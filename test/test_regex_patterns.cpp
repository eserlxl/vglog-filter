// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <iostream>
#include <string>
#include <string_view>
#include <regex>
#include <cassert>
#include "test_helpers.h"

// Simple test framework
// Remove TEST_ASSERT, TEST_PASS, trim, regex_replace_all, canon definitions

// Test helper functions (simplified versions of the main functions)
// Remove TEST_ASSERT, TEST_PASS, trim, regex_replace_all, canon definitions

// Simplified regex patterns for testing (matching the ones in vglog-filter.cpp)
static const std::regex& get_re_addr() {
    static const std::regex re(R"(0x[0-9a-fA-F]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_line() {
    static const std::regex re(R"(:[0-9]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_array() {
    static const std::regex re(R"(\[[0-9]+\])", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_template() {
    static const std::regex re(R"(<[^>]*>)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_ws() {
    static const std::regex re(R"([ \t\v\f\r\n]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_vg_line() {
    static const std::regex re(R"(^==[0-9]+==)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_prefix() {
    static const std::regex re(R"(^==[0-9]+==[ \t\v\f\r\n]*)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_start() {
    static const std::regex re(
        R"((Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ blocks|still reachable|possibly lost|definitely lost|Process terminating))",
        std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_bytes_head() {
    static const std::regex re(R"([0-9]+ bytes in [0-9]+ blocks)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_at() {
    static const std::regex re(R"(at : +)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_by() {
    static const std::regex re(R"(by : +)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_q() {
    static const std::regex re(R"(\?{3,})", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

bool test_address_regex_patterns() {
    // Test address pattern matching
    TEST_ASSERT(std::regex_search("0x12345678", get_re_addr()), "Basic hex address should match");
    TEST_ASSERT(std::regex_search("0xABCDEF", get_re_addr()), "Uppercase hex address should match");
    TEST_ASSERT(std::regex_search("0xabcdef", get_re_addr()), "Lowercase hex address should match");
    TEST_ASSERT(std::regex_search("0x0", get_re_addr()), "Single hex digit should match");
    TEST_ASSERT(std::regex_search("0x123456789ABCDEF", get_re_addr()), "Long hex address should match");
    
    // Test address pattern replacement
    TEST_ASSERT(regex_replace_all("at 0x12345678: main", get_re_addr(), "0xADDR") == "at 0xADDR: main", 
                "Address replacement should work");
    TEST_ASSERT(regex_replace_all("0x12345678 0xABCDEF", get_re_addr(), "0xADDR") == "0xADDR 0xADDR", 
                "Multiple addresses should be replaced");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("0x", get_re_addr()), "Incomplete hex should not match");
    TEST_ASSERT(!std::regex_search("0xg", get_re_addr()), "Invalid hex character should not match");
    // Note: The regex pattern 0x[0-9a-fA-F]+ will match up to the last valid hex character
    // So "0x12345678g" will match "0x12345678" and ignore the 'g'
    TEST_ASSERT(std::regex_search("0x12345678g", get_re_addr()), "Invalid hex character in middle should still match valid prefix");
    
    TEST_PASS("Address regex patterns work correctly");
    return true;
}

bool test_line_number_regex_patterns() {
    // Test line number pattern matching
    TEST_ASSERT(std::regex_search(":123", get_re_line()), "Basic line number should match");
    TEST_ASSERT(std::regex_search(":0", get_re_line()), "Zero line number should match");
    TEST_ASSERT(std::regex_search(":999999", get_re_line()), "Large line number should match");
    
    // Test line number pattern replacement
    TEST_ASSERT(regex_replace_all("main.cpp:123", get_re_line(), ":LINE") == "main.cpp:LINE", 
                "Line number replacement should work");
    TEST_ASSERT(regex_replace_all("file.cpp:123:456", get_re_line(), ":LINE") == "file.cpp:LINE:LINE", 
                "Multiple line numbers should be replaced");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search(":", get_re_line()), "Colon alone should not match");
    TEST_ASSERT(!std::regex_search(":abc", get_re_line()), "Non-numeric after colon should not match");
    
    TEST_PASS("Line number regex patterns work correctly");
    return true;
}

bool test_array_regex_patterns() {
    // Test array pattern matching
    TEST_ASSERT(std::regex_search("[0]", get_re_array()), "Basic array index should match");
    TEST_ASSERT(std::regex_search("[123]", get_re_array()), "Multi-digit array index should match");
    TEST_ASSERT(std::regex_search("[999999]", get_re_array()), "Large array index should match");
    
    // Test array pattern replacement
    TEST_ASSERT(regex_replace_all("array[0]", get_re_array(), "[]") == "array[]", 
                "Array index replacement should work");
    TEST_ASSERT(regex_replace_all("matrix[1][2]", get_re_array(), "[]") == "matrix[][]", 
                "Multiple array indices should be replaced");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("[]", get_re_array()), "Empty brackets should not match");
    TEST_ASSERT(!std::regex_search("[abc]", get_re_array()), "Non-numeric index should not match");
    TEST_ASSERT(!std::regex_search("[1", get_re_array()), "Unclosed bracket should not match");
    
    TEST_PASS("Array regex patterns work correctly");
    return true;
}

bool test_template_regex_patterns() {
    // Test template pattern matching
    TEST_ASSERT(std::regex_search("<int>", get_re_template()), "Basic template should match");
    TEST_ASSERT(std::regex_search("<std::string>", get_re_template()), "Complex template should match");
    TEST_ASSERT(std::regex_search("<std::vector<int>>", get_re_template()), "Nested template should match");
    TEST_ASSERT(std::regex_search("<T, U>", get_re_template()), "Multi-parameter template should match");
    
    // Test template pattern replacement
    TEST_ASSERT(regex_replace_all("std::vector<int>", get_re_template(), "<T>") == "std::vector<T>", 
                "Template replacement should work");
    TEST_ASSERT(regex_replace_all("std::map<std::string, int>", get_re_template(), "<T>") == "std::map<T>", 
                "Nested template replacement should work");
    
    // Test edge cases
    // Note: The regex pattern <[^>]*> will match empty templates like <>
    TEST_ASSERT(std::regex_search("<>", get_re_template()), "Empty template should match");
    TEST_ASSERT(!std::regex_search("<", get_re_template()), "Unclosed template should not match");
    TEST_ASSERT(!std::regex_search(">", get_re_template()), "Unopened template should not match");
    
    TEST_PASS("Template regex patterns work correctly");
    return true;
}

bool test_whitespace_regex_patterns() {
    // Test whitespace pattern matching
    TEST_ASSERT(std::regex_search("  ", get_re_ws()), "Spaces should match");
    TEST_ASSERT(std::regex_search("\t", get_re_ws()), "Tab should match");
    TEST_ASSERT(std::regex_search("\n", get_re_ws()), "Newline should match");
    TEST_ASSERT(std::regex_search("\r", get_re_ws()), "Carriage return should match");
    TEST_ASSERT(std::regex_search(" \t\n\r", get_re_ws()), "Mixed whitespace should match");
    
    // Test whitespace pattern replacement
    TEST_ASSERT(regex_replace_all("  hello  world  ", get_re_ws(), " ") == " hello world ", 
                "Whitespace replacement should work");
    TEST_ASSERT(regex_replace_all("a\tb\nc\rd", get_re_ws(), " ") == "a b c d", 
                "Mixed whitespace replacement should work");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("", get_re_ws()), "Empty string should not match");
    TEST_ASSERT(!std::regex_search("a", get_re_ws()), "Non-whitespace should not match");
    
    TEST_PASS("Whitespace regex patterns work correctly");
    return true;
}

bool test_valgrind_line_regex_patterns() {
    // Test valgrind line pattern matching
    TEST_ASSERT(std::regex_search("==12345==", get_re_vg_line()), "Basic valgrind line should match");
    TEST_ASSERT(std::regex_search("==0==", get_re_vg_line()), "Zero PID should match");
    TEST_ASSERT(std::regex_search("==999999==", get_re_vg_line()), "Large PID should match");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("==12345", get_re_vg_line()), "Incomplete valgrind line should not match");
    TEST_ASSERT(!std::regex_search("12345==", get_re_vg_line()), "Missing start markers should not match");
    TEST_ASSERT(!std::regex_search("==abc==", get_re_vg_line()), "Non-numeric PID should not match");
    
    TEST_PASS("Valgrind line regex patterns work correctly");
    return true;
}

bool test_valgrind_prefix_regex_patterns() {
    // Test valgrind prefix pattern matching and replacement
    TEST_ASSERT(std::regex_search("==12345== ", get_re_prefix()), "Basic valgrind prefix should match");
    TEST_ASSERT(std::regex_search("==12345==\t", get_re_prefix()), "Valgrind prefix with tab should match");
    TEST_ASSERT(std::regex_search("==12345==\n", get_re_prefix()), "Valgrind prefix with newline should match");
    
    // Test prefix replacement
    TEST_ASSERT(std::regex_replace("==12345== Invalid read", get_re_prefix(), "") == "Invalid read", 
                "Valgrind prefix replacement should work");
    TEST_ASSERT(std::regex_replace("==12345== \t at 0x12345678: main", get_re_prefix(), "") == "at 0x12345678: main", 
                "Valgrind prefix with whitespace replacement should work");
    
    TEST_PASS("Valgrind prefix regex patterns work correctly");
    return true;
}

bool test_start_pattern_regex_patterns() {
    // Test start pattern matching
    TEST_ASSERT(std::regex_search("Invalid read", get_re_start()), "Invalid read should match");
    TEST_ASSERT(std::regex_search("Invalid write", get_re_start()), "Invalid write should match");
    TEST_ASSERT(std::regex_search("Syscall param", get_re_start()), "Syscall param should match");
    TEST_ASSERT(std::regex_search("Use of uninitialised", get_re_start()), "Use of uninitialised should match");
    TEST_ASSERT(std::regex_search("Conditional jump", get_re_start()), "Conditional jump should match");
    TEST_ASSERT(std::regex_search("bytes in 123 blocks", get_re_start()), "Bytes in blocks should match");
    TEST_ASSERT(std::regex_search("still reachable", get_re_start()), "Still reachable should match");
    TEST_ASSERT(std::regex_search("possibly lost", get_re_start()), "Possibly lost should match");
    TEST_ASSERT(std::regex_search("definitely lost", get_re_start()), "Definitely lost should match");
    TEST_ASSERT(std::regex_search("Process terminating", get_re_start()), "Process terminating should match");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("Invalid", get_re_start()), "Partial match should not match");
    TEST_ASSERT(!std::regex_search("read", get_re_start()), "Partial match should not match");
    
    TEST_PASS("Start pattern regex patterns work correctly");
    return true;
}

bool test_bytes_head_regex_patterns() {
    // Test bytes header pattern matching
    TEST_ASSERT(std::regex_search("123 bytes in 456 blocks", get_re_bytes_head()), "Basic bytes header should match");
    TEST_ASSERT(std::regex_search("0 bytes in 0 blocks", get_re_bytes_head()), "Zero bytes header should match");
    TEST_ASSERT(std::regex_search("999999 bytes in 999999 blocks", get_re_bytes_head()), "Large numbers should match");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("bytes in blocks", get_re_bytes_head()), "Missing numbers should not match");
    TEST_ASSERT(!std::regex_search("123 bytes", get_re_bytes_head()), "Incomplete pattern should not match");
    
    TEST_PASS("Bytes header regex patterns work correctly");
    return true;
}

bool test_at_by_regex_patterns() {
    // Test 'at' and 'by' pattern matching and replacement
    TEST_ASSERT(std::regex_search("at : ", get_re_at()), "Basic 'at' pattern should match");
    TEST_ASSERT(std::regex_search("at : \t", get_re_at()), "'at' pattern with tab should match");
    TEST_ASSERT(std::regex_search("by : ", get_re_by()), "Basic 'by' pattern should match");
    TEST_ASSERT(std::regex_search("by : \t", get_re_by()), "'by' pattern with tab should match");
    
    // Test replacement
    TEST_ASSERT(regex_replace_all("at : main", get_re_at(), "") == "main", 
                "'at' pattern replacement should work");
    TEST_ASSERT(regex_replace_all("by : malloc", get_re_by(), "") == "malloc", 
                "'by' pattern replacement should work");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("at:", get_re_at()), "Missing space should not match");
    TEST_ASSERT(!std::regex_search("by:", get_re_by()), "Missing space should not match");
    
    TEST_PASS("'at' and 'by' regex patterns work correctly");
    return true;
}

bool test_question_mark_regex_patterns() {
    // Test question mark pattern matching and replacement
    TEST_ASSERT(std::regex_search("???", get_re_q()), "Three question marks should match");
    TEST_ASSERT(std::regex_search("????", get_re_q()), "Four question marks should match");
    TEST_ASSERT(std::regex_search("?????", get_re_q()), "Five question marks should match");
    
    // Test replacement
    TEST_ASSERT(regex_replace_all("???", get_re_q(), "") == "", 
                "Question mark replacement should work");
    TEST_ASSERT(regex_replace_all("hello ??? world", get_re_q(), "") == "hello  world", 
                "Question mark replacement in context should work");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("??", get_re_q()), "Two question marks should not match");
    TEST_ASSERT(!std::regex_search("?", get_re_q()), "Single question mark should not match");
    
    TEST_PASS("Question mark regex patterns work correctly");
    return true;
}

bool test_complex_regex_combinations() {
    // Test complex combinations of regex patterns
    std::string complex_line = "==12345==    at 0x12345678: std::vector<int>::operator[] (vector.cpp:123)";
    
    // Test valgrind prefix removal
    std::string after_prefix = std::regex_replace(complex_line, get_re_prefix(), "");
    TEST_ASSERT(after_prefix == "at 0x12345678: std::vector<int>::operator[] (vector.cpp:123)", 
                "Complex line prefix removal should work");
    
    // Test address replacement
    std::string after_addr = regex_replace_all(after_prefix, get_re_addr(), "0xADDR");
    TEST_ASSERT(after_addr == "at 0xADDR: std::vector<int>::operator[] (vector.cpp:123)", 
                "Complex line address replacement should work");
    
    // Test line number replacement
    std::string after_line = regex_replace_all(after_addr, get_re_line(), ":LINE");
    TEST_ASSERT(after_line == "at 0xADDR: std::vector<int>::operator[] (vector.cpp:LINE)", 
                "Complex line number replacement should work");
    
    // Test template replacement
    std::string after_template = regex_replace_all(after_line, get_re_template(), "<T>");
    TEST_ASSERT(after_template == "at 0xADDR: std::vector<T>::operator[] (vector.cpp:LINE)", 
                "Complex template replacement should work");
    
    TEST_PASS("Complex regex combinations work correctly");
    return true;
}

int main() {
    std::cout << "Running regex pattern tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_address_regex_patterns();
    all_passed &= test_line_number_regex_patterns();
    all_passed &= test_array_regex_patterns();
    all_passed &= test_template_regex_patterns();
    all_passed &= test_whitespace_regex_patterns();
    all_passed &= test_valgrind_line_regex_patterns();
    all_passed &= test_valgrind_prefix_regex_patterns();
    all_passed &= test_start_pattern_regex_patterns();
    all_passed &= test_bytes_head_regex_patterns();
    all_passed &= test_at_by_regex_patterns();
    all_passed &= test_question_mark_regex_patterns();
    all_passed &= test_complex_regex_combinations();
    
    if (all_passed) {
        std::cout << "\nAll regex pattern tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome regex pattern tests failed!" << std::endl;
        return 1;
    }
} 