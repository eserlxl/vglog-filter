// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "filter_config.h"
#include <algorithm>
#include <set>
#include <string>
#include <vector>

std::vector<std::string> FilterConfig::validate() const {
  std::vector<std::string> errors;

  // 1. PID Conflict
  // Check intersection of includePids and excludePids
  if (!includePids.empty() && !excludePids.empty()) {
    std::set<int32_t> includes(includePids.begin(), includePids.end());
    for (auto pid : excludePids) {
      if (includes.count(pid)) {
        errors.push_back("Conflict: PID " + std::to_string(pid) +
                         " is both included and excluded.");
      }
    }
  }

  // 2. Thread Conflict
  if (!includeThreads.empty() && !excludeThreads.empty()) {
    std::set<int32_t> includes(includeThreads.begin(), includeThreads.end());
    for (auto tid : excludeThreads) {
      if (includes.count(tid)) {
        errors.push_back("Conflict: Thread " + std::to_string(tid) +
                         " is both included and excluded.");
      }
    }
  }

  // 3. Time Logic
  // If timeAfter and timeBefore are both present, timeAfter must be <= timeBefore logically,
  // preventing empty range errors (though technically valid to have empty range).
  // We won't enforce rigorous time parsing here as strings might be complex formats,
  // but if both are identical, it effectively filters to one point or nothing depending on implementation.
  // We'll leave time validation to runtime parsing in LogFilter for Iteration 1.

  return errors;
}
