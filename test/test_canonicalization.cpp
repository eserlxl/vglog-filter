// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <iostream>
#include <string>
#include <string_view>
#include <cassert>
#include "test_helpers.h"
#include <canonicalization.h>

using namespace canonicalization;

bool test_trim_views() {
    std::cout << "\n=== Testing trim_view ===" << std::endl;

    TEST_ASSERT(trim_view("  hello  ") == "hello", "trim_view: leading and trailing spaces");
    TEST_ASSERT(trim_view("\t\nhello\r\n") == "hello", "trim_view: mixed whitespace");
    TEST_ASSERT(trim_view("hello") == "hello", "trim_view: no whitespace");
    TEST_ASSERT(trim_view("  ") == "", "trim_view: all spaces");
    TEST_ASSERT(trim_view("") == "", "trim_view: empty string");
    TEST_ASSERT(trim_view("  h e l l o  ") == "h e l l o", "trim_view: internal spaces");

    TEST_PASS("trim_view tests completed");
    return true;
}

bool test_rtrim_string() {
    std::cout << "\n=== Testing rtrim(Str) ===" << std::endl;

    TEST_ASSERT(rtrim("  hello  ") == "  hello", "rtrim: trailing spaces");
    TEST_ASSERT(rtrim("\t\nhello\r\n") == "\t\nhello", "rtrim: mixed trailing whitespace");
    TEST_ASSERT(rtrim("hello") == "hello", "rtrim: no trailing whitespace");
    TEST_ASSERT(rtrim("  ") == "", "rtrim: all spaces");
    TEST_ASSERT(rtrim("") == "", "rtrim: empty string");
    TEST_ASSERT(rtrim("hello world  ") == "hello world", "rtrim: multiple words");

    TEST_PASS("rtrim(Str) tests completed");
    return true;
}

bool test_canon_function() {
    std::cout << "\n=== Testing canon() function ===" << std::endl;

    // Test case 1: Basic Valgrind line with all elements
    std::string input1 = "   at 0x12345678: std::vector<int>::operator[] (vector.cpp:123)[0]";
    std::string expected1 = "at 0xADDR: std::vector<T>::operator[] (vector.cpp:LINE)[]";
    TEST_ASSERT(canon(input1) == expected1, "Canon: basic valgrind line");

    // Test case 2: Multiple addresses, line numbers, templates, arrays
    std::string input2 = "Invalid read of size 4 at 0xABCDEF: func<char>(file.c:45)[1] by 0x12345: main";
    std::string expected2 = "Invalid read of size 4 at 0xADDR: func<T>(file.c:LINE)[] by 0xADDR: main";
    TEST_ASSERT(canon(input2) == expected2, "Canon: multiple elements");

    // Test case 3: Only whitespace
    std::string input3 = "   \t\n\r   ";
    std::string expected3 = "";
    TEST_ASSERT(canon(input3) == expected3, "Canon: only whitespace");

    // Test case 4: No special patterns
    std::string input4 = "This is a regular log line.";
    std::string expected4 = "This is a regular log line.";
    TEST_ASSERT(canon(input4) == expected4, "Canon: no special patterns");

    // Test case 5: Empty string
    std::string input5 = "";
    std::string expected5 = "";
    TEST_ASSERT(canon(input5) == expected5, "Canon: empty string");

    // Test case 6: Valgrind line with only whitespace
    std::string input6 = "   \t ";
    std::string expected6 = "";
    TEST_ASSERT(canon(input6) == expected6, "Canon: prefix and whitespace");

    // Test case 7: Valgrind line with question marks
    std::string input7 = "??? some error ???";
    std::string expected7 = "??? some error ???"; // Question marks are not canonicalized by canon()
    TEST_ASSERT(canon(input7) == expected7, "Canon: question marks");

    // Test case 8: Valgrind line with 'at :' and 'by :'
    std::string input8 = "   at : main by : func";
    std::string expected8 = "at : main by : func"; // 'at :' and 'by :' are not canonicalized by canon()
    TEST_ASSERT(canon(input8) == expected8, "Canon: at and by");

    TEST_PASS("canon() function tests completed");
    return true;
}

int main() {
    std::cout << "Running canonicalization tests..." << std::endl;

    bool all_passed = true;

    all_passed &= test_trim_views();
    all_passed &= test_rtrim_string();
    all_passed &= test_canon_function();

    if (all_passed) {
        std::cout << "\n✅ All canonicalization tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\n❌ Some canonicalization tests failed!" << std::endl;
        return 1;
    }
}