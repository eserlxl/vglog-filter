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
#include <stdexcept>
#include <limits>
#include <locale>

using namespace canonicalization;

namespace {
    // Regex pattern constants for better maintainability
    constexpr const char* VG_LINE_PATTERN = R"(^==[0-9]+==)";
    constexpr const char* PREFIX_PATTERN = R"(^==[0-9]+==[ \t\v\f\r\n]*)";
    constexpr const char* START_PATTERN = R"((Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ blocks|still reachable|possibly lost|definitely lost|Process terminating))";
    constexpr const char* BYTES_HEAD_PATTERN = R"([0-9]+ bytes in [0-9]+ blocks)";
    constexpr const char* AT_PATTERN = R"(at : +)";
    constexpr const char* BY_PATTERN = R"(by : +)";
    constexpr const char* Q_PATTERN = R"(\?{3,})";
    
    // Progress reporting constants
    constexpr size_t PROGRESS_REPORT_INTERVAL = 1024 * 1024; // 1MB
    
    // Security limits
    constexpr size_t MAX_LINE_LENGTH = 1024 * 1024; // 1MB per line
    constexpr size_t MAX_BLOCK_SIZE = 10 * 1024 * 1024; // 10MB per block
    constexpr size_t MAX_PENDING_BLOCKS = 1000;
    
    // Validate line length for security
    void validate_line_length(std::string_view line) {
        if (line.length() > MAX_LINE_LENGTH) {
            throw std::runtime_error("Line too long (max " + std::to_string(MAX_LINE_LENGTH) + " bytes)");
        }
    }
    
    // Validate block size for security
    void validate_block_size(size_t size) {
        if (size > MAX_BLOCK_SIZE) {
            throw std::runtime_error("Block too large (max " + std::to_string(MAX_BLOCK_SIZE) + " bytes)");
        }
    }
    
    // Validate pending blocks count for security
    void validate_pending_blocks_count(size_t count) {
        if (count > MAX_PENDING_BLOCKS) {
            throw std::runtime_error("Too many pending blocks (max " + std::to_string(MAX_PENDING_BLOCKS) + ")");
        }
    }
}

LogProcessor::LogProcessor(const Options& options) :
    opt(options)
{
    // Pre-allocate containers for better performance
    seen.reserve(256);
    if (opt.stream_mode) {
        pending_blocks.reserve(64);
    }
    sigLines.reserve(64);
    
    // Initialize regex patterns with explicit locale to avoid uninitialized value issues
    initialize_regex_patterns();
}

void LogProcessor::initialize_regex_patterns() {
    try {
        // Ensure locale is properly initialized before regex compilation
        std::locale::global(std::locale(""));
        
        // Initialize regex patterns with explicit locale and proper initialization
        re_vg_line = std::regex(VG_LINE_PATTERN, std::regex::optimize | std::regex::ECMAScript);
        re_prefix = std::regex(PREFIX_PATTERN, std::regex::optimize | std::regex::ECMAScript);
        re_start = std::regex(START_PATTERN, std::regex::optimize | std::regex::ECMAScript);
        re_bytes_head = std::regex(BYTES_HEAD_PATTERN, std::regex::optimize | std::regex::ECMAScript);
        re_at = std::regex(AT_PATTERN, std::regex::optimize | std::regex::ECMAScript);
        re_by = std::regex(BY_PATTERN, std::regex::optimize | std::regex::ECMAScript);
        re_q = std::regex(Q_PATTERN, std::regex::optimize | std::regex::ECMAScript);
    } catch (const std::regex_error& e) {
        throw std::runtime_error("Failed to initialize regex patterns: " + std::string(e.what()));
    } catch (const std::runtime_error& e) {
        throw std::runtime_error("Failed to set locale for regex patterns: " + std::string(e.what()));
    }
}

