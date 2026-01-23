// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_filter.h"
#include "time_utils.h"
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
    for (const auto& pat : config.excludeTypesRegex) {
      excludeTypesRegexes.emplace_back(pat, std::regex::optimize);
    }
    for (const auto& pat : config.includeTypesRegex) {
      includeTypesRegexes.emplace_back(pat, std::regex::optimize);
    }
    for (const auto& pat : config.excludeFunctionsRegex) {
      excludeFunctionsRegexes.emplace_back(pat, std::regex::optimize);
    }
    for (const auto& pat : config.includeFunctionsRegex) {
      includeFunctionsRegexes.emplace_back(pat, std::regex::optimize);
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
  for (const auto& re : excludeTypesRegexes) {
    if (std::regex_search(entry.errorType, re)) {
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
  if (!excludeFunctionsRegexes.empty()) {
    for (const auto& re : excludeFunctionsRegexes) {
      bool match = entry.hasFrame(
          [&](const LogEntry::StackFrame& frame) { return std::regex_search(frame.function, re); });
      if (match)
        return false;
    }
  }

  // Time Filter (Iteration 1)
  if (config.timeAfter.has_value() || config.timeBefore.has_value()) {
    if (!entry.timestamp.has_value()) {
      return false; // Strict
    }
    const auto& ts = *entry.timestamp;
    if (config.timeAfter.has_value() && !time_utils::isAfter(ts, *config.timeAfter)) {
      if (time_utils::normalizeTimestamp(ts) !=
          time_utils::normalizeTimestamp(
              *config
                   .timeAfter)) // inclusive? usually after means >. Let's say >= if user wants. But isAfter is strict >. Let's use strict > or >=?
                                // User said "timeAfter". Usually implies "from this time onwards".
        // Let's assume inclusive for "After" usually means >= in logs? Or >?
        // Let's stick to logic: !(ts < after).
        // My isAfter checks normalization.
        // Let's interpret "timeAfter" as "keep if ts >= timeAfter".
        // So if ts < timeAfter, return false.
        // isBefore(ts, timeAfter) -> return false.
        if (time_utils::isBefore(ts, *config.timeAfter))
          return false;
    }
    if (config.timeBefore.has_value() && time_utils::isAfter(ts, *config.timeBefore)) {
      return false;
    }
  }

  // Include-Only Logic (OR logic within category, AND across categories)
  bool includesActive = !config.includeTypes.empty() || !config.includeFunctions.empty() ||
                        !config.includePids.empty() || !config.includeThreads.empty() ||
                        !config.includeStackPatterns.empty() || !includeTypesRegexes.empty() ||
                        !includeFunctionsRegexes.empty();
  if (includesActive) {

    // REWRITE Type check block to unify
    bool hasTypeIncludes = !config.includeTypes.empty() || !includeTypesRegexes.empty();
    if (hasTypeIncludes) {
      bool typeMatched = false;
      // Check scalar
      for (const auto& type : config.includeTypes) {
        if (entry.matchesErrorType(type)) {
          typeMatched = true;
          break;
        }
      }
      // Check regex if not yet matched
      if (!typeMatched) {
        for (const auto& re : includeTypesRegexes) {
          if (std::regex_search(entry.errorType, re)) {
            typeMatched = true;
            break;
          }
        }
      }
      if (!typeMatched)
        return false;
    }

    // Check Functions (Unified)
    bool hasFuncIncludes = !config.includeFunctions.empty() || !includeFunctionsRegexes.empty();
    if (hasFuncIncludes) {
      bool funcMatched = false;
      // Scalar
      for (const auto& func : config.includeFunctions) {
        if (entry.hasFrameMatching(func)) {
          funcMatched = true;
          break;
        }
      }
      // Regex
      if (!funcMatched) {
        for (const auto& re : includeFunctionsRegexes) {
          if (entry.hasFrame([&](const LogEntry::StackFrame& f) {
                return std::regex_search(f.function, re);
              })) {
            funcMatched = true;
            break;
          }
        }
      }
      if (!funcMatched)
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

  // Source Path Inclusion (Iteration 1)
  if (!config.includeSourcePaths.empty()) {
    bool match = false;
    for (const auto& path : config.includeSourcePaths) {
      if (entry.involvesSourceFile(path)) {
        match = true;
        break;
      }
    }
    if (!match)
      return false;
  }

  return true;
}
