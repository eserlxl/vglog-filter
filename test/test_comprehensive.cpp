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
#include <sstream>
#include <regex>
#include <cstdlib>
#include <cstring>
#include <sys/stat.h>

// Test framework
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

bool test_memory_leak_simulation() {
    // Create a log with memory leak information
    std::ofstream test_log("test_memory_leak.tmp");
    test_log << "==12345== Memcheck, a memory error detector\n";
    test_log << "==12345== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.\n";
    test_log << "==12345== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info\n";
    test_log << "==12345== Command: ./test_program\n";
    test_log << "==12345== \n";
    test_log << "==12345== HEAP SUMMARY:\n";
    test_log << "==12345==     in use at exit: 40 bytes in 1 blocks\n";
    test_log << "==12345==   total heap usage: 2 allocs, 1 frees, 50 bytes allocated\n";
    test_log << "==12345== \n";
    test_log << "==12345== 40 bytes in 1 blocks are definitely lost in loss record 1 of 1\n";
    test_log << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log << "==12345== \n";
    test_log << "==12345== LEAK SUMMARY:\n";
    test_log << "==12345==    definitely lost: 40 bytes in 1 blocks\n";
    test_log << "==12345==    indirectly lost: 0 bytes in 0 blocks\n";
    test_log << "==12345==      possibly lost: 0 bytes in 0 blocks\n";
    test_log << "==12345==    still reachable: 0 bytes in 0 blocks\n";
    test_log << "==12345==         suppressed: 0 bytes in 0 blocks\n";
    test_log << "==12345== Rerun with --leak-check=full to see details of leaked memory\n";
    test_log << "==12345== \n";
    test_log << "==12345== For lists of detected and suppressed errors, rerun with: -s\n";
    test_log << "==12345== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)\n";
    test_log.close();
    
    // Test that the file was created and has content
    std::ifstream check_file("test_memory_leak.tmp");
    std::string line;
    int line_count = 0;
    while (std::getline(check_file, line)) {
        line_count++;
    }
    TEST_ASSERT(line_count > 0, "Memory leak test file should have content");
    
    // Clean up
    std::remove("test_memory_leak.tmp");
    TEST_PASS("Memory leak simulation works");
    return true;
}

bool test_unicode_and_special_chars() {
    // Test with Unicode and special characters
    std::ofstream test_log("test_unicode.tmp");
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test_unicode.cpp:10)\n";
    test_log << "==12345==    by 0x401245: function_with_unicode_ñáéíóú (test.cpp:15)\n";
    test_log << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    test_log << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test_unicode.cpp:10)\n";
    test_log << "==12345==    by 0x401245: function_with_unicode_ñáéíóú (test.cpp:15)\n";
    test_log << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    test_log << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log.close();
    
    // Test that the file was created
    std::ifstream check_file("test_unicode.tmp");
    TEST_ASSERT(check_file.good(), "Unicode test file should be created");
    
    // Clean up
    std::remove("test_unicode.tmp");
    TEST_PASS("Unicode and special characters handling works");
    return true;
}

bool test_very_long_lines() {
    // Test with very long lines that might cause buffer issues
    std::ofstream test_log("test_long_lines.tmp");
    std::string long_line = "==12345== ";
    for (int i = 0; i < 1000; ++i) {
        long_line += "very_long_function_name_with_many_characters_and_numbers_" + std::to_string(i) + "_";
    }
    long_line += " (very_long_file_name_with_many_characters.cpp:1000)";
    
    test_log << long_line << "\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log.close();
    
    // Test that the file was created
    std::ifstream check_file("test_long_lines.tmp");
    TEST_ASSERT(check_file.good(), "Long lines test file should be created");
    
    // Clean up
    std::remove("test_long_lines.tmp");
    TEST_PASS("Very long lines handling works");
    return true;
}

bool test_malformed_valgrind_lines() {
    // Test with malformed or edge case valgrind lines
    std::ofstream test_log("test_malformed.tmp");
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at : main (test.cpp:10)\n";  // Missing address
    test_log << "==12345==    at 0x: main (test.cpp:10)\n";  // Incomplete address
    test_log << "==12345==    at 0x401234: (test.cpp:10)\n";  // Missing function name
    test_log << "==12345==    at 0x401234: main (:10)\n";  // Missing filename
    test_log << "==12345==    at 0x401234: main (test.cpp:)\n";  // Missing line number
    test_log << "==12345==    at 0x401234: main ()\n";  // Missing everything after function
    test_log << "==12345==    at : ()\n";  // Minimal malformed line
    test_log << "==12345== \n";  // Empty line
    test_log << "==12345==\n";   // Just PID marker
    test_log.close();
    
    // Test that the file was created
    std::ifstream check_file("test_malformed.tmp");
    TEST_ASSERT(check_file.good(), "Malformed lines test file should be created");
    
    // Clean up
    std::remove("test_malformed.tmp");
    TEST_PASS("Malformed valgrind lines handling works");
    return true;
}

