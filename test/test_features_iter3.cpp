// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ilog_writer.h"
#include "log_entry.h"
#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"
#include <iostream>
#include <memory>
#include <vector>

// Mock Writer
class MockLogWriter : public ILogWriter {
public:
  std::vector<LogEntry> entries;

  void writeEntry(const LogEntry& entry) override {
    entries.push_back(entry);
  }

  void writeStats(const LogStats&) override {
    // no-op
  }

  void writeStatsJson(const LogStats&, const std::string&) const override {
    // no-op
  }
};

bool test_deduplication_mock() {
  Options opt;
  opt.uniqueOutput = true;
  opt.depth = 2;

  auto mockWriter = std::make_unique<MockLogWriter>();
  // Store pointer to verify later
  MockLogWriter* writerPtr = mockWriter.get();

  LogProcessor processor(opt, std::move(mockWriter));

  std::vector<std::string> lines = {
      "==123== Invalid read of size 4",       "==123==    at 0xABC: func1 (file.c:1)",
      "==123==    by 0xDEF: main (main.c:2)", "==123== ",
      "==123== Invalid read of size 4",       "==123==    at 0xABC: func1 (file.c:1)",
      "==123==    by 0xDEF: main (main.c:2)", "==123== "};

  processor.processLines(lines);
  processor.flush();

  if (writerPtr->entries.size() != 1) {
    std::cout << "FAIL: Deduplication failed. Expected 1 entry, got " << writerPtr->entries.size()
              << "\n";
    return false;
  }

  std::cout << "PASS: Deduplication with Mock\n";
  return true;
}

int main() {
  std::cout << "Running Iteration 3 Mock Tests...\n";
  bool pass = true;
  pass &= test_deduplication_mock();
  return pass ? 0 : 1;
}
