#include "log_parser.h"
#include "test_helpers.h"
#include <cassert>
#include <iostream>
#include <string>
#include <string_view>

bool test_parse_header_simple() {
  auto res = LogParser::parse_header("==12345== Invalid read of size 4");
  TEST_ASSERT(res.has_value(), "Should parse valid header");
  TEST_ASSERT(res->first == "12345", "PID should be 12345");
  TEST_ASSERT(res->second == "Invalid read of size 4", "Error type should match");
  TEST_PASS("Simple header parsing");
  return true;
}

bool test_parse_header_whitespace() {
  auto res = LogParser::parse_header(
      "==999==    Conditional jump or move depends on uninitialised value(s)  ");
  TEST_ASSERT(res.has_value(), "Should parse header with spacing");
  TEST_ASSERT(res->first == "999", "PID should be 999");
  // Trailing whitespace should be trimmed by our logic
  TEST_ASSERT(res->second == "Conditional jump or move depends on uninitialised value(s)",
              "Error type trimmed");
  TEST_PASS("Header parsing with whitespace");
  return true;
}

bool test_parse_header_invalid() {
  TEST_ASSERT(!LogParser::parse_header("Not a valgrind line").has_value(),
              "Should fail non-valgrind line");
  TEST_ASSERT(!LogParser::parse_header("==123== ").has_value(), "Should fail empty error type");
  TEST_PASS("Invalid header parsing");
  return true;
}

bool test_stack_frame() {
  // "==12345==    at 0x4C29F73: malloc (vg_replace_malloc.c:299)"
  // LogParser::parse_stack_frame expects the full line.
  std::string line = "==12345==    at 0x4C29F73: malloc (vg_replace_malloc.c:299)";
  auto res = LogParser::parse_stack_frame(line);
  TEST_ASSERT(res.has_value(), "Should parse stack frame");
  TEST_ASSERT(res->find("at 0x") != std::string::npos, "Should contain 'at 0x'");
  TEST_ASSERT(res->find("==12345==") == std::string::npos, "Should not contain PID prefix");

  std::string line2 = "==12345==    by 0x4005B6: main (test.c:10)";
  auto res2 = LogParser::parse_stack_frame(line2);
  TEST_ASSERT(res2.has_value(), "Should parse 'by' frame");
  TEST_PASS("Stack frame parsing");
  return true;
}

bool test_remove_prefix() {
  std::string line = "==12345== Hello World";
  TEST_ASSERT(LogParser::remove_prefix(line) == "Hello World", "Should remove prefix");

  std::string line2 = "==123==  Spaced";
  TEST_ASSERT(LogParser::remove_prefix(line2) == "Spaced", "Should remove prefix and space");

  std::string line3 = "No prefix";
  TEST_ASSERT(LogParser::remove_prefix(line3) == "No prefix",
              "Should return original if no prefix");

  TEST_PASS("Prefix removal");
  return true;
}

int main() {
  bool all_passed = true;
  all_passed &= test_parse_header_simple();
  all_passed &= test_parse_header_whitespace();
  all_passed &= test_parse_header_invalid();
  all_passed &= test_stack_frame();
  all_passed &= test_remove_prefix();

  if (all_passed) {
    std::cout << "All LogParser tests passed!" << std::endl;
    return 0;
  }
  return 1;
}