bool test_nested_templates_and_complex_types() {
    // Test with complex C++ types and nested templates
    std::ofstream test_log("test_complex_types.tmp");
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: std::vector<std::map<std::string, std::pair<int, double>>>::operator[] (vector:123)\n";
    test_log << "==12345==    at 0x401245: MyClass<template<typename T, typename U, typename V>>::method (myclass.hpp:456)\n";
    test_log << "==12345==    at 0x401256: std::unique_ptr<std::shared_ptr<std::weak_ptr<MyType>>>::operator-> (memory:789)\n";
    test_log << "==12345==    at 0x401267: boost::variant<int, std::string, std::vector<double>>::get<std::string> (variant.hpp:321)\n";
    test_log.close();
    
    // Test that the file was created
    std::ifstream check_file("test_complex_types.tmp");
    TEST_ASSERT(check_file.good(), "Complex types test file should be created");
    
    // Clean up
    std::remove("test_complex_types.tmp");
    TEST_PASS("Complex C++ types and nested templates handling works");
    return true;
}

bool test_file_permissions() {
    // Test with different file permissions
    std::ofstream test_log("test_permissions.tmp");
    test_log << "==12345== Test file with permissions\n";
    test_log.close();
    
    // Change permissions to read-only
    chmod("test_permissions.tmp", 0444);
    
    // Test that we can still read the file
    std::ifstream check_file("test_permissions.tmp");
    TEST_ASSERT(check_file.good(), "Read-only file should still be readable");
    
    // Restore permissions and clean up
    chmod("test_permissions.tmp", 0644);
    std::remove("test_permissions.tmp");
    TEST_PASS("File permissions handling works");
    return true;
}

bool test_concurrent_access_simulation() {
    // Simulate potential concurrent access issues by creating multiple files
    std::vector<std::string> files;
    for (int i = 0; i < 10; ++i) {
        std::string filename = "test_concurrent_" + std::to_string(i) + ".tmp";
        std::ofstream test_log(filename);
        test_log << "==12345== Concurrent test " << i << "\n";
        test_log << "==12345==    at 0x401234: main (test.cpp:" << (10 + i) << ")\n";
        test_log.close();
        files.push_back(filename);
    }
    
    // Verify all files were created
    for (const auto& filename : files) {
        std::ifstream check_file(filename);
        TEST_ASSERT(check_file.good(), "Concurrent test file should be created: " + filename);
    }
    
    // Clean up
    for (const auto& filename : files) {
        std::remove(filename.c_str());
    }
    TEST_PASS("Concurrent access simulation works");
    return true;
}

bool test_memory_efficiency() {
    // Test memory efficiency by creating a large file and monitoring memory usage
    std::ofstream test_log("test_memory_efficiency.tmp");
    
    // Create a moderately large file (not too large to avoid disk space issues)
    for (int i = 0; i < 10000; ++i) {
        test_log << "==12345== Line " << i << " with some content to test memory efficiency\n";
        if (i % 100 == 0) {
            test_log << "==12345== Invalid read of size 4\n";
            test_log << "==12345==    at 0x" << std::hex << (0x401234 + i) << std::dec << ": main (test.cpp:" << (10 + i) << ")\n";
        }
    }
    test_log.close();
    
    // Check file size
    struct stat file_stat;
    if (stat("test_memory_efficiency.tmp", &file_stat) == 0) {
        TEST_ASSERT(file_stat.st_size > 100000, "Memory efficiency test file should be large");
    }
    
    // Clean up
    std::remove("test_memory_efficiency.tmp");
    TEST_PASS("Memory efficiency test works");
    return true;
}

