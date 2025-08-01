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

// Simplified regex patterns for testing (matching the ones in vglog-filter.cpp)
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
    TEST_ASSERT(std::regex_replace("at : main", get_re_at(), "") == "main", 
                "'at' pattern replacement should work");
    TEST_ASSERT(std::regex_replace("by : malloc", get_re_by(), "") == "malloc", 
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
    TEST_ASSERT(std::regex_replace("???", get_re_q(), "") == "", 
                "Question mark replacement should work");
    TEST_ASSERT(std::regex_replace("hello ??? world", get_re_q(), "") == "hello  world", 
                "Question mark replacement in context should work");
    
    // Test edge cases
    TEST_ASSERT(!std::regex_search("??", get_re_q()), "Two question marks should not match");
    TEST_ASSERT(!std::regex_search("?", get_re_q()), "Single question mark should not match");
    
    TEST_PASS("Question mark regex patterns work correctly");
    return true;
}

int main() {
    std::cout << "Running regex pattern tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_valgrind_line_regex_patterns();
    all_passed &= test_valgrind_prefix_regex_patterns();
    all_passed &= test_start_pattern_regex_patterns();
    all_passed &= test_bytes_head_regex_patterns();
    all_passed &= test_at_by_regex_patterns();
    all_passed &= test_question_mark_regex_patterns();
    
    if (all_passed) {
        std::cout << "\nAll regex pattern tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome regex pattern tests failed!" << std::endl;
        return 1;
    }
}