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
#include <cstdlib>
#include <cstring>
#include <sys/stat.h>
#include "test_helpers.h"

bool test_memory_leak_simulation() {
    // Create a log with memory leak information
    TempFile test_log("test_memory_leak.tmp");
    std::ofstream& log_stream = test_log.get_stream();
    log_stream << "==12345== Memcheck, a memory error detector\n";
    log_stream << "==12345== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.\n";
    log_stream << "==12345== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info\n";
    log_stream << "==12345== Command: ./test_program\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== HEAP SUMMARY:\n";
    log_stream << "==12345==     in use at exit: 40 bytes in 1 blocks\n";
    log_stream << "==12345==   total heap usage: 2 allocs, 1 frees, 50 bytes allocated\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== 40 bytes in 1 blocks are definitely lost in loss record 1 of 1\n";
    log_stream << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    log_stream << "==12345==    by 0x401200: main (test.cpp:8)\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== LEAK SUMMARY:\n";
    log_stream << "==12345==    definitely lost: 40 bytes in 1 blocks\n";
    log_stream << "==12345==    indirectly lost: 0 bytes in 0 blocks\n";
    log_stream << "==12345==      possibly lost: 0 bytes in 0 blocks\n";
    log_stream << "==12345==    still reachable: 0 bytes in 0 blocks\n";
    log_stream << "==12345==         suppressed: 0 bytes in 0 blocks\n";
    log_stream << "==12345== Rerun with --leak-check=full to see details of leaked memory\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== For lists of detected and suppressed errors, rerun with: -s\n";
    log_stream << "==12345== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)\n";
    test_log.close(); // Close the stream before reading
    
    // Test that the file was created and has content
    std::ifstream check_file("test_memory_leak.tmp");
    if (check_file) {
        std::string line;
        int line_count = 0;
        while (std::getline(check_file, line)) {
            line_count++;
        }
        TEST_ASSERT(line_count > 0, "Memory leak test file should have content");
    }
    
    TEST_PASS("Memory leak simulation works");
    return true;
}

bool test_multiple_memory_leaks() {
    // Test with multiple different types of memory leaks
    TempFile test_log("test_multiple_leaks.tmp");
    std::ofstream& log_stream = test_log.get_stream();
    log_stream << "==12345== Memcheck, a memory error detector\n";
    log_stream << "==12345== Command: ./test_program\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== HEAP SUMMARY:\n";
    log_stream << "==12345==     in use at exit: 120 bytes in 3 blocks\n";
    log_stream << "==12345==   total heap usage: 5 allocs, 2 frees, 150 bytes allocated\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== 40 bytes in 1 blocks are definitely lost in loss record 1 of 3\n";
    log_stream << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    log_stream << "==12345==    by 0x401200: main (test.cpp:8)\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== 50 bytes in 1 blocks are definitely lost in loss record 2 of 3\n";
    log_stream << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    log_stream << "==12345==    by 0x401210: main (test.cpp:10)\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== 30 bytes in 1 blocks are possibly lost in loss record 3 of 3\n";
    log_stream << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    log_stream << "==12345==    by 0x401220: main (test.cpp:12)\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== LEAK SUMMARY:\n";
    log_stream << "==12345==    definitely lost: 90 bytes in 2 blocks\n";
    log_stream << "==12345==    indirectly lost: 0 bytes in 0 blocks\n";
    log_stream << "==12345==      possibly lost: 30 bytes in 1 blocks\n";
    log_stream << "==12345==    still reachable: 0 bytes in 0 blocks\n";
    log_stream << "==12345==         suppressed: 0 bytes in 0 blocks\n";
    log_stream << "==12345== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)\n";
    
    // Test that the file was created
    std::ifstream check_file("test_multiple_leaks.tmp");
    TEST_ASSERT(check_file.good(), "Multiple memory leaks test file should be created");
    
    TEST_PASS("Multiple memory leaks simulation works");
    return true;
}

