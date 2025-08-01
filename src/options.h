// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef OPTIONS_H
#define OPTIONS_H

#include <string>
#include <iostream>

constexpr int         DEFAULT_DEPTH  = 1;
constexpr const char* DEFAULT_MARKER = "Successfully downloaded debug";
constexpr size_t      LARGE_FILE_THRESHOLD_MB = 5;

struct Options {
    int   depth           = DEFAULT_DEPTH;
    bool  trim            = true;
    bool  scrub_raw       = true;
    bool  stream_mode     = false;
    bool  show_progress   = false;
    bool  monitor_memory  = false;
    std::string marker    = DEFAULT_MARKER;
    std::string filename;
    bool  use_stdin       = false;
};

void usage(const char* prog);

#endif // OPTIONS_H
