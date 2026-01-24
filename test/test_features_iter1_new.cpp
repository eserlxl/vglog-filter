// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "file_utils.h"
#include "log_processor.h"
#include "options.h"
#include "signal_handler.h"
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// Regression test for IO safety and new CamelCase API
bool test_file_utils_api() {
  std::string tmp = "test_file_utils_api.tmp";
  {
    std::ofstream ofs(tmp);
    ofs << "Line 1\nLine 2\n";
  }

  // Test new API names
  if (!isLargeFile(tmp)) {
    // Expected for small file
  } else {
    std::cerr << "FAIL: isLargeFile reported true for small file\n";
    return false;
  }

  size_t sz = getFileSizeBytes(tmp);
  if (sz == 0) {
    std::cerr << "FAIL: getFileSizeBytes returned 0\n";
    return false;
  }

  auto lines = readFileLines(tmp);
  if (lines.size() != 2) {
    std::cerr << "FAIL: readFileLines returned " << lines.size() << " lines\n";
    return false;
  }

  std::filesystem::remove(tmp);
  std::cout << "PASS: FileUtils API (CamelCase)\n";
  return true;
}

// Check SignalHandler API
bool test_signal_handler_api() {
  SignalHandler::install();
  if (SignalHandler::isStopRequested()) {
    std::cerr << "FAIL: SignalHandler reported stop without signal\n";
    return false;
  }
  std::cout << "PASS: SignalHandler API\n";
  return true;
}

int main() {
  std::cout << "Running Iteration 1 Feature Tests...\n";
  bool pass = true;
  pass &= test_file_utils_api();
  pass &= test_signal_handler_api();
  return pass ? 0 : 1;
}
