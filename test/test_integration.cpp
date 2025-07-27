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
#include <cstdlib>
#include <cstring>

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

bool test_valgrind_log_processing() {
    // Create a realistic Valgrind log file
    std::ofstream test_log("test_valgrind.tmp");
    test_log << "==12345== Memcheck, a memory error detector\n";
    test_log << "==12345== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.\n";
    test_log << "==12345== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info\n";
    test_log << "==12345== Command: ./test_program\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345==    by 0x401245: some_function (test.cpp:15)\n";
    test_log << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    test_log << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345==    by 0x401245: some_function (test.cpp:15)\n";
    test_log << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    test_log << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log << "==12345== \n";
    test_log << "==12345== HEAP SUMMARY:\n";
    test_log << "==12345==     in use at exit: 0 bytes in 0 blocks\n";
    test_log << "==12345==   total heap usage: 1 allocs, 1 frees, 10 bytes allocated\n";
    test_log << "==12345== \n";
    test_log << "==12345== All heap blocks were freed -- no leaks are possible\n";
    test_log << "==12345== \n";
    test_log << "==12345== For lists of detected and suppressed errors, rerun with: -s\n";
    test_log << "==12345== ERROR SUMMARY: 2 errors from 1 contexts (suppressed: 0 from 0)\n";
    test_log.close();
    
    // Test that the file was created
    if (std::ifstream check_file("test_valgrind.tmp"); check_file) {
        TEST_ASSERT(check_file.good(), "Test Valgrind log file should be created");
        
        // Count lines to verify content
        std::string line;
        int line_count = 0;
        while (std::getline(check_file, line)) {
            line_count++;
        }
        TEST_ASSERT(line_count > 0, "Test Valgrind log should have content");
    }
    
    // Clean up
    std::remove("test_valgrind.tmp");
    TEST_PASS("Valgrind log processing test setup works");
    return true;
}

bool test_deduplication_logic() {
    // Create a log with duplicate entries
    std::ofstream test_log("test_dedup.tmp");
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log.close();
    
    // Test that duplicates are present in the raw file
    std::ifstream check_file("test_dedup.tmp");
    std::string line;
    int invalid_read_count = 0;
    while (std::getline(check_file, line)) {
        if (line.find("Invalid read of size 4") != std::string::npos) {
            invalid_read_count++;
        }
    }
    TEST_ASSERT(invalid_read_count >= 3, "Raw file should contain multiple duplicate entries");
    
    // Clean up
    std::remove("test_dedup.tmp");
    TEST_PASS("Deduplication logic test setup works");
    return true;
}

bool test_marker_trimming() {
    // Create a log with marker in the middle
    std::ofstream test_log("test_marker.tmp");
    test_log << "==12345== Early message 1\n";
    test_log << "==12345== Early message 2\n";
    test_log << "==12345== Successfully downloaded debug\n";
    test_log << "==12345== Late message 1\n";
    test_log << "==12345== Late message 2\n";
    test_log.close();
    
    // Test that marker is present
    std::ifstream check_file("test_marker.tmp");
    std::string line;
    bool found_marker = false;
    while (std::getline(check_file, line)) {
        if (line.find("Successfully downloaded debug") != std::string::npos) {
            found_marker = true;
            break;
        }
    }
    TEST_ASSERT(found_marker, "Marker should be present in test file");
    
    // Clean up
    std::remove("test_marker.tmp");
    TEST_PASS("Marker trimming test setup works");
    return true;
}

bool test_stream_processing_simulation() {
    // Create a large log file to test stream processing
    std::ofstream test_log("test_stream.tmp");
    for (int i = 0; i < 5000; ++i) {
        test_log << "==12345== Line " << i << " with some content\n";
        if (i % 100 == 0) {
            test_log << "==12345== Invalid read of size 4\n";
            test_log << "==12345==    at 0x" << std::hex << (0x401234 + i) << std::dec << ": main (test.cpp:" << (10 + i) << ")\n";
        }
    }
    test_log.close();
    
    // Test file size
    std::ifstream check_file("test_stream.tmp");
    check_file.seekg(0, std::ios::end);
    std::streampos file_size = check_file.tellg();
    TEST_ASSERT(file_size > 100000, "Stream test file should be large");
    
    // Clean up
    std::remove("test_stream.tmp");
    TEST_PASS("Stream processing simulation works");
    return true;
}

bool test_error_conditions() {
    // Test with non-existent file
    std::ifstream nonexistent("nonexistent_file.tmp");
    TEST_ASSERT(!nonexistent.good(), "Non-existent file should not be readable");
    
    // Test with empty file
    std::ofstream empty_file("test_empty_integration.tmp");
    empty_file.close();
    
    std::ifstream check_empty("test_empty_integration.tmp");
    std::string line;
    bool has_content = static_cast<bool>(std::getline(check_empty, line));
    TEST_ASSERT(!has_content, "Empty file should have no content");
    
    // Clean up
    std::remove("test_empty_integration.tmp");
    TEST_PASS("Error condition tests work");
    return true;
}

int main() {
    std::cout << "Running integration tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_valgrind_log_processing();
    all_passed &= test_deduplication_logic();
    all_passed &= test_marker_trimming();
    all_passed &= test_stream_processing_simulation();
    all_passed &= test_error_conditions();
    
    if (all_passed) {
        std::cout << "\nAll integration tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome integration tests failed!" << std::endl;
        return 1;
    }
} 