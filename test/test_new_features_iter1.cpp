#include "log_entry.h"
#include "log_parser.h"
#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

bool test_has_frame_predicate() {
  LogEntry entry;
  entry.stackFrames.push_back({"raw", "0x123", "myFunc", "file.cpp:10"});
  entry.stackFrames.push_back({"raw", "0x456", "otherFunc", "other.cpp:20"});

  bool found = entry.hasFrame([](const LogEntry::StackFrame& f) { return f.function == "myFunc"; });
  TEST_ASSERT(found, "Should find myFunc");

  found = entry.hasFrame([](const LogEntry::StackFrame& f) {
    return f.location.find("other.cpp") != std::string::npos;
  });
  TEST_ASSERT(found, "Should find other.cpp");

  found = entry.hasFrame([](const LogEntry::StackFrame& f) { return f.function == "missing"; });
  TEST_ASSERT(!found, "Should NOT find missing");

  TEST_PASS("test_has_frame_predicate");
  return true;
}

bool test_max_errors() {
  Options opt;
  opt.trim = false;
  opt.filter.maxErrors = 2;
  LogProcessor processor(opt);

  std::string input;
  // create 5 error blocks
  for (int i = 0; i < 5; ++i) {
    input += "==12345== Invalid read of size 4\n==12345==    at 0x1: main (f.c:1)\n\n";
  }

  std::stringstream ss(input);
  processor.processStream(ss);

  const auto& stats = processor.getStats();
  TEST_ASSERT(stats.blocksFound == 2u, "Should stop at 2 blocks");

  TEST_PASS("test_max_errors");
  return true;
}

bool test_include_types() {
  Options opt;
  opt.trim = false;
  opt.filter.includeTypes.push_back("Invalid read");
  LogProcessor processor(opt);

  // Use LogProcessor::processLines for simplified testing
  std::vector<std::string> lines;
  auto add_block = [&](const std::string& type) {
    lines.push_back("==100== " + type);
    lines.push_back("==100==    at 0x1: f (f.c:1)");
    lines.push_back("");
  };

  add_block("Invalid read of size 4");  // Keep
  add_block("Invalid write of size 4"); // Drop
  add_block("Conditional jump");        // Drop
  add_block("Invalid read of size 8");  // Keep

  processor.processLines(lines);

  const auto& stats = processor.getStats();
  // stats.blocksFound counts found *before* filtering?
  // Let's check implementation again.
  // Line 361: stats.blocksFound++;
  // Line 372: if (!shouldKeepEntry) { stats.filteredCount++; ... return; }
  // Line 378: if (seen.insert()...) { stats.uniqueBlocks++; ... }

  // So:
  // blocksFound should be 4 (total blocks in input)
  // filteredCount should be 2 (write + jump)
  // uniqueBlocks should be 2 (read4 + read8 are unique)
  // errorCounts should contain 2 entries (types)

  TEST_ASSERT(stats.blocksFound == 4u, "Found 4 blocks total");
  TEST_ASSERT(stats.filteredCount == 2u, "Filtered 2 blocks");
  TEST_ASSERT(stats.uniqueBlocks == 2u, "Kept 2 unique blocks");

  TEST_PASS("test_include_types");
  return true;
}

bool test_pid_stats() {
  Options opt;
  opt.trim = false;
  LogProcessor processor(opt);

  std::vector<std::string> lines;
  lines.push_back("==100== Invalid read");
  lines.push_back("==100==    at 0x1: f (f.c:1)");
  lines.push_back("");

  lines.push_back("==200== Invalid write");
  lines.push_back("==200==    at 0x1: f (f.c:1)");
  lines.push_back("");

  processor.processLines(lines);

  const auto& stats = processor.getStats();
  TEST_ASSERT(stats.errorCountsByPid.size() == 2u, "Should track 2 PIDs");
  TEST_ASSERT(stats.errorCountsByPid.at(100) == 1u, "PID 100 count 1");
  TEST_ASSERT(stats.errorCountsByPid.at(200) == 1u, "PID 200 count 1");

  TEST_PASS("test_pid_stats");
  return true;
}

int main() {
  std::cout << "Running Iteration 1 Feature Tests..." << std::endl;

  bool all_passed = true;
  all_passed &= test_has_frame_predicate();
  all_passed &= test_max_errors();
  all_passed &= test_include_types();
  all_passed &= test_pid_stats();

  if (all_passed) {
    std::cout << "\nAll Iteration 1 tests passed!" << std::endl;
    return 0;
  } else {
    std::cout << "\nSome tests failed!" << std::endl;
    return 1;
  }
}
