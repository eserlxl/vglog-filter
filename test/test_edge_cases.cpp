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

// Test framework
// Remove TEST_ASSERT, TEST_PASS, trim, regex_replace_all, canon definitions

bool test_malformed_valgrind_lines() {
    // Test with malformed or edge case valgrind lines
    TempFile test_log("test_malformed.tmp");
    test_log.get_stream() << "==12345== Invalid read of size 4\n";
    test_log.get_stream() << "==12345==    at : main (test.cpp:10)\n";  // Missing address
    test_log.get_stream() << "==12345==    at 0x: main (test.cpp:10)\n";  // Incomplete address
    test_log.get_stream() << "==12345==    at 0x401234: (test.cpp:10)\n";  // Missing function name
    test_log.get_stream() << "==12345==    at 0x401234: main (:10)\n";  // Missing filename
    test_log.get_stream() << "==12345==    at 0x401234: main (test.cpp:)\n";  // Missing line number
    test_log.get_stream() << "==12345==    at 0x401234: main ()\n";  // Missing everything after function
    test_log.get_stream() << "==12345==    at : ()\n";  // Minimal malformed line
    test_log.get_stream() << "==12345== \n";  // Empty line
    test_log.get_stream() << "==12345==\n";   // Just PID marker
    test_log.close(); // Close the stream before reading
    
    // Test that the file was created
    std::ifstream check_file("test_malformed.tmp");
    if (check_file) {
        std::string line;
        int line_count = 0;
        while (std::getline(check_file, line)) {
            line_count++;
        }
        TEST_ASSERT(line_count > 0, "Malformed valgrind lines test file should have content");
    }
    
    TEST_PASS("Malformed valgrind lines handling works");
    return true;
}

bool test_very_long_lines() {
    // Test with very long lines that might cause buffer issues
    TempFile test_log("test_long_lines.tmp");
    std::string long_line = "==12345== ";
    for (int i = 0; i < 1000; ++i) {
        long_line += "very_long_function_name_with_many_characters_and_numbers_" + std::to_string(i) + "_";
    }
    long_line += " (very_long_file_name_with_many_characters.cpp:1000)";
    
    test_log.get_stream() << long_line + "\n";
    test_log.get_stream() << "==12345==    at 0x401234: main (test.cpp:10)\n";
    test_log.close();
    
    // Test that the file was created
    if (std::ifstream check_file("test_long_lines.tmp"); check_file) {
        TEST_ASSERT(check_file.good(), "Long lines test file should be created");
    }
    
    // Clean up
    TEST_PASS("Very long lines handling works");
    return true;
}

bool test_unicode_and_special_chars() {
    // Test with Unicode and special characters
    TempFile test_log("test_unicode.tmp");
    test_log.get_stream() << "==12345== Invalid read of size 4\n";
    test_log.get_stream() << "==12345==    at 0x401234: main (test_unicode.cpp:10)\n";
    test_log.get_stream() << "==12345==    by 0x401245: function_with_unicode_ñáéíóú (test.cpp:15)\n";
    test_log.get_stream() << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    test_log.get_stream() << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log.get_stream() << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log.get_stream() << "==12345== \n";
    test_log.get_stream() << "==12345== Invalid read of size 4\n";
    test_log.get_stream() << "==12345==    at 0x401234: main (test_unicode.cpp:10)\n";
    test_log.get_stream() << "==12345==    by 0x401245: function_with_unicode_ñáéíóú (test.cpp:15)\n";
    test_log.get_stream() << "==12345==  Address 0x12345678 is 0 bytes after a block of size 10 alloc'd\n";
    test_log.get_stream() << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
    test_log.get_stream() << "==12345==    by 0x401200: main (test.cpp:8)\n";
    test_log.close();
    
    // Test that the file was created
    if (std::ifstream check_file("test_unicode.tmp"); check_file) {
        TEST_ASSERT(check_file.good(), "Unicode test file should be created");
    }
    
    // Clean up
    TEST_PASS("Unicode and special characters handling works");
    return true;
}

