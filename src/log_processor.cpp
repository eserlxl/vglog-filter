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
#include <chrono>
#include <thread>
#include <atomic> // Added for atomic variables

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
    initialize_string_patterns();
}

void LogProcessor::initialize_string_patterns() {
    // Initialize pattern strings for string matching
    // No regex compilation needed - eliminates MSan warnings
    vg_pattern = VG_LINE_PATTERN;
    prefix_pattern = PREFIX_PATTERN;
    start_pattern = START_PATTERN;
    bytes_head_pattern = BYTES_HEAD_PATTERN;
    at_pattern = AT_PATTERN;
    by_pattern = BY_PATTERN;
    q_pattern = Q_PATTERN;
}

// Simple string matching functions to replace regex

bool LogProcessor::matches_vg_line(std::string_view line) const {
    // Match pattern: ^==[0-9]+==
    if (line.size() < 4) return false;
    if (line[0] != '=' || line[1] != '=') return false;
    
    size_t i = 2;
    while (i < line.size() && std::isdigit(line[i])) i++;
    if (i < 4 || i >= line.size() - 1) return false;
    if (line[i] != '=' || line[i+1] != '=') return false;
    
    return true;
}

bool LogProcessor::matches_prefix(std::string_view line) const {
    // Match pattern: ^==[0-9]+==[ \t\v\f\r\n]*
    if (!matches_vg_line(line)) return false;
    
    // Find the end of ==[0-9]+==
    size_t i = 2;
    while (i < line.size() && std::isdigit(line[i])) i++;
    i += 2; // Skip ==
    
    // Check for whitespace
    while (i < line.size() && std::isspace(line[i])) i++;
    
    return true;
}

bool LogProcessor::matches_start_pattern(std::string_view line) const {
    // Match pattern: (Invalid (read|write)|Syscall param|Use of uninitialised|...)
    const std::vector<std::string_view> patterns = {
        "Invalid read",
        "Invalid write", 
        "Syscall param",
        "Use of uninitialised",
        "Conditional jump",
        "bytes in ",
        "still reachable",
        "possibly lost",
        "definitely lost",
        "Process terminating"
    };
    
    for (const auto& pattern : patterns) {
        if (line.find(pattern) != std::string_view::npos) return true;
    }
    return false;
}

bool LogProcessor::matches_bytes_head(std::string_view line) const {
    // Match pattern: [0-9]+ bytes in [0-9]+ blocks
    size_t pos = 0;
    
    // Find first number
    while (pos < line.size() && !std::isdigit(line[pos])) pos++;
    if (pos >= line.size()) return false;
    
    // Skip first number
    while (pos < line.size() && std::isdigit(line[pos])) pos++;
    
    // Check for " bytes in "
    if (pos + 10 >= line.size()) return false;
    if (line.substr(pos, 10) != " bytes in ") return false;
    pos += 10;
    
    // Find second number
    while (pos < line.size() && !std::isdigit(line[pos])) pos++;
    if (pos >= line.size()) return false;
    
    // Skip second number
    while (pos < line.size() && std::isdigit(line[pos])) pos++;
    
    // Check for " blocks"
    if (pos + 7 >= line.size()) return false;
    return line.substr(pos, 7) == " blocks";
}

bool LogProcessor::matches_at_pattern(std::string_view line) const {
    // Match pattern: at : +
    return line.find("at : ") != std::string_view::npos;
}

bool LogProcessor::matches_by_pattern(std::string_view line) const {
    // Match pattern: by : +
    return line.find("by : ") != std::string_view::npos;
}

bool LogProcessor::matches_q_pattern(std::string_view line) const {
    // Match pattern: \?{3,} (3 or more question marks)
    int count = 0;
    for (char c : line) {
        if (c == '?') {
            count++;
            if (count >= 3) return true;
        } else {
            count = 0;
        }
    }
    return false;
}

