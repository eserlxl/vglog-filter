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
    for (const auto& pat : config.includeStackPatterns) {
      includeStackRegexes.emplace_back(pat, std::regex::optimize);
    }
  } catch (const std::regex_error& e) {
    throw std::runtime_error("Invalid regex in stack patterns: " + std::string(e.what()));
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

  // Time Filter (Iteration 1)
  if (config.timeAfter.has_value() || config.timeBefore.has_value()) {
    if (!entry.timestamp.has_value()) {
      // If time filter is requested but entry has no timestamp, exclude it?
      // Or strictly follow "if present"?
      // Design decision: If time filtering is strictly requested, missing timestamp = drop.
      return false;
    }
    const auto& ts = *entry.timestamp;
    if (config.timeAfter.has_value() && ts < *config.timeAfter) {
      return false;
    }
    if (config.timeBefore.has_value() && ts > *config.timeBefore) {
      return false;
    }
  }

  // Include-Only Logic (OR logic within category, AND across categories)
  bool includesActive = !config.includeTypes.empty() || !config.includeFunctions.empty() ||
                        !config.includePids.empty() || !config.includeThreads.empty() ||
                        !config.includeStackPatterns.empty();
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

    // Check Stack Patterns (Include)
    if (!includeStackRegexes.empty()) {
      bool matched = false;
      for (const auto& re : includeStackRegexes) {
        for (const auto& frame : entry.stackTrace) {
          if (std::regex_search(frame, re)) {
            matched = true;
            break;
          }
        }
        if (matched)
          break;
      }
      if (!matched)
        return false;
    }
  }

  return true;
}
