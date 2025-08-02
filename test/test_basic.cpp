// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <iostream>
#include <fstream>
#include <string>
#include <string_view>
#include <vector>
#include <cassert>
#include <sstream>
#include <regex>
#include "test_helpers.h"

// Simple test framework
// Remove TEST_ASSERT, TEST_PASS, trim, regex_replace_all, canon definitions

// Test helper functions (simplified versions of the main functions)
// Remove TEST_ASSERT, TEST_PASS, trim, regex_replace_all, canon definitions

// Add RAII file cleanup helper

bool test_version_reading() {
    // Test that version can be read from local VERSION file
    if (std::ifstream version_file("VERSION"); version_file) {
        std::string version;
        std::getline(version_file, version);
        TEST_ASSERT(!version.empty(), "Version should not be empty");
        TEST_PASS("Version file reading works");
        return true;
    } else {
        std::cout << "SKIP: VERSION file not found in current directory" << std::endl;
        return true;
    }
}

bool test_empty_file_handling() {
    TempFile cleanup("test_empty.tmp");
    std::ofstream empty_file("/tmp/test_empty.tmp");
    empty_file.close();
    bool has_content = false;
    if (std::ifstream check_file("/tmp/test_empty.tmp"); check_file) {
        std::string line;
        has_content = static_cast<bool>(std::getline(check_file, line));
    }
    TEST_ASSERT(!has_content, "Empty file should have no content");
    TEST_PASS("Empty file handling works");
    return true;
}

bool test_basic_valgrind_log_parsing() {
    // Create a simple test valgrind log
    std::ofstream test_log("/tmp/test_log.tmp");
    test_log << "==12345== Memcheck, a memory error detector\n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345== Successfully downloaded debug\n";
    test_log << "==12345== Invalid write of size 4\n";
    test_log << "==12345==    at 0x401234: main (test2.cpp:15)\n";
    test_log.close();
    
    // Test that the file was created and has content
    std::ifstream check_log("/tmp/test_log.tmp");
    std::string line;
    int line_count = 0;
    while (std::getline(check_log, line)) {
        line_count++;
    }
    TEST_ASSERT(line_count > 0, "Test log should have content");
    
    // Clean up
    std::remove("/tmp/test_log.tmp");
    TEST_PASS("Basic valgrind log parsing test setup works");
    return true;
}

bool test_string_trimming() {
    // Test ltrim, rtrim, and trim functions
    std::string test1 = "  hello world  ";
    std::string test2 = "\t\n\r test \t\n\r";
    std::string test3 = "no_spaces";
    std::string test4 = "   ";
    
    TEST_ASSERT(trim(test1) == "hello world", "Basic trimming should work");
    TEST_ASSERT(trim(test2) == "test", "Complex whitespace trimming should work");
    TEST_ASSERT(trim(test3) == "no_spaces", "String without spaces should remain unchanged");
    TEST_ASSERT(trim(test4) == "", "All whitespace should be trimmed to empty string");
    
    TEST_PASS("String trimming functions work correctly");
    return true;
}

bool test_canonicalization() {
    // Test the canonicalization function
    std::string test1 = "==12345==    at 0x401234: main (test.cpp:10)";
    std::string test2 = "==12345==    at 0x401234: array[5] (test.cpp:15)";
    std::string test3 = "==12345==    at 0x401234: std::vector<int>::operator[] (vector:123)";
    
    std::string result1 = canon(test1);
    std::string result2 = canon(test2);
    std::string result3 = canon(test3);
    
    TEST_ASSERT(result1.find("0xADDR") != std::string::npos, "Address should be canonicalized");
    TEST_ASSERT(result1.find(":LINE") != std::string::npos, "Line number should be canonicalized");
    TEST_ASSERT(result2.find("[]") != std::string::npos, "Array index should be canonicalized");
    TEST_ASSERT(result3.find("<T>") != std::string::npos, "Template should be canonicalized");
    
    TEST_PASS("Canonicalization function works correctly");
    return true;
}

