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
#include <atomic>
#include <algorithm>
#include <cctype>

using namespace canonicalization;

namespace {
    // Simple string matching functions to replace regex
    bool starts_with(const std::string& str, const std::string& prefix) {
        return str.size() >= prefix.size() && 
               str.compare(0, prefix.size(), prefix) == 0;
    }
    
    bool contains(const std::string& str, const std::string& substr) {
        return str.find(substr) != std::string::npos;
    }
    
    bool matches_vg_line(const std::string& line) {
        // Match pattern: ^==[0-9]+==
        if (line.size() < 4) return false;
        if (line[0] != '=' || line[1] != '=') return false;
        
        size_t i = 2;
        while (i < line.size() && std::isdigit(line[i])) i++;
        if (i < 4 || line[i] != '=' || line[i+1] != '=') return false;
        
        return true;
    }
    
    bool matches_prefix(const std::string& line) {
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
    
    bool matches_start_pattern(const std::string& line) {
        // Match pattern: (Invalid (read|write)|Syscall param|Use of uninitialised|...)
        const std::vector<std::string> patterns = {
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
            if (contains(line, pattern)) return true;
        }
        return false;
    }
    
    bool matches_bytes_head(const std::string& line) {
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
    
    bool matches_at_pattern(const std::string& line) {
        // Match pattern: at : +
        return contains(line, "at : ");
    }
    
    bool matches_by_pattern(const std::string& line) {
        // Match pattern: by : +
        return contains(line, "by : ");
    }
    
    bool matches_q_pattern(const std::string& line) {
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

// Alternative LogProcessor implementation without std::regex
class LogProcessorAlternative {
public:
    using Str = std::string;
    using VecS = std::vector<Str>;
    using StrSpan = std::span<const Str>;

    explicit LogProcessorAlternative(const Options& options) : opt(options) {
        // Pre-allocate containers for better performance
        seen.reserve(256);
        if (opt.stream_mode) {
            pending_blocks.reserve(64);
        }
        sigLines.reserve(64);
        
        // No regex initialization needed - we use simple string matching
    }
    
    // Process from a stream (for stdin or large files)
    void process_stream(std::istream& in) {
        // Implementation would be similar but use string matching functions
        // instead of regex_search/regex_match
    }

    // Process from a vector of lines (for smaller files)
    void process_lines(const VecS& lines) {
        // Implementation would be similar but use string matching functions
        // instead of regex_search/regex_match
    }

private:
    void process_line(std::string_view line) {
        // Use string matching functions instead of regex
        std::string line_str(line);
        
        if (matches_vg_line(line_str)) {
            // Handle valgrind line
        } else if (matches_start_pattern(line_str)) {
            // Handle start pattern
        } else if (matches_bytes_head(line_str)) {
            // Handle bytes head pattern
        } else if (matches_at_pattern(line_str)) {
            // Handle at pattern
        } else if (matches_by_pattern(line_str)) {
            // Handle by pattern
        } else if (matches_q_pattern(line_str)) {
            // Handle q pattern
        }
    }
    
    void flush() {
        // Implementation
    }
    
    void clear_current_state() {
        // Implementation
    }
    
    void reset_epoch() {
        // Implementation
    }
    
    [[nodiscard]] size_t find_marker(const VecS& lines) const {
        // Implementation
        return 0;
    }
    
    size_t get_file_size_for_progress() const {
        // Implementation
        return 0;
    }
    
    bool should_report_progress(size_t bytes_processed, size_t total_bytes) const {
        // Implementation
        return false;
    }
    
    void output_pending_blocks() {
        // Implementation
    }
    
    std::string process_raw_line(const std::string& processed_line) {
        // Implementation
        return processed_line;
    }
    
    std::string generate_signature_key() const {
        // Implementation
        return "";
    }

    const Options& opt;
    std::ostringstream raw, sig;
    VecS sigLines;
    std::unordered_set<Str> seen;
    
    // Used only in stream mode
    std::vector<Str> pending_blocks;
    bool marker_found = false;
}; 