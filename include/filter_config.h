// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <optional>

struct FilterConfig {
  std::vector<std::string> excludeTypes;
  std::vector<std::string> excludeStackPatterns;
  std::vector<std::string> excludeSourcePaths;
  std::vector<std::string> includeSourcePaths; // Iteration 1: Include specific sources
  std::vector<int32_t> excludeThreads;
  // Iteration 1 Extension
  size_t maxErrors = 0; // 0 = unlimited
  std::vector<std::string> includeTypes;
  std::vector<std::string> includeFunctions;
  std::vector<std::string> excludeFunctions;
  std::vector<int32_t> excludePids;    // Iteration 1: Explicit exclude by PID
  std::vector<int32_t> includePids;    // Iteration 1: Only include these PIDs
  std::vector<int32_t> includeThreads; // Iteration 1: Only include these Threads

  // Iteration 1 Extensions
  std::vector<std::string> includeStackPatterns;
  std::optional<std::string> timeAfter;
  std::optional<std::string> timeBefore;

  // Iteration 3 Extensions (Regex)
  std::vector<std::string> excludeTypesRegex;
  std::vector<std::string> includeTypesRegex;
  std::vector<std::string> excludeFunctionsRegex;
  std::vector<std::string> includeFunctionsRegex;
};
