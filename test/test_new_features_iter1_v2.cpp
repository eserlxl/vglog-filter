#include "log_entry.h"
#include "log_filter.h"
#include "options.h"
#include "test_helpers.h"
#include "time_utils.h"
#include <iostream>
#include <vector>

bool test_time_normalization() {
  TEST_ASSERT(time_utils::normalizeTimestamp("foo 12:34:56 bar") == "12:34:56",
              "Normalize with context");
  TEST_ASSERT(time_utils::normalizeTimestamp("12:34:56.789") == "12:34:56.789", "Normalize exact");
  TEST_ASSERT(time_utils::normalizeTimestamp("simple") == "simple", "Normalize fallback");
  TEST_PASS("Time normalization works");
  return true;
}

bool test_time_comparison() {
  TEST_ASSERT(time_utils::isAfter("12:34:57", "12:34:56"), "isAfter true");
  TEST_ASSERT(!time_utils::isAfter("12:34:56", "12:34:57"), "isAfter false");
  TEST_ASSERT(time_utils::isBefore("09:00:00", "10:00:00"), "isBefore true");
  TEST_PASS("Time comparison works");
  return true;
}

bool test_include_source_paths() {
  FilterConfig cfg;
  cfg.includeSourcePaths = {"user_code.cpp", "important.c"};

  LogFilter filter(cfg);

  LogEntry entry1;
  entry1.stackFrames.push_back({"raw", "0x1", "main", "main.cpp:50"});
  // Should fail because main.cpp is not in include list
  if (filter.shouldKeep(entry1)) {
    std::cerr << "Entries without matching source path should be filtered out\n";
    return false;
  }

  LogEntry entry2;
  entry2.stackFrames.push_back({"raw", "0x2", "foo", "user_code.cpp:10"});
  // Should pass
  TEST_ASSERT(filter.shouldKeep(entry2), "Matching source path should be kept");

  TEST_PASS("Include source paths works");
  return true;
}

int main() {
  std::cout << "Running Iteration 1 Feature Tests..." << std::endl;
  bool all_passed = true;
  all_passed &= test_time_normalization();
  all_passed &= test_time_comparison();
  all_passed &= test_include_source_paths();

  if (all_passed) {
    std::cout << "\nAll new feature tests passed!" << std::endl;
    return 0;
  } else {
    std::cout << "\nSome tests failed!" << std::endl;
    return 1;
  }
}
