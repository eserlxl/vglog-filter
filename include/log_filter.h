// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "log_entry.h"
#include "options.h"

#include <regex>
#include <vector>

/**
 * @brief Encapsulates filtering logic for Valgrind log entries.
 *
 * Determines whether a given LogEntry should be kept or discarded
 * based on the provided configuration (Types, Threads, Stack Patterns).
 */
class LogFilter {
public:
  explicit LogFilter(const FilterConfig& cfg);

  /**
   * @brief Checks if the entry satisfies the filter criteria.
   * @param entry The log entry to check.
   * @return true if the entry should be KEPT, false if it should be discarded.
   */
  [[nodiscard]] bool shouldKeep(const LogEntry& entry) const;

private:
  const FilterConfig& config;
  std::vector<std::regex> stackRegexes;
  std::vector<std::regex> includeStackRegexes; // Iteration 1
};
