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
#include <regex>
#include <iostream>
#include <span>
#include <memory>
#include <locale>

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
    void initialize_regex_patterns();
    size_t get_file_size_for_progress() const;
    bool should_report_progress(size_t bytes_processed, size_t total_bytes) const;
    void output_pending_blocks();
    std::string process_raw_line(const std::string& processed_line);
    std::string generate_signature_key() const;

    const Options& opt;
    std::ostringstream raw, sig;
    VecS sigLines;
    std::unordered_set<Str> seen;
    
    // Used only in stream mode
    std::vector<Str> pending_blocks;
    bool marker_found = false;

    // Regex members - use pointers to avoid default construction issues
    std::unique_ptr<std::regex> re_vg_line;
    std::unique_ptr<std::regex> re_prefix;
    std::unique_ptr<std::regex> re_start;
    std::unique_ptr<std::regex> re_bytes_head;
    std::unique_ptr<std::regex> re_at;
    std::unique_ptr<std::regex> re_by;
    std::unique_ptr<std::regex> re_q;
};