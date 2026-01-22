// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include <iostream>
#include <string>
#include <string_view>
#include <vector>

inline constexpr int DEFAULT_DEPTH = 1;
inline constexpr auto DEFAULT_MARKER = std::string_view{"Successfully downloaded debug"};
inline constexpr size_t LARGE_FILE_THRESHOLD_MB = 5;

struct Options {
  int depth = DEFAULT_DEPTH;
  bool trim = true;
  bool scrub_raw = true;
  bool stream_mode = false;
  bool show_progress = false;
  bool monitor_memory = false;
  std::vector<std::string> markers;
  std::string filename;
  std::string output_file;
  bool json_output = false;
  bool use_stdin = false;
};

void usage(std::string_view prog);