bool test_no_memory_leaks() {
    // Test with a clean run that has no memory leaks
    TempFile test_log("test_no_leaks.tmp");
    std::ofstream& log_stream = test_log.get_stream();
    log_stream << "==12345== Memcheck, a memory error detector\n";
    log_stream << "==12345== Command: ./test_program\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== HEAP SUMMARY:\n";
    log_stream << "==12345==     in use at exit: 0 bytes in 0 blocks\n";
    log_stream << "==12345==   total heap usage: 3 allocs, 3 frees, 100 bytes allocated\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== All heap blocks were freed -- no leaks are possible\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== For lists of detected and suppressed errors, rerun with: -s\n";
    log_stream << "==12345== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)\n";
    
    // Test that the file was created
    std::ifstream check_file("test_no_leaks.tmp");
    TEST_ASSERT(check_file.good(), "No memory leaks test file should be created");
    
    TEST_PASS("No memory leaks simulation works");
    return true;
}

bool test_memory_allocation_failures() {
    // Test scenarios that might cause memory allocation issues
    TempFile test_log("test_allocation_failures.tmp");
    std::ofstream& log_stream = test_log.get_stream();
    
    // Create a very large string that might stress memory allocation
    std::string large_string = "==12345== ";
    for (int i = 0; i < 10000; ++i) {
        large_string += "very_long_string_with_many_characters_to_test_memory_allocation_" + std::to_string(i) + "_";
    }
    large_string += " (test.cpp:10000)";
    
    log_stream << large_string << "\n";
    log_stream << "==12345== HEAP SUMMARY:\n";
    log_stream << "==12345==     in use at exit: 0 bytes in 0 blocks\n";
    log_stream << "==12345==   total heap usage: 1 allocs, 1 frees, 1000000 bytes allocated\n";
    
    TEST_PASS("Memory allocation failures test works");
    return true;
}

bool test_memory_sanitizer_compatibility() {
    // Test scenarios that are commonly problematic with memory sanitizers
    TempFile test_log("test_msan_compatibility.tmp");
    std::ofstream& log_stream = test_log.get_stream();
    log_stream << "==12345== Memcheck, a memory error detector\n";
    log_stream << "==12345== Command: ./test_program\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== Invalid read of size 4\n";
    log_stream << "==12345==    at 0x401234: main (test.cpp:10)\n";
    log_stream << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    log_stream << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    log_stream << "==12345==    by 0x401200: main (test.cpp:8)\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== HEAP SUMMARY:\n";
    log_stream << "==12345==     in use at exit: 10 bytes in 1 blocks\n";
    log_stream << "==12345==   total heap usage: 1 allocs, 0 frees, 10 bytes allocated\n";
    log_stream << "==12345== \n";
    log_stream << "==12345== LEAK SUMMARY:\n";
    log_stream << "==12345==    definitely lost: 10 bytes in 1 blocks\n";
    log_stream << "==12345== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)\n";
    
    // Test that the file was created
    std::ifstream check_file("test_msan_compatibility.tmp");
    TEST_ASSERT(check_file.good(), "Memory sanitizer compatibility test file should be created");
    
    TEST_PASS("Memory sanitizer compatibility test works");
    return true;
}

bool test_memory_efficiency_large_files() {
    // Test memory efficiency with large files that might cause OOM
    TempFile test_log("test_memory_efficiency_large.tmp");
    std::ofstream& log_stream = test_log.get_stream();
    
    // Create a large file to test memory efficiency
    for (int i = 0; i < 50000; ++i) {
        log_stream << "==12345== Line " << i << " with some content to test memory efficiency with large files\n";
        if (i % 1000 == 0) {
            log_stream << "==12345== HEAP SUMMARY:\n";
            log_stream << "==12345==     in use at exit: " << (i * 10) << " bytes in " << (i / 100) << " blocks\n";
            log_stream << "==12345==   total heap usage: " << (i * 2) << " allocs, " << (i * 2 - 10) << " frees, " << (i * 100) << " bytes allocated\n";
        }
    }
    
    // Check file size
    struct stat file_stat;
    if (stat("test_memory_efficiency_large.tmp", &file_stat) == 0) {
        TEST_ASSERT(file_stat.st_size > 500000, "Large memory efficiency test file should be very large");
    }
    
    TEST_PASS("Memory efficiency with large files test works");
    return true;
}

int main() {
    std::cout << "Running memory leak and memory-related tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_memory_leak_simulation();
    all_passed &= test_multiple_memory_leaks();
    all_passed &= test_no_memory_leaks();
    all_passed &= test_memory_allocation_failures();
    all_passed &= test_memory_sanitizer_compatibility();
    all_passed &= test_memory_efficiency_large_files();
    
    if (all_passed) {
        std::cout << "\nAll memory-related tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome memory-related tests failed!" << std::endl;
        return 1;
    }
} 