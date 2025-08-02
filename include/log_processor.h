// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include "options.h"
#include <string>
#include <string_view>
#include <vector>
#include <sstream>
#include <unordered_set>
#include <iostream>
#include <span>
#include <memory>
#include <locale>
#include <algorithm>
#include <cctype>

class LogProcessor {
public:
    using Str = std::string;
    using VecS = std::vector<Str>;
    using StrSpan = std::span<const Str>;

    explicit LogProcessor(const Options& options);
    
    // Process from a stream (for stdin or large files)
    void process_stream(std::istream& in);

    // Process from a vector of lines (for smaller files)
    void process_lines(const VecS& lines);

private:
    void process_line(std::string_view line);
    void flush();
    void clear_current_state();
    void reset_epoch();
    [[nodiscard]] size_t find_marker(const VecS& lines) const;
    
    // New helper methods for better code organization
    void initialize_string_patterns();
    size_t get_file_size_for_progress() const;
    bool should_report_progress(size_t bytes_processed, size_t total_bytes) const;
    void output_pending_blocks();
    std::string process_raw_line(const std::string& processed_line);
    std::string generate_signature_key() const;

    // Simple string matching functions to replace regex
    bool matches_vg_line(std::string_view line) const;
    bool matches_prefix(std::string_view line) const;
    bool matches_start_pattern(std::string_view line) const;
    bool matches_bytes_head(std::string_view line) const;
    bool matches_at_pattern(std::string_view line) const;
    bool matches_by_pattern(std::string_view line) const;
    bool matches_q_pattern(std::string_view line) const;
    std::string replace_prefix(std::string_view line) const;
    std::string replace_patterns(const std::string& line) const;

    const Options& opt;
    std::string raw, sig;  // Use regular strings instead of ostringstream to avoid MSAN issues
    VecS sigLines;
    std::unordered_set<Str> seen;
    
    // Used only in stream mode
    std::vector<Str> pending_blocks;
    bool marker_found = false;

    // Pattern strings for string matching (replaces regex objects)
    std::string vg_pattern;
    std::string prefix_pattern;
    std::string start_pattern;
    std::string bytes_head_pattern;
    std::string at_pattern;
    std::string by_pattern;
    std::string q_pattern;
};