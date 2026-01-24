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

  void writeRaw(const std::string&) override {}
  void setUseColor(bool) override {}
  void flush() override {}
  void writeDiffSummary(const DiffEngine::DiffStats&) override {}
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

bool test_regex_exclude_type() {
  Options opt;
  opt.filter.excludeTypesRegex.push_back("Inv.*read"); // Regex for Invalid read

  LogFilter filter(opt.filter);

  LogEntry e1;
  e1.errorType = "Invalid read of size 4";
  LogEntry e2;
  e2.errorType = "Conditional jump";

  if (filter.shouldKeep(e1)) {
    std::cout << "FAIL: Regex exclude type failed (kept matched)\n";
    return false;
  }
  if (!filter.shouldKeep(e2)) {
    std::cout << "FAIL: Regex exclude type failed (discarded unmatched)\n";
    return false;
  }
  std::cout << "PASS: Regex Exclude Type\n";
  return true;
}

bool test_regex_include_function() {
  Options opt;
  opt.filter.includeFunctionsRegex.push_back("^my_.*_func$");

  LogFilter filter(opt.filter);

  LogEntry e1;
  e1.errorType = "Any";
  e1.stackFrames.push_back({"raw", "0x1", "my_cool_func", "f.c:1"});

  LogEntry e2;
  e2.errorType = "Any";
  e2.stackFrames.push_back({"raw", "0x2", "other_func", "f.c:2"});

  if (!filter.shouldKeep(e1)) {
    std::cout << "FAIL: Regex include function failed (discarded matched)\n";
    return false;
  }
  if (filter.shouldKeep(e2)) {
    std::cout << "FAIL: Regex include function failed (kept unmatched)\n";
    return false;
  }
  std::cout << "PASS: Regex Include Function\n";
  return true;
}

bool test_regex_exclude_function() {
  Options opt;
  opt.filter.excludeFunctionsRegex.push_back("bad_.*");

  LogFilter filter(opt.filter);

  LogEntry e1;
  e1.stackFrames.push_back({"raw", "0x1", "bad_alloc", "f.c:1"});

  LogEntry e2;
  e2.stackFrames.push_back({"raw", "0x2", "good_alloc", "f.c:2"});

  if (filter.shouldKeep(e1)) {
    std::cout << "FAIL: Regex exclude function failed (kept matched)\n";
    return false;
  }
  if (!filter.shouldKeep(e2)) {
    std::cout << "FAIL: Regex exclude function failed (discarded unmatched)\n";
    return false;
  }
  std::cout << "PASS: Regex Exclude Function\n";
  return true;
}

int main() {
  std::cout << "Running Iteration 3 Mock Tests...\n";
  bool pass = true;
  pass &= test_deduplication_mock();
  pass &= test_regex_exclude_type();
  pass &= test_regex_include_function();
  pass &= test_regex_exclude_function();
  return pass ? 0 : 1;
}