std::string LogProcessor::replace_prefix(std::string_view line) const {
    // Replace pattern: ^==[0-9]+==[ \t\v\f\r\n]*
    if (!matches_vg_line(line)) return std::string(line);
    
    // Find the end of ==[0-9]+==
    size_t i = 2;
    while (i < line.size() && std::isdigit(line[i])) i++;
    i += 2; // Skip ==
    
    // Skip whitespace
    while (i < line.size() && std::isspace(line[i])) i++;
    
    return std::string(line.substr(i));
}

std::string LogProcessor::replace_patterns(const std::string& line) const {
    std::string result = line;
    
    // Replace address patterns (0x[0-9a-fA-F]+)
    size_t pos = 0;
    while ((pos = result.find("0x", pos)) != std::string::npos) {
        size_t start = pos;
        pos += 2; // Skip "0x"
        
        // Find end of hex digits
        while (pos < result.size() && std::isxdigit(result[pos])) pos++;
        
        // Replace if we found hex digits
        if (pos > start + 2) {
            result.replace(start, pos - start, "");
            pos = start; // Continue from the same position
        }
    }
    
    // Replace "at : " patterns
    pos = 0;
    while ((pos = result.find("at : ", pos)) != std::string::npos) {
        result.replace(pos, 5, "");
    }
    
    // Replace "by : " patterns
    pos = 0;
    while ((pos = result.find("by : ", pos)) != std::string::npos) {
        result.replace(pos, 5, "");
    }
    
    // Replace question mark patterns (3 or more)
    pos = 0;
    while (pos < result.size()) {
        if (result[pos] == '?') {
            size_t start = pos;
            size_t count = 0;
            while (pos < result.size() && result[pos] == '?') {
                count++;
                pos++;
            }
            if (count >= 3) {
                result.replace(start, count, "");
                pos = start; // Continue from the same position
            }
        } else {
            pos++;
        }
    }
    
    return result;
}

void LogProcessor::process_stream(std::istream& in) {
    size_t bytes_processed = 0;
    size_t total_bytes = 0;

    if (opt.show_progress && !opt.use_stdin) {
        total_bytes = get_file_size_for_progress();
    }

    // Add timeout for stdin input
    if (opt.use_stdin) {
        std::cerr << "Waiting for input from stdin... (timeout: 15 seconds)\n";
        
        // Use a background thread to check for input availability
        std::atomic<bool> input_available{false};
        std::atomic<bool> timeout_reached{false};
        
        auto input_checker = [&input_available, &timeout_reached]() {
            // Wait for input or timeout
            auto start_time = std::chrono::steady_clock::now();
            const auto timeout_duration = std::chrono::seconds(15);
            
            while (!input_available && !timeout_reached) {
                if (std::chrono::steady_clock::now() - start_time >= timeout_duration) {
                    timeout_reached = true;
                    break;
                }
                
                // Check if stdin has data available
                if (std::cin.peek() != EOF) {
                    input_available = true;
                    break;
                }
                
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }
        };
        
        std::thread timeout_thread(input_checker);
        
        // Wait for either input or timeout
        while (!input_available && !timeout_reached) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
        
        timeout_thread.join();
        
        if (timeout_reached) {
            std::cerr << "Error: No input received within 15 seconds.\n";
            std::cerr << "Usage: vglog-filter [options] [valgrind_log]\n";
            std::cerr << "       echo 'input' | vglog-filter\n";
            std::cerr << "       vglog-filter log.txt\n";
            std::exit(1);
        }
        
        std::cerr << "Input detected, processing...\n";
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
    if (!matches_vg_line(line)) {
        return;
    }

    std::string processed_line = replace_prefix(line);

    // Handle start of new block
    if (matches_start_pattern(processed_line)) {
        flush();
        if (matches_bytes_head(processed_line)) {
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
        // Use string matching instead of regex - no exceptions to catch
        rawLine = replace_patterns(rawLine);
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