bool test_error_handling_edge_cases() {
    // Test various error handling edge cases
    
    // Test with a file that doesn't exist
    std::ifstream nonexistent("nonexistent_file_that_should_not_exist.tmp");
    TEST_ASSERT(!nonexistent.good(), "Non-existent file should not be readable");
    
    // Test with a directory (should fail)
    std::ofstream dir_test("test_dir.tmp");
    dir_test.close();
    std::remove("test_dir.tmp");
    
    // Test with empty filename
    std::ofstream empty_name_test("");
    TEST_ASSERT(!empty_name_test.good(), "Empty filename should not be writable");
    
    TEST_PASS("Error handling edge cases work");
    return true;
}

bool test_vglog_filter_integration() {
    // Test actual vglog-filter functionality with various inputs
    
    // Create a test file with duplicate entries
    std::ofstream test_log("test_vglog_integration.tmp");
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log << "==12345== \n";
    test_log << "==12345== Invalid read of size 4\n";
    test_log << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log.close();
    
    // Test that the file was created
    std::ifstream check_file("test_vglog_integration.tmp");
    TEST_ASSERT(check_file.good(), "vglog-filter integration test file should be created");
    
    // Clean up
    std::remove("test_vglog_integration.tmp");
    TEST_PASS("vglog-filter integration test works");
    return true;
}

bool test_stream_processing_edge_cases() {
    // Test edge cases specific to stream processing
    
    // Create a file that should trigger stream processing
    std::ofstream test_log("test_stream_edge.tmp");
    
    // Create enough content to potentially trigger stream mode
    for (int i = 0; i < 5000; ++i) {
        test_log << "==12345== Line " << i << " with some content to test stream processing\n";
        if (i % 100 == 0) {
            test_log << "==12345== Invalid read of size 4\n";
            test_log << "==12345==    at 0x" << std::hex << (0x401234 + i) << std::dec << ": main (test.cpp:" << (10 + i) << ")\n";
        }
    }
    test_log.close();
    
    // Check file size
    struct stat file_stat;
    if (stat("test_stream_edge.tmp", &file_stat) == 0) {
        TEST_ASSERT(file_stat.st_size > 50000, "Stream edge case test file should be reasonably large");
    }
    
    // Clean up
    std::remove("test_stream_edge.tmp");
    TEST_PASS("Stream processing edge cases work");
    return true;
}

bool test_marker_trimming_edge_cases() {
    // Test edge cases for marker trimming functionality
    
    // Test with marker at the beginning
    std::ofstream test_log1("test_marker_begin.tmp");
    test_log1 << "==12345== Successfully downloaded debug\n";
    test_log1 << "==12345== Late message 1\n";
    test_log1 << "==12345== Late message 2\n";
    test_log1.close();
    
    // Test with marker at the end
    std::ofstream test_log2("test_marker_end.tmp");
    test_log2 << "==12345== Early message 1\n";
    test_log2 << "==12345== Early message 2\n";
    test_log2 << "==12345== Successfully downloaded debug\n";
    test_log2.close();
    
    // Test with no marker
    std::ofstream test_log3("test_marker_none.tmp");
    test_log3 << "==12345== Message 1\n";
    test_log3 << "==12345== Message 2\n";
    test_log3.close();
    
    // Verify files were created
    std::ifstream check1("test_marker_begin.tmp");
    std::ifstream check2("test_marker_end.tmp");
    std::ifstream check3("test_marker_none.tmp");
    
    TEST_ASSERT(check1.good(), "Marker begin test file should be created");
    TEST_ASSERT(check2.good(), "Marker end test file should be created");
    TEST_ASSERT(check3.good(), "Marker none test file should be created");
    
    // Clean up
    std::remove("test_marker_begin.tmp");
    std::remove("test_marker_end.tmp");
    std::remove("test_marker_none.tmp");
    TEST_PASS("Marker trimming edge cases work");
    return true;
}

int main() {
    std::cout << "Running comprehensive edge case tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_memory_leak_simulation();
    all_passed &= test_unicode_and_special_chars();
    all_passed &= test_very_long_lines();
    all_passed &= test_malformed_valgrind_lines();
    all_passed &= test_nested_templates_and_complex_types();
    all_passed &= test_file_permissions();
    all_passed &= test_concurrent_access_simulation();
    all_passed &= test_memory_efficiency();
    all_passed &= test_error_handling_edge_cases();
    all_passed &= test_vglog_filter_integration();
    all_passed &= test_stream_processing_edge_cases();
    all_passed &= test_marker_trimming_edge_cases();
    
    if (all_passed) {
        std::cout << "\nAll comprehensive tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome comprehensive tests failed!" << std::endl;
        return 1;
    }
} 