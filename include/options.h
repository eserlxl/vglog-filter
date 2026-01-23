// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include <cstdint>
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
  bool streamMode = false;
  bool showProgress = false;
  bool monitor_memory = false;
  std::vector<std::string> markers;
  std::string filename;
  std::string outputFile;
  bool jsonOutput = false;
  bool use_stdin = false;
  std::vector<std::string> excludeTypes;
  std::vector<std::string> excludeStackPatterns;
  std::vector<std::string> excludeSourcePaths;
  std::vector<int32_t> excludeThreads;
  bool detailedJson = false;

  size_t rotateSizeMb = 0;
  size_t rotateBackups = 0;
  bool strictMode = false;

  // Iteration 1 Extension
  size_t maxErrors = 0; // 0 = unlimited
  std::vector<std::string> includeTypes;
  std::vector<std::string> includeFunctions;
  std::vector<std::string> excludeFunctions;
  bool detailedStats = false;
  /**
   * @brief Validates the configuration.
   * @throws std::runtime_error if invalid.
   */
  void validate() const;
};

void usage(std::string_view prog);