void LogProcessor::process_stream(std::istream& in) {
    size_t bytes_processed = 0;
    size_t total_bytes = 0;

    if (opt.show_progress && !opt.use_stdin) {
        total_bytes = get_file_size_for_progress();
    }

    std::string line;
    line.reserve(1024); // Pre-allocate line buffer for better performance
    
    while (std::getline(in, line)) {
        // Security validation
        validate_line_length(line);
        
        bytes_processed += line.length() + 1; // +1 for the newline character
        
        if (should_report_progress(bytes_processed, total_bytes)) {
            report_progress(bytes_processed, total_bytes, opt.filename);
        }
        
        process_line(line);
    }

    if (opt.show_progress && total_bytes > 0) {
        report_progress(bytes_processed, total_bytes, opt.filename);
    }

    flush();
    output_pending_blocks();
}

size_t LogProcessor::get_file_size_for_progress() const {
    try {
        return std::filesystem::file_size(opt.filename);
    } catch (const std::filesystem::filesystem_error& e) {
        std::cerr << "Warning: Could not get file size for progress reporting: " << e.what() << "\n";
        return 0;
    }
}

bool LogProcessor::should_report_progress(size_t bytes_processed, size_t total_bytes) const {
    return opt.show_progress && total_bytes > 0 && 
           (bytes_processed % PROGRESS_REPORT_INTERVAL == 0 || bytes_processed >= total_bytes);
}

void LogProcessor::output_pending_blocks() {
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
        // Security validation
        validate_line_length(lines[i]);
        process_line(lines[i]);
    }
    flush();
}

void LogProcessor::process_line(std::string_view line) {
    // Check for marker in stream mode
    if (opt.trim && opt.stream_mode && line.find(opt.marker) != std::string_view::npos) {
        marker_found = true;
        reset_epoch();
        return; // skip marker line
    }

    // Skip lines that don't match valgrind pattern
    if (!std::regex_search(line.begin(), line.end(), re_vg_line)) {
        return;
    }

    std::string processed_line = std::regex_replace(std::string(line), re_prefix, "");

    // Handle start of new block
    if (std::regex_search(processed_line, re_start)) {
        flush();
        if (std::regex_search(processed_line, re_bytes_head)) {
            return;
        }
    }

    // Process the line
    std::string rawLine = process_raw_line(processed_line);
    if (trim_view(rawLine).empty()) {
        return;
    }

    // Add to current block
    raw << rawLine << '\n';
    std::string cl = canon(processed_line);
    sig << cl << '\n';
    sigLines.push_back(std::move(cl));
}

std::string LogProcessor::process_raw_line(const std::string& processed_line) {
    std::string rawLine = processed_line;
    
    if (opt.scrub_raw) {
        try {
            rawLine = regex_replace_all(rawLine, get_re_addr(), "");
            rawLine = regex_replace_all(rawLine, re_at, "");
            rawLine = regex_replace_all(rawLine, re_by, "");
            rawLine = regex_replace_all(rawLine, re_q, "");
        } catch (const std::regex_error& e) {
            throw std::runtime_error("Regex processing failed: " + std::string(e.what()));
        }
    }
    
    return rawLine;
}

void LogProcessor::flush() {
    const std::string rawStr = raw.str();
    if (rawStr.empty()) {
        clear_current_state();
        return;
    }

    // Security validation
    validate_block_size(rawStr.size());

    std::string key = generate_signature_key();
    
    if (seen.insert(key).second) {
        if (opt.stream_mode) {
            // Security validation for pending blocks
            validate_pending_blocks_count(pending_blocks.size());
            pending_blocks.emplace_back(rawStr + '\n');
        } else {
            std::cout << rawStr << '\n';
        }
    }
    
    clear_current_state();
}

std::string LogProcessor::generate_signature_key() const {
    if (opt.depth > 0) {
        std::string key;
        key.reserve(256);
        
        const int depth_limit = std::min(opt.depth, static_cast<int>(sigLines.size()));
        for (int i = 0; i < depth_limit; ++i) {
            key += sigLines[static_cast<size_t>(i)];
            key += '\n';
        }
        return key;
    } else {
        return sig.str();
    }
}

void LogProcessor::clear_current_state() {
    raw.str(""); 
    raw.clear();
    sig.str(""); 
    sig.clear();
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