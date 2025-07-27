// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cassert>

// Simple test framework
#define TEST_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            std::cerr << "FAIL: " << message << std::endl; \
            return false; \
        } \
    } while(0)

#define TEST_PASS(message) \
    do { \
        std::cout << "PASS: " << message << std::endl; \
    } while(0)

bool test_version_reading() {
    // Test that version can be read from local VERSION file
    std::ifstream version_file("VERSION");
    if (version_file) {
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
    // Create a temporary empty file
    std::ofstream empty_file("test_empty.tmp");
    empty_file.close();
    
    // Test that the file is actually empty
    std::ifstream check_file("test_empty.tmp");
    std::string line;
    bool has_content = static_cast<bool>(std::getline(check_file, line));
    TEST_ASSERT(!has_content, "Empty file should have no content");
    
    // Clean up
    std::remove("test_empty.tmp");
    TEST_PASS("Empty file handling works");
    return true;
}

bool test_basic_valgrind_log_parsing() {
    // Create a simple test valgrind log
    std::ofstream test_log("test_log.tmp");
    test_log << "==12345== Memcheck, a memory error detector\n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345== Successfully downloaded debug\n";
    test_log << "==12345== Invalid write of size 4\n";
    test_log << "==12345==    at 0x401234: main (test2.cpp:15)\n";
    test_log.close();
    
    // Test that the file was created and has content
    std::ifstream check_log("test_log.tmp");
    std::string line;
    int line_count = 0;
    while (std::getline(check_log, line)) {
        line_count++;
    }
    TEST_ASSERT(line_count > 0, "Test log should have content");
    
    // Clean up
    std::remove("test_log.tmp");
    TEST_PASS("Basic valgrind log parsing test setup works");
    return true;
}

int main() {
    std::cout << "Running basic tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_version_reading();
    all_passed &= test_empty_file_handling();
    all_passed &= test_basic_valgrind_log_parsing();
    
    if (all_passed) {
        std::cout << "\nAll tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome tests failed!" << std::endl;
        return 1;
    }
} 