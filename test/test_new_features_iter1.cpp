// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_entry.h"
#include "log_filter.h"
#include "options.h"
#include "test_helpers.h"
#include <cstdio>
#include <fstream>
#include <iostream>
#include <regex>
#include <string>
#include <vector>

// Reuse test framework

bool test_config_file_loading() {
  // Create a dummy config file
  std::ofstream cfg("/tmp/test_config.json");
  cfg << "{\n";
  cfg << "  \"timeAfter\": \"10:00:00\",\n";
  cfg << "  \"color\": true\n";
  cfg << "}\n";
  cfg.close();

  // Verify manually that our main logic (which we can't easily unit test without refactoring main) work.
  // However, we can invoke the binary via system() or just trust integration test.
  // Ideally we unit test `load_config` but it's in main.cpp anonymous namespace.
  // So this test file is primarily for Integration Testing via CTest if we run the binary.
  // But `test_new_features_iter1` is compiled as an executable linked to `vglog-filter-lib`.
  // `vglog-filter-lib` does NOT contain `main.cpp`.
  // So `load_config` is NOT available here.

  // We can only test library components here: Options, LogFilter, LogWriter.

  std::cout << "SKIP: Config loading test requires main binary integration logic.\n";
  // We tested adding fields to options.h, so we can test that they exist.
  return true;
}

bool test_time_filtering_logic() {
  // Test LogFilter with time options
  FilterConfig config;
  config.timeAfter = "12:00:00";
  config.timeBefore = "13:00:00";
  LogFilter filter(config);

  LogEntry early;
  early.timestamp = "11:59:59.999";
  early.errorType = "Error";

  LogEntry late;
  late.timestamp = "13:00:01.000";
  late.errorType = "Error";

  LogEntry middle;
  middle.timestamp = "12:30:00.000";
  middle.errorType = "Error";

  LogEntry no_time;
  no_time.errorType = "Error";

  if (filter.shouldKeep(early)) {
    std::cout << "FAIL: Early entry should be rejected\n";
    return false;
  }
  if (filter.shouldKeep(late)) {
    std::cout << "FAIL: Late entry should be rejected\n";
    return false;
  }
  if (!filter.shouldKeep(middle)) {
    std::cout << "FAIL: Middle entry should be kept\n";
    return false;
  }
  if (filter.shouldKeep(no_time)) {
    std::cout << "FAIL: No-time entry should be rejected when time filter active\n";
    return false;
  }

  std::cout << "PASS: Time filtering logic\n";
  return true;
}

bool test_stack_pattern_inclusion() {
  FilterConfig config;
  config.includeStackPatterns = {"my_func", "special_.*_handler"};
  LogFilter filter(config);

  LogEntry match1;
  match1.errorType = "Error";
  match1.stackTrace = {"at 0x123: my_func (file.c:1)"};

  LogEntry match2;
  match2.errorType = "Error";
  match2.stackTrace = {"at 0x456: special_io_handler (file.c:2)"};

  LogEntry no_match;
  no_match.errorType = "Error";
  no_match.stackTrace = {"at 0x789: other_func (file.c:3)"};

  if (!filter.shouldKeep(match1)) {
    std::cout << "FAIL: match1 should be kept\n";
    return false;
  }
  if (!filter.shouldKeep(match2)) {
    std::cout << "FAIL: match2 should be kept\n";
    return false;
  }
  if (filter.shouldKeep(no_match)) {
    std::cout << "FAIL: no_match should be rejected\n";
    return false;
  }

  std::cout << "PASS: Stack pattern inclusion logic\n";
  return true;
}

int main() {
  std::cout << "Running Iteration 1 Feature Tests...\n";
  bool pass = true;
  pass &= test_time_filtering_logic();
  pass &= test_stack_pattern_inclusion();
  // Color and StatsJson functionality is in LogWriter, which prints to file/stdout.
  // Hard to unit test without mocking file system or capturing stdout.

  return pass ? 0 : 1;
}