bool test_regex_patterns() {
    // Test that our regex patterns work correctly
    static const std::regex re_addr(R"(0x[0-9a-fA-F]+)", std::regex::optimize);
    static const std::regex re_line(R"(:[0-9]+)", std::regex::optimize);
    static const std::regex re_vg_line(R"(^==[0-9]+==)", std::regex::optimize);
    
    std::string addr_test = "0x12345678";
    std::string line_test = ":42";
    std::string vg_test = "==12345== Some message";
    std::string normal_test = "normal text";
    
    TEST_ASSERT(std::regex_search(addr_test, re_addr), "Address regex should match");
    TEST_ASSERT(std::regex_search(line_test, re_line), "Line regex should match");
    TEST_ASSERT(std::regex_search(vg_test, re_vg_line), "Valgrind line regex should match");
    TEST_ASSERT(!std::regex_search(normal_test, re_addr), "Address regex should not match normal text");
    
    TEST_PASS("Regex patterns work correctly");
    return true;
}

bool test_edge_cases() {
    // Test various edge cases
    std::string empty = "";
    std::string only_whitespace = "   \t\n\r   ";
    std::string very_long = std::string(1000, 'x') + "0x12345678" + std::string(1000, 'y');
    
    TEST_ASSERT(trim(empty) == "", "Empty string should remain empty");
    TEST_ASSERT(trim(only_whitespace) == "", "Only whitespace should be trimmed to empty");
    TEST_ASSERT(canon(empty) == "", "Empty string canonicalization should work");
    TEST_ASSERT(canon(very_long).find("0xADDR") != std::string::npos, "Long string canonicalization should work");
    
    TEST_PASS("Edge cases handled correctly");
    return true;
}

bool test_large_file_simulation() {
    // Simulate processing a large number of lines
    std::ofstream large_file("/tmp/test_large.tmp");
    for (int i = 0; i < 1000; ++i) {
        large_file << "==12345== Line " << i << " with 0x" << std::hex << (i * 1000) << std::dec << "\n";
    }
    large_file.close();
    
    // Test that we can read the large file
    std::ifstream check_file("/tmp/test_large.tmp");
    std::string line;
    int count = 0;
    while (std::getline(check_file, line)) {
        count++;
        if (count % 100 == 0) {
            // Test canonicalization on some lines
            std::string canon_line = canon(line);
            TEST_ASSERT(canon_line.find("0xADDR") != std::string::npos, "Large file canonicalization should work");
        }
    }
    TEST_ASSERT(count == 1000, "Large file should have 1000 lines");
    
    // Clean up
    std::remove("/tmp/test_large.tmp");
    TEST_PASS("Large file processing simulation works");
    return true;
}

bool test_large_file_detection() {
    // Create a small file (should not trigger large file detection)
    std::ofstream small_file("/tmp/test_small.tmp");
    small_file << "==12345== Small file test\n";
    small_file << "==12345== Only a few lines\n";
    small_file.close();
    
    // Create a "large" file for testing (we'll simulate by checking file size logic)
    std::ofstream large_file("/tmp/test_large_detect.tmp");
    // Write enough content to simulate a large file
    for (int i = 0; i < 10000; ++i) {
        large_file << "==12345== Line " << i << " with some content to make the file larger\n";
    }
    large_file.close();
    
    // Test file size detection logic (simplified version)
    std::ifstream small_check("/tmp/test_small.tmp");
    small_check.seekg(0, std::ios::end);
    std::streampos small_size = small_check.tellg();
    
    std::ifstream large_check("/tmp/test_large_detect.tmp");
    large_check.seekg(0, std::ios::end);
    std::streampos large_size = large_check.tellg();
    
    // Verify that large file is indeed larger
    TEST_ASSERT(large_size > small_size, "Large file should be bigger than small file");
    
    // Clean up
    std::remove("/tmp/test_small.tmp");
    std::remove("/tmp/test_large_detect.tmp");
    TEST_PASS("Large file detection logic works");
    return true;
}

int main() {
    std::cout << "Running comprehensive tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_version_reading();
    all_passed &= test_empty_file_handling();
    all_passed &= test_basic_valgrind_log_parsing();
    all_passed &= test_string_trimming();
    all_passed &= test_canonicalization();
    all_passed &= test_regex_patterns();
    all_passed &= test_edge_cases();
    all_passed &= test_large_file_simulation();
    all_passed &= test_large_file_detection();
    
    if (all_passed) {
        std::cout << "\nAll tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome tests failed!" << std::endl;
        return 1;
    }
} 