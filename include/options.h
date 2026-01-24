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
inline constexpr auto VERSION_STRING = "10.5.0"; // Iteration 1



#include "filter_config.h"

enum class SanitizerType { Auto, Valgrind, Asan };
enum class ColorMode { Auto, Always, Never }; // Iteration 1

struct RotationConfig {
  size_t rotateSizeMb = 0;
  size_t rotateBackups = 0;
};

struct Options {
  int depth = DEFAULT_DEPTH;
  bool trim = false;
  bool scrubRaw = true; // Renamed from scrub_raw
  bool streamMode = false;
  bool showProgress = false;
  bool monitorMemory = false; // Renamed from monitor_memory
  std::vector<std::string> markers;
  std::string filename;
  std::string outputFile;
  bool jsonOutput = false;
  bool jsonArray = false; // Iteration 2
  bool useStdin = false;  // Renamed from use_stdin
  bool detailedJson = false;
  bool detailedStats = false;
  bool strictMode = false;
  bool verbose = false; // Iteration 1 Extension

  enum class StatsFormat : std::uint8_t { text, json };
  StatsFormat statsFormat = StatsFormat::text;
  std::string dumpConfig; // Empty if disabled

  // Iteration 1 Extensions
  std::string timeAfter;
  std::string timeBefore;
  std::string statsFile;
  std::string configFile;
  bool color = false; // Kept for compat/sync, master source is colorMode
  ColorMode colorMode = ColorMode::Auto; // Iteration 1
  bool githubActions = false; // Iteration 1: GitHub Actions output
  bool version = false; // Iteration 1: Print version and exit
  std::string htmlReport; // Iteration 1: HTML Output file
  std::string markdownReport; // Iteration 1: Markdown Output file
  std::string csvOutput;      // Iteration 1: CSV Output file
  std::string yamlOutput;     // Iteration 1: YAML Output file
  std::string diffBaseline; // Iteration 2: Baseline file for diff

  // Iteration 2 Extensions
  bool uniqueOutput = false;
  int contextLines = 0;
  size_t jobs = 1;
  std::vector<std::string> inputFiles;


  SanitizerType sanitizerType = SanitizerType::Auto;


  // Nested Configs
  FilterConfig filter;
  RotationConfig rotation;

  /**
   * @brief Validates the configuration.
   * @throws std::runtime_error if invalid.
   */
  void validate() const;

  void dump(std::ostream& out) const;
  void load(std::istream& in);
};

void usage(std::string_view prog);