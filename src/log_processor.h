// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef LOG_PROCESSOR_H
#define LOG_PROCESSOR_H

#include "options.h"
#include <string>
#include <vector>
#include <sstream>
#include <unordered_set>
#include <regex>
#include <iostream>
#include <span>

using Str = std::string;
using VecS = std::vector<Str>;
using StrSpan = std::span<const Str>;

class LogProcessor {
public:
    explicit LogProcessor(const Options& options);
    
    // Process from a stream (for stdin or large files)
    void process_stream(std::istream& in);

    // Process from a vector of lines (for smaller files)
    void process_lines(const VecS& lines);

private:
    void process_line(const Str& line);
    void flush();
    void clear_current_state();
    void reset_epoch();
    size_t find_marker(const VecS& lines) const;

    const Options& opt;
    std::ostringstream raw, sig;
    VecS sigLines;
    std::unordered_set<Str> seen;
    
    // Used only in stream mode
    std::vector<Str> pending_blocks;
    bool marker_found = false;

    // Regex members
    const std::regex re_vg_line;
    const std::regex re_prefix;
    const std::regex re_start;
    const std::regex re_bytes_head;
    const std::regex re_at;
    const std::regex re_by;
    const std::regex re_q;
};

#endif // LOG_PROCESSOR_H