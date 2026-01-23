#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <iostream>
#include <sstream>
#include <string>

bool testMaxErrors() {
  Options opt;
  opt.maxErrors = 2;
  LogProcessor processor(opt);

  std::string block = "==12345== Invalid read\n==12345==    at 0x1: f1 (a.c:1)\n";
  std::string input_buffer;
  for (int i = 0; i < 4; ++i)
    input_buffer += block;
  std::stringstream input_stream(input_buffer);

  processor.processStream(input_stream);

  if (processor.getStats().blocksFound != 2) {
    std::cerr << "Max errors failed. Found: " << processor.getStats().blocksFound << std::endl;
    std::cerr << "Lines read: " << processor.getStats().linesRead << std::endl;
    std::cerr << "Bytes processed: " << processor.getStats().bytesProcessed << std::endl;
    return false;
  }

  TEST_PASS("Max Errors");
  return true;
}

bool testIncludeFilter() {
  Options opt;
  opt.includeTypes.push_back("KeepMe");

  LogProcessor processor(opt);
  std::string b1 = "==12345== KeepMe error\n==12345==    at 0x1: f (f.c:1)\n";
  std::string b2 = "==12345== DropMe error\n==12345==    at 0x1: f (f.c:1)\n";

  std::stringstream input_stream(b1 + b2);

  processor.processStream(input_stream);

  if (processor.getStats().blocksFound != 1) {
    std::cerr << "Include filter failed. Found: " << processor.getStats().blocksFound
              << std::endl;
    std::cerr << "Lines read: " << processor.getStats().linesRead << std::endl;
    return false;
  }

  TEST_PASS("Include Filter");
  return true;
}

bool testExcludeFunction() {
  Options opt;
  opt.excludeFunctions.push_back("badFunc");

  LogProcessor processor(opt);
  std::string b1 = "==12345== Error\n==12345==    at 0x1: goodFunc (f.c:1)\n";
  std::string b2 = "==12345== Error\n==12345==    at 0x1: badFunc (f.c:1)\n";

  std::stringstream input_stream(b1 + b2);

  processor.processStream(input_stream);

  if (processor.getStats().blocksFound != 1) {
    std::cerr << "Exclude function failed. Found: " << processor.getStats().blocksFound
              << std::endl;
    std::cerr << "Lines read: " << processor.getStats().linesRead << std::endl;
    return false;
  }

  TEST_PASS("Exclude Function");
  return true;
}

int main() {
  bool passed = true;
  passed &= testMaxErrors();
  passed &= testIncludeFilter();
  passed &= testExcludeFunction();

  if (passed) {
    std::cout << "Iter1 Feat Tests Passed\n";
    return 0;
  }
  return 1;
}
