#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <cstdio>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

bool test_max_errors() {
  Options opt;
  opt.maxErrors = 2;
  LogProcessor processor(opt);

  std::string block = "==12345== Invalid read\n==12345==    at 0x1: f1 (a.c:1)\n";
  std::string input_buffer;
  for (int i = 0; i < 4; ++i)
    input_buffer += block;
  std::stringstream input_stream(input_buffer);

  processor.process_stream(input_stream);

  if (processor.get_stats().blocks_found != 2) {
    std::cerr << "Max errors failed. Found: " << processor.get_stats().blocks_found << std::endl;
    std::cerr << "Lines read: " << processor.get_stats().lines_read << std::endl;
    std::cerr << "Bytes processed: " << processor.get_stats().bytes_processed << std::endl;
    return false;
  }

  TEST_PASS("Max Errors");
  return true;
}

bool test_include_filter() {
  Options opt;
  opt.includeTypes.push_back("KeepMe");

  LogProcessor processor(opt);
  std::string b1 = "==12345== KeepMe error\n==12345==    at 0x1: f (f.c:1)\n";
  std::string b2 = "==12345== DropMe error\n==12345==    at 0x1: f (f.c:1)\n";

  std::stringstream input_stream(b1 + b2);

  processor.process_stream(input_stream);

  if (processor.get_stats().blocks_found != 1) {
    std::cerr << "Include filter failed. Found: " << processor.get_stats().blocks_found
              << std::endl;
    std::cerr << "Lines read: " << processor.get_stats().lines_read << std::endl;
    return false;
  }

  TEST_PASS("Include Filter");
  return true;
}

bool test_exclude_function() {
  Options opt;
  opt.excludeFunctions.push_back("badFunc");

  LogProcessor processor(opt);
  std::string b1 = "==12345== Error\n==12345==    at 0x1: goodFunc (f.c:1)\n";
  std::string b2 = "==12345== Error\n==12345==    at 0x1: badFunc (f.c:1)\n";

  std::stringstream input_stream(b1 + b2);

  processor.process_stream(input_stream);

  if (processor.get_stats().blocks_found != 1) {
    std::cerr << "Exclude function failed. Found: " << processor.get_stats().blocks_found
              << std::endl;
    std::cerr << "Lines read: " << processor.get_stats().lines_read << std::endl;
    return false;
  }

  TEST_PASS("Exclude Function");
  return true;
}

int main() {
  bool passed = true;
  passed &= test_max_errors();
  passed &= test_include_filter();
  passed &= test_exclude_function();

  if (passed) {
    std::cout << "Iter1 Feat Tests Passed\n";
    return 0;
  }
  return 1;
}
