// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_filter.h"
#include <stdexcept>

LogFilter::LogFilter(const FilterConfig& cfg) : config(cfg) {
  // Pre-compile regexes
  try {
    for (const auto& pat : config.excludeStackPatterns) {
      stackRegexes.emplace_back(pat, std::regex::optimize);
    }
  } catch (const std::regex_error& e) {
    throw std::runtime_error("Invalid regex in exclude-stack: " + std::string(e.what()));
  }
}

bool LogFilter::shouldKeep(const LogEntry& entry) const {
  // Exclude Types
  for (const auto& ex : config.excludeTypes) {
    if (entry.errorType.find(ex) != std::string::npos) {
      return false;
    }
  }

  // Stack Regex Filter (Exclude)
  if (!stackRegexes.empty()) {
    for (const auto& re : stackRegexes) {
      for (const auto& frame : entry.stackTrace) {
        if (std::regex_search(frame, re)) {
          return false;
        }
      }
    }
  }

  // Thread Filter (Exclude)
  if (entry.tid.has_value()) {
    for (auto t : config.excludeThreads) {
      if (t == *entry.tid) {
        return false;
      }
    }
  }

  // PID Filter (Exclude) - Iteration 1
  if (!entry.pid.empty()) {
    try {
      int32_t pidVal = std::stoi(entry.pid);
      for (auto p : config.excludePids) {
        if (p == pidVal)
          return false;
      }
    } catch (...) {
      // Ignore non-numeric PID
    }
  }

  // Path Filter (Structured Stack Exclude)
  if (!config.excludeSourcePaths.empty()) {
    for (const auto& path : config.excludeSourcePaths) {
      if (entry.involvesSourceFile(path)) {
        return false;
      }
    }
  }

  // Function Name Exclusion
  if (!config.excludeFunctions.empty()) {
    for (const auto& func : config.excludeFunctions) {
      if (entry.hasFrameMatching(func)) {
        return false;
      }
    }
  }

  // Include-Only Logic (OR logic within category, AND across categories)
  bool includesActive = !config.includeTypes.empty() || !config.includeFunctions.empty() ||
                        !config.includePids.empty() || !config.includeThreads.empty();
  if (includesActive) {
    // Check Types
    if (!config.includeTypes.empty()) {
      bool matched = false;
      for (const auto& type : config.includeTypes) {
        if (entry.matchesErrorType(type)) {
          matched = true;
          break;
        }
      }
      if (!matched)
        return false;
    }

    // Check Functions
    if (!config.includeFunctions.empty()) {
      bool matched = false;
      for (const auto& func : config.includeFunctions) {
        if (entry.hasFrameMatching(func)) {
          matched = true;
          break;
        }
      }
      if (!matched)
        return false;
    }

    // Check PIDs
    if (!config.includePids.empty()) {
      bool matched = false;
      if (!entry.pid.empty()) {
        try {
          int32_t pidVal = std::stoi(entry.pid);
          for (auto p : config.includePids) {
            if (p == pidVal) {
              matched = true;
              break;
            }
          }
        } catch (...) {
        }
      }
      if (!matched)
        return false;
    }

    // Check Threads
    if (!config.includeThreads.empty()) {
      bool matched = false;
      if (entry.tid.has_value()) {
        for (auto t : config.includeThreads) {
          if (t == *entry.tid) {
            matched = true;
            break;
          }
        }
      }
      if (!matched)
        return false;
    }
  }

  return true;
}
