// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "log_processor.h" 
#include "file_utils.h"
#include <canonicalization.h>
#include <filesystem>
#include <iterator>

using namespace canonicalization;

LogProcessor::LogProcessor(const Options& options) :
    opt(options)
{
    seen.reserve(256);
    if (opt.stream_mode) {
        pending_blocks.reserve(64);
    }
    sigLines.reserve(64);
    
    // Initialize regex patterns with explicit locale to avoid uninitialized value issues
    try {
        re_vg_line = std::regex(R"(^==[0-9]+==)", std::regex::optimize | std::regex::ECMAScript);
        re_prefix = std::regex(R"(^==[0-9]+==[ \t\v\f\r\n]*)", std::regex::optimize | std::regex::ECMAScript);
        re_start = std::regex(R"((Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ blocks|still reachable|possibly lost|definitely lost|Process terminating))", std::regex::optimize | std::regex::ECMAScript);
        re_bytes_head = std::regex(R"([0-9]+ bytes in [0-9]+ blocks)", std::regex::optimize | std::regex::ECMAScript);
        re_at = std::regex(R"(at : +)", std::regex::optimize | std::regex::ECMAScript);
        re_by = std::regex(R"(by : +)", std::regex::optimize | std::regex::ECMAScript);
        re_q = std::regex(R"(\?{3,})", std::regex::optimize | std::regex::ECMAScript);
    } catch (const std::regex_error& e) {
        throw std::runtime_error("Failed to initialize regex patterns: " + std::string(e.what()));
    }
}

void LogProcessor::process_stream(std::istream& in) {
    size_t bytes_processed = 0;
    size_t total_bytes = 0;

    if (opt.show_progress && !opt.use_stdin) {
        try {
            total_bytes = std::filesystem::file_size(opt.filename);
        } catch (const std::filesystem::filesystem_error& e) {
            std::cerr << "Warning: Could not get file size for progress reporting: " << e.what() << "\n";
        }
    }

    std::string line;
    while (std::getline(in, line)) {
        bytes_processed += line.length() + 1; // +1 for the newline character
        if (opt.show_progress && total_bytes > 0 && (bytes_processed % (1024 * 1024) == 0 || bytes_processed >= total_bytes)) {
            report_progress(bytes_processed, total_bytes, opt.filename);
        }
        process_line(line);
    }

    if (opt.show_progress && total_bytes > 0) {
        report_progress(bytes_processed, total_bytes, opt.filename);
    }

    flush();
    
    if (!opt.trim || marker_found) {
        for (const auto& block : pending_blocks) {
            std::cout << block;
        }
    }
}

void LogProcessor::process_lines(const VecS& lines) {
    size_t start_index = 0;
    if (opt.trim) {
        start_index = find_marker(lines);
        if (start_index == 0) {
            // When trimming, if the marker is not found, we output nothing.
            return;
        }
    }

    for (size_t i = start_index; i < lines.size(); ++i) {
        process_line(lines[i]);
    }
    flush();
}


void LogProcessor::process_line(std::string_view line) {
    if (opt.trim && opt.stream_mode && line.find(opt.marker) != std::string_view::npos) {
        marker_found = true;
        reset_epoch();
        return; // skip marker line
    }

    if (!std::regex_search(line.begin(), line.end(), re_vg_line)) return;

    std::string processed_line = std::regex_replace(std::string(line), re_prefix, "");

    if (std::regex_search(processed_line, re_start)) {
        flush();
        if (std::regex_search(processed_line, re_bytes_head)) {
            return;
        }
    }

    std::string rawLine = processed_line;
    if (opt.scrub_raw) {
        rawLine = regex_replace_all(rawLine, get_re_addr(), "");
        rawLine = regex_replace_all(rawLine, re_at, "");
        rawLine = regex_replace_all(rawLine, re_by, "");
        rawLine = regex_replace_all(rawLine, re_q, "");
    }
    if (trim_view(rawLine).empty()) return;

    raw << rawLine << '\n';
    std::string cl = canon(processed_line);
    sig << cl << '\n';
    sigLines.push_back(std::move(cl));
}

void LogProcessor::flush() {
    const std::string rawStr = raw.str();
    if (rawStr.empty()) {
        clear_current_state();
        return;
    }

    std::string key;
    if (opt.depth > 0) {
        key.reserve(256);
        for (int i = 0; i < opt.depth && i < static_cast<int>(sigLines.size()); ++i) {
            key += sigLines[static_cast<size_t>(i)];
            key += '\n';
        }
    }
    else {
        key = sig.str();
    }

    if (seen.insert(key).second) {
        if (opt.stream_mode) {
            pending_blocks.emplace_back(rawStr + '\n');
        } else {
            std::cout << rawStr << '\n';
        }
    }
    clear_current_state();
}

void LogProcessor::clear_current_state() {
    raw.str(""); raw.clear();
    sig.str(""); sig.clear();
    sigLines.clear();
}

void LogProcessor::reset_epoch() {
    pending_blocks.clear();
    seen.clear();
    clear_current_state();
}

size_t LogProcessor::find_marker(const VecS& lines) const {
    for (size_t i = lines.size(); i-- > 0;) {
        if (lines[i].find(opt.marker) != std::string::npos) {
            return i + 1; // start after the marker line
        }
    }
    return 0; // process whole input when marker not found
}