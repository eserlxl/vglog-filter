// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_entry.h" // Needed?
#include "log_filter.h"
#include "options.h"
#include "source_loader.h"
#include "test_helpers.h"
#include <cstdio>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

bool test_source_loader() {
  // Create a temp file
  std::string path = "/tmp/test_source.cpp";
  std::ofstream f(path);
  f << "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n";
  f.close();

  // Test context loading
  // Context 1 around line 3 -> 2, 3, 4
  auto ctx = SourceLoader::loadContext(path, 3, 1);
  if (ctx.size() != 3) {
    std::cout << "FAIL: Expected 3 lines, got " << ctx.size() << "\n";
    return false;
  }
  if (ctx[0] != "Line 2" || ctx[1] != "Line 3" || ctx[2] != "Line 4") {
    std::cout << "FAIL: Context content mismatch\n";
    return false;
  }

  // Test edge cases
  auto ctx2 = SourceLoader::loadContext(path, 1, 1); // 1, 2
  if (ctx2.size() != 2) {
    std::cout << "FAIL: Edge (start) expected 2 lines\n";
    return false;
  }

  std::cout << "PASS: SourceLoader\n";
  return true;
}

// Cannot easily unit test Deduplication without mocking LogWriter or verifying output file.
// But we verified logic is in LogProcessor.

int main() {
  std::cout << "Running Iteration 2 Feature Tests...\n";
  bool pass = true;
  pass &= test_source_loader();
  return pass ? 0 : 1;
}
