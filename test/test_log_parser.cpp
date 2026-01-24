#include "log_parser.h"
#include "test_helpers.h"
#include <cassert>
#include <iostream>
#include <string>
#include <string_view>

bool test_parseHeader_simple() {
  auto res = LogParser::parseHeader("==12345== Invalid read of size 4");
  TEST_ASSERT(res.has_value(), "Should parse valid header");
  TEST_ASSERT(res->pid == 12345, "PID should be 12345");
  TEST_ASSERT(res->errorType == "Invalid read of size 4", "Error type should match");
  TEST_ASSERT(!res->tid.has_value(), "Should not have TID");
  TEST_PASS("Simple header parsing");
  return true;
}

bool test_parseHeader_whitespace() {
  auto res = LogParser::parseHeader(
      "==999==    Conditional jump or move depends on uninitialised value(s)  ");
  TEST_ASSERT(res.has_value(), "Should parse header with spacing");
  TEST_ASSERT(res->pid == 999, "PID should be 999");
  // Trailing whitespace should be trimmed by our logic
  TEST_ASSERT(res->errorType == "Conditional jump or move depends on uninitialised value(s)",
              "Error type trimmed");
  TEST_PASS("Header parsing with whitespace");
  return true;
}

bool test_parseHeader_tid() {
  auto res = LogParser::parseHeader("==123== Thread 2: Invalid read");
  TEST_ASSERT(res.has_value(), "Should parse TID header");
  TEST_ASSERT(res->pid == 123, "PID 123");
  TEST_ASSERT(res->tid.has_value() && *res->tid == 2, "TID should be 2");
  TEST_ASSERT(res->errorType == "Invalid read", "Error type should strip TID prefix");

  auto res2 = LogParser::parseHeader("==123== Thread 99: Process terminating");
  TEST_ASSERT(res2->tid.has_value() && *res2->tid == 99, "TID should be 99");
  TEST_ASSERT(res2->errorType == "Process terminating", "Error type correct");

  // Test no-prefix parsing
  auto res3 = LogParser::parseHeader("Thread 5: Error");
  TEST_ASSERT(res3.has_value(), "Should parse no-prefix Thread ID");
  TEST_ASSERT(res3->tid.has_value() && *res3->tid == 5, "TID 5 extracted from raw line");

  TEST_PASS("Header parsing with TID");
  return true;
}

bool test_parseHeader_relaxed() {
  // Relaxed: non-valgrind lines are treated as raw content headers with no PID/TID
  auto res = LogParser::parseHeader("Not a valgrind line");
  TEST_ASSERT(res.has_value(), "Should accept raw lines now");
  TEST_ASSERT(res->pid == 0, "No PID");
  TEST_ASSERT(res->errorType == "Not a valgrind line", "Content preserved");

  // Empty line check
  TEST_ASSERT(!LogParser::parseHeader("").has_value(), "Empty line still invalid");

  TEST_PASS("Relaxed header parsing");
  return true;
}

bool test_stack_frame() {
  // "==12345==    at 0x4C29F73: malloc (vg_replace_malloc.c:299)"
  // LogParser::parseStackFrame expects the full line.
  std::string line = "==12345==    at 0x4C29F73: malloc (vg_replace_malloc.c:299)";
  auto res = LogParser::parseStackFrame(line);
  TEST_ASSERT(res.has_value(), "Should parse stack frame");
  TEST_ASSERT(res->find("at 0x") != std::string::npos, "Should contain 'at 0x'");
  TEST_ASSERT(res->find("==12345==") == std::string::npos, "Should not contain PID prefix");

  std::string line2 = "==12345==    by 0x4005B6: main (test.c:10)";
  auto res2 = LogParser::parseStackFrame(line2);
  TEST_ASSERT(res2.has_value(), "Should parse 'by' frame");
  TEST_PASS("Stack frame parsing");
  return true;
}

bool test_removePrefix() {
  std::string line = "==12345== Hello World";
  TEST_ASSERT(LogParser::removePrefix(line) == "Hello World", "Should remove prefix");

  std::string line2 = "==123==  Spaced";
  TEST_ASSERT(LogParser::removePrefix(line2) == "Spaced", "Should remove prefix and space");

  std::string line3 = "No prefix";
  TEST_ASSERT(LogParser::removePrefix(line3) == "No prefix",
              "Should return original if no prefix");

  TEST_PASS("Prefix removal");
  return true;
}

bool test_stack_frame_structured() {
  // Case 1: Standard at
  auto res1 = LogParser::parseFrameStructured(
      "==123==    at 0x4C29F73: malloc (vg_replace_malloc.c:299)");
  TEST_ASSERT(res1.has_value(), "Should parse case 1");
  TEST_ASSERT(res1->address == "0x4C29F73", "Address 1 mismatch");
  TEST_ASSERT(res1->function == "malloc", "Function 1 mismatch");
  TEST_ASSERT(res1->location == "vg_replace_malloc.c:299", "Location 1 mismatch");

  // Case 2: Standard by
  auto res2 = LogParser::parseFrameStructured("==123==    by 0x4005B6: main (test.c:10)");
  TEST_ASSERT(res2.has_value(), "Should parse case 2");
  TEST_ASSERT(res2->address == "0x4005B6", "Address 2 mismatch");
  TEST_ASSERT(res2->function == "main", "Function 2 mismatch");
  TEST_ASSERT(res2->location == "test.c:10", "Location 2 mismatch");

  // Case 3: Library (no line)
  auto res3 = LogParser::parseFrameStructured("==123==    by 0x500: ??? (in /usr/lib/libc.so)");
  TEST_ASSERT(res3.has_value(), "Should parse case 3");
  TEST_ASSERT(res3->function == "???", "Function 3 mismatch");
  TEST_ASSERT(res3->location == "in /usr/lib/libc.so", "Location 3 mismatch");

  // Case 3b: Vendor path
  auto res3b =
      LogParser::parseFrameStructured("==123==    at 0x500: bad (vendor/lib3rd/bad.c:20)");
  TEST_ASSERT(res3b.has_value(), "Should parse vendor case");
  TEST_ASSERT(res3b->location == "vendor/lib3rd/bad.c:20", "Location vendor mismatch");

  // Case 4: Invalid
  auto res4 = LogParser::parseFrameStructured("Not a stack frame");
  TEST_ASSERT(!res4.has_value(), "Should fail invalid frame");

  TEST_PASS("Structured stack frame parsing");
  return true;
}

int main() {
  bool all_passed = true;
  all_passed &= test_parseHeader_simple();
  all_passed &= test_parseHeader_whitespace();
  all_passed &= test_parseHeader_relaxed();
  all_passed &= test_stack_frame();
  all_passed &= test_removePrefix();
  all_passed &= test_parseHeader_tid();
  all_passed &= test_stack_frame_structured();

  if (all_passed) {
    std::cout << "All LogParser tests passed!" << std::endl;
    return 0;
  }
  return 1;
}