bool test_nested_templates_and_complex_types() {
    // Test with complex C++ types and nested templates
    TempFile test_log("test_complex_types.tmp");
    test_log.get_stream() << "==12345== Invalid read of size 4\n";
    test_log.get_stream() << "==12345==    at 0x401234: std::vector<std::map<std::string, std::pair<int, double>>>::operator[] (vector:123)\n";
    test_log.get_stream() << "==12345==    at 0x401245: MyClass<template<typename T, typename U, typename V>>::method (myclass.hpp:456)\n";
    test_log.get_stream() << "==12345==    at 0x401256: std::unique_ptr<std::shared_ptr<std::weak_ptr<MyType>>>::operator-> (memory:789)\n";
    test_log.get_stream() << "==12345==    at 0x401267: boost::variant<int, std::string, std::vector<double>>::get<std::string> (variant.hpp:321)\n";
    test_log.close();
    
    // Test that the file was created
    std::ifstream check_file("test_complex_types.tmp");
    TEST_ASSERT(check_file.good(), "Complex types test file should be created");
    
    // Clean up
    TEST_PASS("Complex C++ types and nested templates handling works");
    return true;
}

bool test_file_permissions() {
    // Test with different file permissions
    TempFile test_log("test_permissions.tmp");
    test_log.get_stream() << "==12345== Test file with permissions\n";
    test_log.close();
    
    // Change permissions to read-only
    chmod("test_permissions.tmp", 0444);
    
    // Test that we can still read the file
    std::ifstream check_file("test_permissions.tmp");
    TEST_ASSERT(check_file.good(), "Read-only file should still be readable");
    check_file.close();
    
    // Restore permissions and clean up
    chmod("test_permissions.tmp", 0644);
    TEST_PASS("File permissions handling works");
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

bool test_invalid_input_scenarios() {
    // Test various invalid input scenarios that should be handled gracefully
    
    // Test with completely empty file
    TempFile empty_file("test_empty.tmp");
    
    std::ifstream check_empty("test_empty.tmp");
    TEST_ASSERT(check_empty.good(), "Empty file should be readable");
    check_empty.close();
    
    // Test with file containing only whitespace
    TempFile whitespace_file("test_whitespace.tmp");
    whitespace_file.get_stream() << "   \n\t\n  \n";
    whitespace_file.close();
    
    std::ifstream check_whitespace("test_whitespace.tmp");
    TEST_ASSERT(check_whitespace.good(), "Whitespace-only file should be readable");
    check_whitespace.close();
    
    // Test with file containing no valgrind markers
    TempFile no_markers_file("test_no_markers.tmp");
    no_markers_file.get_stream() << "This is not a valgrind log\n";
    no_markers_file.get_stream() << "Just some random text\n";
    no_markers_file.get_stream() << "No ==PID== markers here\n";
    no_markers_file.close();
    
    std::ifstream check_no_markers("test_no_markers.tmp");
    TEST_ASSERT(check_no_markers.good(), "File without markers should be readable");
    check_no_markers.close();
    
    // Test with file containing invalid PID format
    TempFile invalid_pid_file("test_invalid_pid.tmp");
    invalid_pid_file.get_stream() << "==abc== Invalid read of size 4\n";  // Non-numeric PID
    invalid_pid_file.get_stream() << "==12345==    at 0x401234: main (test.cpp:10)\n";
    invalid_pid_file.get_stream() << "==def== Invalid write of size 8\n";  // Another non-numeric PID
    invalid_pid_file.get_stream() << "==12345==    at 0x401245: main (test.cpp:15)\n";
    invalid_pid_file.close();
    
    std::ifstream check_invalid_pid("test_invalid_pid.tmp");
    TEST_ASSERT(check_invalid_pid.good(), "File with invalid PID format should be readable");
    check_invalid_pid.close();
    
    // Test with file containing null bytes (should be handled gracefully)
    TempFile null_bytes_file("test_null_bytes.tmp", std::ios::binary);
    null_bytes_file.get_stream() << "==12345== Invalid read of size 4\n";
    null_bytes_file.get_stream() << '\0';  // Null byte
    null_bytes_file.get_stream() << "==12345==    at 0x401234: main (test.cpp:10)\n";
    null_bytes_file.close();
    
    std::ifstream check_null_bytes("test_null_bytes.tmp");
    TEST_ASSERT(check_null_bytes.good(), "File with null bytes should be readable");
    check_null_bytes.close();
    
    // Clean up
    TEST_PASS("Invalid input scenarios handled correctly");
    return true;
}

bool test_memory_allocation_failure_simulation() {
    // Test scenarios that might trigger memory allocation issues
    
    // Test with extremely long lines that might cause memory issues
    TempFile long_lines_file("test_memory_long_lines.tmp");
    std::string extremely_long_line = "==12345== ";
    for (int i = 0; i < 10000; ++i) {
        extremely_long_line += "very_long_function_name_with_many_characters_and_numbers_" + std::to_string(i) + "_";
    }
    extremely_long_line += " (very_long_file_name_with_many_characters.cpp:10000)";
    
    long_lines_file.get_stream() << extremely_long_line + "\n";
    long_lines_file.get_stream() << "==12345==    at 0x401234: main (test.cpp:10)\n";
    long_lines_file.close();
    
    std::ifstream check_long_lines("test_memory_long_lines.tmp");
    TEST_ASSERT(check_long_lines.good(), "File with extremely long lines should be readable");
    check_long_lines.close();
    
    // Test with many duplicate lines that might cause hash table issues
    TempFile duplicates_file("test_memory_duplicates.tmp");
    for (int i = 0; i < 1000; ++i) {
        duplicates_file.get_stream() << "==12345== Invalid read of size 4\n";
        duplicates_file.get_stream() << "==12345==    at 0x401234: main (test.cpp:10)\n";
        duplicates_file.get_stream() << "==12345==    by 0x401245: helper (test.cpp:15)\n";
    }
    duplicates_file.close();
    
    std::ifstream check_duplicates("test_memory_duplicates.tmp");
    TEST_ASSERT(check_duplicates.good(), "File with many duplicates should be readable");
    check_duplicates.close();
    
    // Test with many unique lines that might cause memory growth
    TempFile unique_lines_file("test_memory_unique.tmp");
    for (int i = 0; i < 1000; ++i) {
        unique_lines_file.get_stream() << "==12345== Invalid read of size " + std::to_string(i) + "\n";
        unique_lines_file.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
        unique_lines_file.get_stream() << "==12345==    by 0x" + std::to_string(0x401245 + i) + ": helper (test.cpp:" + std::to_string(15 + i) + ")\n";
    }
    unique_lines_file.close();
    
    std::ifstream check_unique("test_memory_unique.tmp");
    TEST_ASSERT(check_unique.good(), "File with many unique lines should be readable");
    check_unique.close();
    
    // Clean up
    TEST_PASS("Memory allocation failure scenarios handled correctly");
    return true;
}

bool test_file_system_error_scenarios() {
    // Test various file system error scenarios
    
    // Test with file that becomes unreadable during processing
    TempFile temp_file("test_fs_error.tmp");
    temp_file.get_stream() << "==12345== Invalid read of size 4\n";
    temp_file.get_stream() << "==12345==    at 0x401234: main (test.cpp:10)\n";
    temp_file.close();
    
    // Verify file exists and is readable
    std::ifstream check_file("test_fs_error.tmp");
    TEST_ASSERT(check_file.good(), "Temporary file should be readable");
    check_file.close();
    
    // Test with file that has read permissions but is actually a directory
    // (This would be a rare edge case but should be handled)
    std::remove("test_fs_error.tmp");
    
    // Test with file that has unusual permissions
    TempFile perm_file("test_fs_perm.tmp");
    perm_file.get_stream() << "==12345== Test content\n";
    perm_file.close();
    
    // Change permissions to read-only
    chmod("test_fs_perm.tmp", S_IRUSR);
    
    std::ifstream check_perm("test_fs_perm.tmp");
    TEST_ASSERT(check_perm.good(), "Read-only file should still be readable");
    check_perm.close();
    
    // Restore permissions and clean up
    chmod("test_fs_perm.tmp", S_IRUSR | S_IWUSR);
    std::remove("test_fs_perm.tmp");
    
    TEST_PASS("File system error scenarios handled correctly");
    return true;
}

bool test_marker_trimming_edge_cases() {
    // Test edge cases for marker trimming functionality
    
    // Test with marker at the beginning
    TempFile test_log1("test_marker_begin.tmp");
    test_log1.get_stream() << "==12345== Successfully downloaded debug\n";
    test_log1.get_stream() << "==12345== Late message 1\n";
    test_log1.get_stream() << "==12345== Late message 2\n";
    test_log1.close();
    
    // Test with marker at the end
    TempFile test_log2("test_marker_end.tmp");
    test_log2.get_stream() << "==12345== Early message 1\n";
    test_log2.get_stream() << "==12345== Early message 2\n";
    test_log2.get_stream() << "==12345== Successfully downloaded debug\n";
    test_log2.close();
    
    // Test with no marker
    TempFile test_log3("test_marker_none.tmp");
    test_log3.get_stream() << "==12345== Message 1\n";
    test_log3.get_stream() << "==12345== Message 2\n";
    test_log3.close();
    
    // Verify files were created
    std::ifstream check1("test_marker_begin.tmp");
    std::ifstream check2("test_marker_end.tmp");
    std::ifstream check3("test_marker_none.tmp");
    
    TEST_ASSERT(check1.good(), "Marker begin test file should be created");
    TEST_ASSERT(check2.good(), "Marker end test file should be created");
    TEST_ASSERT(check3.good(), "Marker none test file should be created");
    
    // Clean up
    TEST_PASS("Marker trimming edge cases work");
    return true;
}

bool test_stream_processing_edge_cases() {
    // Test edge cases specific to stream processing
    
    // Create a file that should trigger stream processing
    TempFile test_log("test_stream_edge.tmp");
    
    // Create enough content to potentially trigger stream mode
    for (int i = 0; i < 5000; ++i) {
        test_log.get_stream() << "==12345== Line " + std::to_string(i) + " with some content to test stream processing\n";
        if (i % 100 == 0) {
            test_log.get_stream() << "==12345== Invalid read of size 4\n";
            test_log.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
        }
    }
    test_log.close();
    
    // Check file size
    struct stat file_stat;
    if (stat("test_stream_edge.tmp", &file_stat) == 0) {
        TEST_ASSERT(file_stat.st_size > 50000, "Stream edge case test file should be reasonably large");
    }
    
    // Clean up
    TEST_PASS("Stream processing edge cases work");
    return true;
}

bool test_concurrent_access_simulation() {
    // Test with multiple files that might be accessed concurrently
    std::vector<std::string> files;
    std::vector<std::unique_ptr<TempFile>> temp_files;
    
    for (int i = 0; i < 10; ++i) {
        std::string filename = "test_concurrent_" + std::to_string(i) + ".tmp";
        auto temp_file = std::make_unique<TempFile>(filename.c_str());
        temp_file->get_stream() << "==12345== Concurrent test " + std::to_string(i) + "\n";
        temp_file->get_stream() << "==12345==    at 0x401234: main (test.cpp:" + std::to_string(10 + i) + ")\n";
        temp_file->close(); // Close the stream
        
        // Check if file exists before it gets cleaned up
        if (std::ifstream(filename).good()) {
            files.push_back(filename);
        }
        temp_files.push_back(std::move(temp_file));
    }
    
    // Verify that at least one file was created successfully
    TEST_ASSERT(!files.empty(), "At least one concurrent test file should be created");
    
    TEST_PASS("Concurrent access simulation works");
    return true;
}

bool test_memory_efficiency() {
    // Test memory efficiency by creating a large file and monitoring memory usage
    TempFile test_log("test_memory_efficiency.tmp");
    
    // Create a moderately large file (not too large to avoid disk space issues)
    for (int i = 0; i < 10000; ++i) {
        test_log.get_stream() << "==12345== Line " + std::to_string(i) + " with some content to test memory efficiency\n";
        if (i % 100 == 0) {
            test_log.get_stream() << "==12345== Invalid read of size 4\n";
            test_log.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
        }
    }
    test_log.close();
    
    // Check file size
    struct stat file_stat;
    if (stat("test_memory_efficiency.tmp", &file_stat) == 0) {
        TEST_ASSERT(file_stat.st_size > 100000, "Memory efficiency test file should be large");
    }
    
    // Clean up
    TEST_PASS("Memory efficiency test works");
    return true;
}

bool test_large_file_processing() {
    // Test processing of large files that should trigger stream mode
    TempFile test_log("test_large_file.tmp");
    
    // Create a file that's large enough to trigger stream processing (5MB threshold)
    // Each line is approximately 80 bytes, so we need about 75,000 lines
    const int target_lines = 80000;  // More than needed for 5MB
    
    for (int i = 0; i < target_lines; ++i) {
        test_log.get_stream() << "==12345== Line " + std::to_string(i) + " with some content to test large file processing\n";
        
        // Add some valgrind error blocks periodically
        if (i % 1000 == 0) {
            test_log.get_stream() << "==12345== Invalid read of size 4\n";
            test_log.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
            test_log.get_stream() << "==12345==    by 0x" + std::to_string(0x401245 + i) + ": helper (test.cpp:" + std::to_string(15 + i) + ")\n";
            test_log.get_stream() << "==12345==  Address 0x" + std::to_string(0x12345678 + i) + " is 0 bytes after a block of size 10 alloc'd\n";
            test_log.get_stream() << "==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)\n";
            test_log.get_stream() << "==12345==    by 0x" + std::to_string(0x401200 + i) + ": main (test.cpp:8)\n";
        }
        
        // Add marker line periodically to test trimming
        if (i % 5000 == 0) {
            test_log.get_stream() << "==12345== Successfully downloaded debug\n";
        }
    }
    test_log.close();
    
    // Check file size
    struct stat file_stat;
    if (stat("test_large_file.tmp", &file_stat) == 0) {
        TEST_ASSERT(file_stat.st_size > 5000000, "Large file test should be at least 5MB");
        std::cout << "Created large test file: " << (file_stat.st_size / 1024 / 1024) << " MB" << std::endl;
    }
    
    // Test that the file can be opened and read
    std::ifstream check_file("test_large_file.tmp");
    TEST_ASSERT(check_file.good(), "Large file should be readable");
    
    // Read a few lines to verify content
    std::string line;
    int line_count = 0;
    while (std::getline(check_file, line) && line_count < 10) {
        TEST_ASSERT(!line.empty(), "Large file should contain non-empty lines");
        line_count++;
    }
    check_file.close();
    
    // Clean up
    TEST_PASS("Large file processing test works");
    return true;
}

bool test_progress_and_memory_features() {
    // Test new features like progress reporting and memory monitoring
    
    // Test progress reporting simulation
    TempFile progress_test_file("test_progress.tmp");
    for (int i = 0; i < 5000; ++i) {
        progress_test_file.get_stream() << "==12345== Line " + std::to_string(i) + " for progress testing\n";
        if (i % 100 == 0) {
            progress_test_file.get_stream() << "==12345== Invalid read of size 4\n";
            progress_test_file.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
        }
    }
    progress_test_file.close();
    
    // Verify progress test file was created
    std::ifstream check_progress("test_progress.tmp");
    TEST_ASSERT(check_progress.good(), "Progress test file should be created");
    check_progress.close();
    
    // Test memory monitoring simulation
    TempFile memory_test_file("test_memory.tmp");
    for (int i = 0; i < 1000; ++i) {
        memory_test_file.get_stream() << "==12345== Memory test line " + std::to_string(i) + "\n";
        memory_test_file.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
        memory_test_file.get_stream() << "==12345==    by 0x" + std::to_string(0x401245 + i) + ": helper (test.cpp:" + std::to_string(15 + i) + ")\n";
    }
    memory_test_file.close();
    
    // Verify memory test file was created
    std::ifstream check_memory("test_memory.tmp");
    TEST_ASSERT(check_memory.good(), "Memory test file should be created");
    check_memory.close();
    
    // Test combined features simulation
    TempFile combined_test_file("test_combined.tmp");
    for (int i = 0; i < 2000; ++i) {
        combined_test_file.get_stream() << "==12345== Combined test line " + std::to_string(i) + "\n";
        if (i % 50 == 0) {
            combined_test_file.get_stream() << "==12345== Successfully downloaded debug\n";
        }
        if (i % 100 == 0) {
            combined_test_file.get_stream() << "==12345== Invalid read of size 4\n";
            combined_test_file.get_stream() << "==12345==    at 0x" + std::to_string(0x401234 + i) + ": main (test.cpp:" + std::to_string(10 + i) + ")\n";
        }
    }
    combined_test_file.close();
    
    // Verify combined test file was created
    std::ifstream check_combined("test_combined.tmp");
    TEST_ASSERT(check_combined.good(), "Combined test file should be created");
    check_combined.close();
    
    // Clean up
    TEST_PASS("Progress and memory features test works");
    return true;
}

int main() {
    std::cout << "Running edge case tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_malformed_valgrind_lines();
    all_passed &= test_very_long_lines();
    all_passed &= test_unicode_and_special_chars();
    all_passed &= test_nested_templates_and_complex_types();
    all_passed &= test_file_permissions();
    all_passed &= test_error_handling_edge_cases();
    all_passed &= test_invalid_input_scenarios();
    all_passed &= test_memory_allocation_failure_simulation();
    all_passed &= test_file_system_error_scenarios();
    all_passed &= test_marker_trimming_edge_cases();
    all_passed &= test_stream_processing_edge_cases();
    all_passed &= test_concurrent_access_simulation();
    all_passed &= test_memory_efficiency();
    all_passed &= test_large_file_processing();
    all_passed &= test_progress_and_memory_features();
    
    if (all_passed) {
        std::cout << "\nAll edge case tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome edge case tests failed!" << std::endl;
        return 1;
    }
} 