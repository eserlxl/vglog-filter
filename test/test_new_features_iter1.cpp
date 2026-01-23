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
  // kept 2 blocks (read 4 and read 8)
  TEST_ASSERT(stats.uniqueBlocks == 2u, "Kept 2 unique blocks");
  TEST_ASSERT(stats.filteredCount == 2u, "Filtered 2 blocks");

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
  // Invalid read + Invalid write = 2 blocks
  TEST_ASSERT(stats.errorCountsByPid.size() == 2u, "Should track 2 PIDs");
  TEST_ASSERT(stats.errorCountsByPid.at(100) == 1u, "PID 100 count 1");
  TEST_ASSERT(stats.errorCountsByPid.at(200) == 1u, "PID 200 count 1");

  TEST_PASS("test_pid_stats");
  return true;
}

bool test_timestamp_parsing() {
  std::string line = "==12345== 01:23:45 MyError";
  auto res = LogParser::parseHeader(LogParser::removePrefix(line));
  TEST_ASSERT(res.has_value(), "Should parse header");
  TEST_ASSERT(res->timestamp.has_value(), "Should have timestamp");
  TEST_ASSERT(*res->timestamp == "01:23:45", "Timestamp should match");
  TEST_ASSERT(res->errorType == "MyError", "Error type should match");

  // Multilevel timestamp
  line = "==12345== 01:23:45.678 MyError";
  res = LogParser::parseHeader(LogParser::removePrefix(line));
  TEST_ASSERT(*res->timestamp == "01:23:45.678", "Timestamp ms should match");

  // No timestamp
  line = "==12345== MyError";
  res = LogParser::parseHeader(LogParser::removePrefix(line));
  TEST_ASSERT(!res->timestamp.has_value(), "Should not have timestamp");

  TEST_PASS("test_timestamp_parsing");
  return true;
}

bool test_primary_frame() {
  LogEntry entry;
  entry.stackFrames = {{"", "", "malloc", ""},
                       {"", "", "operator new", ""},
                       {"", "", "my_func", "file.cpp:10"},
                       {"", "", "main", "main.cpp:5"}};

  auto* f = entry.getPrimaryFrame({"malloc", "operator new"});
  TEST_ASSERT(f != nullptr, "Should find frame");
  TEST_ASSERT(f->function == "my_func", "Should be my_func");

  f = entry.getPrimaryFrame({"malloc", "operator new", "my_func", "main"});
  TEST_ASSERT(f == nullptr, "Should return nullptr if all excluded");

  TEST_PASS("test_primary_frame");
  return true;
}

bool test_pid_filters() {
  Options opt;
  opt.trim = false;

  // Test Include PID
  opt.filter.includePids = {100};
  {
    LogProcessor p(opt);
    std::vector<std::string> lines;
    // Use "Invalid read" to trigger block start
    lines.push_back("==100== Invalid read");
    lines.push_back("==100== at f");
    lines.push_back("");
    lines.push_back("==200== Invalid read");
    lines.push_back("==200== at f");
    lines.push_back("");
    p.processLines(lines);
    TEST_ASSERT(p.getStats().uniqueBlocks == 1u, "Should keep only PID 100");
    TEST_ASSERT(p.getStats().filteredCount == 1u, "Should filter PID 200");
  }

  // Test Exclude PID
  opt.filter.includePids.clear();
  opt.filter.excludePids = {100};
  {
    LogProcessor p(opt);
    std::vector<std::string> lines;
    lines.push_back("==100== Invalid read");
    lines.push_back("==100== at f");
    lines.push_back("");
    lines.push_back("==200== Invalid read");
    lines.push_back("==200== at f");
    lines.push_back("");
    p.processLines(lines);
    TEST_ASSERT(p.getStats().uniqueBlocks == 1u, "Should keep only PID 200");
    TEST_ASSERT(p.getStats().filteredCount == 1u, "Should filter PID 100");
  }

  TEST_PASS("test_pid_filters");
  return true;
}

bool test_thread_filters() {
  Options opt;
  opt.trim = false;
  opt.filter.includeThreads = {2};

  LogProcessor p(opt);
  std::vector<std::string> lines;
  lines.push_back("==100== Thread 1: Invalid read");
  lines.push_back("==100== at f");
  lines.push_back("");
  lines.push_back("==100== Thread 2: Invalid read");
  lines.push_back("==100== at f");
  lines.push_back("");
  lines.push_back("==100== Thread 3: Invalid read");
  lines.push_back("==100== at f");
  lines.push_back("");

  p.processLines(lines);
  TEST_ASSERT(p.getStats().uniqueBlocks == 1u, "Should keep only Thread 2");
  TEST_ASSERT(p.getStats().filteredCount == 2u, "Should filter others");

  TEST_PASS("test_thread_filters");
  return true;
}

int main() {
  std::cout << "Running Iteration 1 Feature Tests..." << std::endl;

  bool all_passed = true;
  all_passed &= test_has_frame_predicate();
  all_passed &= test_max_errors();
  all_passed &= test_include_types();
  all_passed &= test_pid_stats();
  all_passed &= test_timestamp_parsing();
  all_passed &= test_primary_frame();
  all_passed &= test_pid_filters();
  all_passed &= test_thread_filters();

  if (all_passed) {
    std::cout << "\nAll Iteration 1 tests passed!" << std::endl;
    return 0;
  } else {
    std::cout << "\nSome tests failed!" << std::endl;
    return 1;
  }
}
