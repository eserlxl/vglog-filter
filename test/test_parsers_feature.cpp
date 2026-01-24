#include "parsers/valgrind_parser.h"
#include "parsers/asan_parser.h"
#include "test_helpers.h"
#include <iostream>
#include <string>
#include <vector>

using namespace parsers;

bool test_valgrind_parser() {
  ValgrindParser parser;
  
  // Test Block Start
  std::vector<std::string> valid_starts = {
      "==123== Invalid read of size 4",
      "==123== Conditional jump or move depends on uninitialised value(s)",
      "==123== bytes in 1 blocks are definitely lost"
  };
  
  for (const auto& line : valid_starts) {
    TEST_ASSERT(parser.isBlockStart(line), "Should be block start: " + line);
    TEST_ASSERT(parser.isRelevant(line), "Should be relevant: " + line);
  }
  
  std::string not_start = "==123==    at 0x4C29F73: malloc (vg_replace_malloc.c:299)";
  TEST_ASSERT(!parser.isBlockStart(not_start), "Stack frame is not block start");
  TEST_ASSERT(parser.isRelevant(not_start), "Stack frame IS relevant");
  
  TEST_ASSERT(!parser.isRelevant("Just some noise"), "Noise is not relevant");
  
  // Test PID Extraction
  auto pid = parser.extractPid("==12345== Error");
  TEST_ASSERT(pid.has_value() && *pid == 12345, "Should extract PID 12345");
  
  TEST_PASS("ValgrindParser");
  return true;
}

bool test_asan_parser() {
  AsanParser parser;
  
  // Test Block Start
  std::string start1 = "=================================================================";
  TEST_ASSERT(parser.isBlockStart(start1), "Separator block start");
  
  std::string start2 = "==12345==ERROR: AddressSanitizer: heap-use-after-free on address 0x60b000000040";
  TEST_ASSERT(parser.isBlockStart(start2), "Explicit ASAN Error start");
  
  std::string stack = "    #0 0x7f1a2b3c4d in free /usr/include/stdlib.h:10";
  TEST_ASSERT(!parser.isBlockStart(stack), "Stack frame not start");
  TEST_ASSERT(parser.isRelevant(stack), "Stack frame is relevant");
  
  // Test Parsing
  std::string block = 
      "==1==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x...\n"
      "READ of size 4 at 0x...\n"
      "    #0 0x123 in main /src/main.cpp:25\n"
      "    #1 0x456 in _start /lib/libc.so\n";
      
  auto entry = parser.parseBlock(block);
  TEST_ASSERT(entry.pid == 1, "Parsed PID 1");
  TEST_ASSERT(entry.errorType == "heap-buffer-overflow", "Parsed Type");
  TEST_ASSERT(entry.stackFrames.size() == 2, "Parsed 2 frames");
  TEST_ASSERT(entry.stackFrames[0].function == "main", "Parsed function main");
  TEST_ASSERT(entry.stackFrames[0].location == "/src/main.cpp:25", "Parsed location");
  
  TEST_PASS("AsanParser");
  return true;
}

int main() {
  bool all = true;
  all &= test_valgrind_parser();
  all &= test_asan_parser();
  
  if (all) {
      std::cout << "All Parser Features Passed" << std::endl;
      return 0;
  }
  return 1;
}
