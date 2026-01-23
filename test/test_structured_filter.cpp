#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <cassert>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

int count_blocks_in_file(const std::string& filename) {
  std::ifstream f(filename);
  std::string line;
  int count = 0;
  while (std::getline(f, line)) {
    if (line.find("\"type\":\"record\"") != std::string::npos) {
      count++;
    }
  }
  return count;
}

bool test_filter_types() {
  std::string outputFile = "test_filter_types.json";
  Options opt;
  opt.jsonOutput = true;
  opt.trim = false;
  opt.outputFile = outputFile;
  opt.filter.excludeTypes.push_back("Process terminating");

  {
    LogProcessor processor(opt);

    std::string block1 = "==123== Invalid read of size 4\n==123==    at 0x400: main (test.c:10)\n";
    std::string block2 = "==123== Process terminating with default action of signal 11\n==123==    "
                         "at 0x400: raise (raise.c:1)\n";

    std::vector<std::string> lines;
    std::stringstream ss(block1 + block2);
    std::string line;
    while (std::getline(ss, line))
      lines.push_back(line);

    processor.processLines(lines);
  } // processor destroyed, file flushed and closed

  // Check output
  int count = count_blocks_in_file(outputFile);
  if (count != 1) {
    std::cerr << "test_filter_types: Expected 1 block, got " << count << "\n";
    std::ifstream f(outputFile);
    std::cout << "File Content:\n" << f.rdbuf() << "\n";
  }
  TEST_ASSERT(count == 1, "Should filter out one block");

  std::string content = read_file_to_string(outputFile);
  TEST_ASSERT(content.find("Invalid read") != std::string::npos, "Should keep Invalid read");
  TEST_ASSERT(content.find("Process terminating") == std::string::npos,
              "Should exclude Process terminating");

  std::remove(outputFile.c_str());
  TEST_PASS("Type filtering");
  return true;
}

bool test_filter_stack_regex() {
  std::string outputFile = "test_filter_stack.json";
  Options opt;
  opt.jsonOutput = true;
  opt.trim = false;
  opt.outputFile = outputFile;
  opt.filter.excludeStackPatterns.push_back(".*libcursed.*");

  {
    LogProcessor processor(opt);

    std::string block1 = "==123== Invalid read\n==123==    at 0x400: main (test.c:10)\n";
    std::string block2 =
        "==123== Invalid write\n==123==    at 0x500: evil_func (libcursed.so:99)\n";

    std::vector<std::string> lines;
    std::stringstream ss(block1 + block2);
    std::string line;
    while (std::getline(ss, line))
      lines.push_back(line);

    processor.processLines(lines);
  } // processor destroyed, file flushed and closed

  int count = count_blocks_in_file(outputFile);
  if (count != 1) {
    std::cerr << "test_filter_stack_regex: Expected 1 block, got " << count << "\n";
    std::ifstream f(outputFile);
    std::cout << "File Content:\n" << f.rdbuf() << "\n";
  }
  TEST_ASSERT(count == 1, "Should filter out stack-matched block");

  std::string content = read_file_to_string(outputFile);
  TEST_ASSERT(content.find("Invalid read") != std::string::npos, "Should keep Block 1");
  TEST_ASSERT(content.find("Invalid write") == std::string::npos, "Should exclude Block 2");

  std::remove(outputFile.c_str());
  TEST_PASS("Stack Regex filtering");
  return true;
}

bool test_filter_tid() {
  std::string outputFile = "test_filter_tid.json";
  Options opt;
  opt.jsonOutput = true;
  opt.trim = false;
  opt.outputFile = outputFile;
  opt.filter.excludeThreads.push_back(2);

  {
    LogProcessor processor(opt);

    std::string block1 = "==123== Thread 1: Invalid read\n==123==    at 0x400: main (test.c:10)\n";
    std::string block2 = "==123== Thread 2: Invalid write\n==123==    at 0x500: bad (test.c:20)\n";

    std::vector<std::string> lines;
    std::stringstream ss(block1 + block2);
    std::string line;
    while (std::getline(ss, line))
      lines.push_back(line);

    processor.processLines(lines);
  }

  int count = count_blocks_in_file(outputFile);
  TEST_ASSERT(count == 1, "Should filter out Thread 2");

  std::string content = read_file_to_string(outputFile);
  TEST_ASSERT(content.find("Invalid read") != std::string::npos, "Should keep Thread 1");
  TEST_ASSERT(content.find("Invalid write") == std::string::npos, "Should exclude Thread 2");

  std::remove(outputFile.c_str());
  TEST_PASS("Thread filtering");
  return true;
}

bool test_filter_source_path() {
  std::string outputFile = "test_filter_path.json";
  Options opt;
  opt.jsonOutput = true;
  opt.trim = false;
  // Note: scrub_raw is true by default, verifying parser handles scrubbed lines.
  opt.outputFile = outputFile;
  opt.filter.excludeSourcePaths.push_back("vendor/lib3rd");

  {
    LogProcessor processor(opt);

    std::string block1 = "==123== Invalid read\n==123==    at 0x400: main (test.c:10)\n";
    std::string block2 =
        "==123== Invalid write\n==123==    at 0x500: bad (vendor/lib3rd/bad.c:20)\n";

    std::vector<std::string> lines;
    std::stringstream ss(block1 + block2);
    std::string line;
    while (std::getline(ss, line))
      lines.push_back(line);

    processor.processLines(lines);
  }

  int count = count_blocks_in_file(outputFile);
  if (count != 1) {
    std::cerr << "test_filter_source_path: Expected 1 block, got " << count << "\n";
    std::ifstream f(outputFile);
    std::cout << "File Content:\n" << f.rdbuf() << "\n";
  }
  TEST_ASSERT(count == 1, "Should filter out vendor path");

  std::string content = read_file_to_string(outputFile);
  TEST_ASSERT(content.find("Invalid read") != std::string::npos, "Should keep Block 1");
  TEST_ASSERT(content.find("Invalid write") == std::string::npos, "Should exclude Block 2");

  std::remove(outputFile.c_str());
  TEST_PASS("Source Path filtering");
  return true;
}

int main() {
  bool passed = true;
  passed &= test_filter_types();
  passed &= test_filter_stack_regex();
  passed &= test_filter_tid();
  passed &= test_filter_source_path();

  if (passed) {
    std::cout << "All structured filter tests passed\n";
    return 0;
  } else {
    std::cerr << "Some structured filter tests failed\n";
    return 1;
  }
}
