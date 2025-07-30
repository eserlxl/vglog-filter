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
#include <filesystem>
#include <limits.h>
#include <stdexcept>
#include <sys/stat.h>
#include <path_validation.h>
#include "test_helpers.h"

// Simple test framework
// Remove TEST_ASSERT, TEST_PASS, trim, regex_replace_all, canon definitions

#define TEST_EXPECT_EXCEPTION(expr, exception_type, message) \
    do { \
        try { \
            expr; \
            std::cerr << "FAIL: " << message << " (expected exception but none thrown)" << std::endl; \
            return false; \
        } catch (const exception_type& e) { \
            TEST_PASS(message << " (exception caught: " << e.what() << ")"); \
        } catch (...) { \
            std::cerr << "FAIL: " << message << " (wrong exception type thrown)" << std::endl; \
            return false; \
        } \
    } while(0)



// Test helper functions
bool test_contains_path_traversal() {
    std::cout << "\n=== Testing contains_path_traversal() ===" << std::endl;
    
    // Test dangerous patterns
    TEST_ASSERT(contains_path_traversal(".."), "Should detect parent directory");
    TEST_ASSERT(contains_path_traversal("../file.txt"), "Should detect parent directory with file");
    TEST_ASSERT(contains_path_traversal("../../file.txt"), "Should detect double parent directory");
    TEST_ASSERT(contains_path_traversal("~"), "Should detect home directory");
    TEST_ASSERT(contains_path_traversal("~/file.txt"), "Should detect home directory with file");
    TEST_ASSERT(contains_path_traversal("//"), "Should detect multiple slashes");
    TEST_ASSERT(contains_path_traversal("//file.txt"), "Should detect multiple slashes with file");
    TEST_ASSERT(contains_path_traversal("\\"), "Should detect backslash");
    TEST_ASSERT(contains_path_traversal("\\file.txt"), "Should detect backslash with file");
    
    // Test safe patterns
    TEST_ASSERT(!contains_path_traversal("-"), "Should allow stdin indicator");
    TEST_ASSERT(!contains_path_traversal("file.txt"), "Should allow simple filename");
    TEST_ASSERT(!contains_path_traversal("test/file.txt"), "Should allow relative path");
    TEST_ASSERT(!contains_path_traversal(""), "Should allow empty string");
    
    // Test absolute paths (should be blocked)
    TEST_ASSERT(contains_path_traversal("/"), "Should block root directory");
    TEST_ASSERT(contains_path_traversal("/etc/passwd"), "Should block absolute path");
    TEST_ASSERT(contains_path_traversal("/home/user/file.txt"), "Should block absolute path with user");
    
    TEST_PASS("contains_path_traversal() tests completed");
    return true;
}

bool test_validate_file_path() {
    std::cout << "\n=== Testing validate_file_path() ===" << std::endl;
    
    // Test stdin indicator (should pass)
    try {
        std::string result = validate_file_path("-");
        TEST_ASSERT(result == "-", "Stdin indicator should be preserved");
        TEST_PASS("Stdin indicator validation");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: Stdin indicator should not throw exception: " << e.what() << std::endl;
        return false;
    }
    
    // Test simple filename (should pass)
    try {
        std::string result = validate_file_path("test.txt");
        TEST_ASSERT(result == "test.txt", "Simple filename should be preserved");
        TEST_PASS("Simple filename validation");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: Simple filename should not throw exception: " << e.what() << std::endl;
        return false;
    }
    
    // Test path traversal attempts (should throw)
    TEST_EXPECT_EXCEPTION(
        validate_file_path(".."),
        std::runtime_error,
        "Parent directory traversal should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("../file.txt"),
        std::runtime_error,
        "Parent directory with file should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("../../file.txt"),
        std::runtime_error,
        "Double parent directory should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("~"),
        std::runtime_error,
        "Home directory should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("~/file.txt"),
        std::runtime_error,
        "Home directory with file should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("//"),
        std::runtime_error,
        "Multiple slashes should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("\\"),
        std::runtime_error,
        "Backslash should be blocked"
    );
    
    // Test absolute paths (should throw)
    TEST_EXPECT_EXCEPTION(
        validate_file_path("/"),
        std::runtime_error,
        "Root directory should be blocked"
    );
    
    TEST_EXPECT_EXCEPTION(
        validate_file_path("/etc/passwd"),
        std::runtime_error,
        "Absolute path should be blocked"
    );
    
    // Test null bytes (should throw)
    std::string path_with_null = "file";
    path_with_null += '\0';
    path_with_null += ".txt";
    TEST_EXPECT_EXCEPTION(
        validate_file_path(path_with_null),
        std::runtime_error,
        "Null bytes should be blocked"
    );
    
    // Test extremely long path (should throw)
    std::string long_path(PATH_MAX + 1, 'a');
    TEST_EXPECT_EXCEPTION(
        validate_file_path(long_path),
        std::runtime_error,
        "Path too long should be blocked"
    );
    
    TEST_PASS("validate_file_path() tests completed");
    return true;
}

bool test_safe_file_operations() {
    std::cout << "\n=== Testing safe file operations ===" << std::endl;
    
    // Create a test file
    std::ofstream test_file("test_safe_ops.txt");
    test_file << "test content";
    test_file.close();
    
    // Test safe_fopen with valid file
    try {
        FILE* file = safe_fopen("test_safe_ops.txt", "r");
        TEST_ASSERT(file != nullptr, "safe_fopen should succeed with valid file");
        fclose(file);
        TEST_PASS("safe_fopen with valid file");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: safe_fopen should not throw with valid file: " << e.what() << std::endl;
        return false;
    }
    
    // Test safe_ifstream with valid file
    try {
        std::ifstream file = safe_ifstream("test_safe_ops.txt");
        TEST_ASSERT(file.is_open(), "safe_ifstream should open valid file");
        TEST_PASS("safe_ifstream with valid file");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: safe_ifstream should not throw with valid file: " << e.what() << std::endl;
        return false;
    }
    
    // Test safe_stat with valid file
    try {
        struct stat st;
        int result = safe_stat("test_safe_ops.txt", &st);
        TEST_ASSERT(result == 0, "safe_stat should succeed with valid file");
        TEST_PASS("safe_stat with valid file");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: safe_stat should not throw with valid file: " << e.what() << std::endl;
        return false;
    }
    
    // Test safe_fopen with path traversal (should throw)
    TEST_EXPECT_EXCEPTION(
        safe_fopen("../test_safe_ops.txt", "r"),
        std::runtime_error,
        "safe_fopen should block path traversal"
    );
    
    // Test safe_ifstream with path traversal (should throw)
    TEST_EXPECT_EXCEPTION(
        safe_ifstream("../test_safe_ops.txt"),
        std::runtime_error,
        "safe_ifstream should block path traversal"
    );
    
    // Test safe_stat with path traversal (should throw)
    TEST_EXPECT_EXCEPTION(
        safe_stat("../test_safe_ops.txt", nullptr),
        std::runtime_error,
        "safe_stat should block path traversal"
    );
    
    // Clean up
    std::remove("test_safe_ops.txt");
    
    TEST_PASS("safe file operations tests completed");
    return true;
}

bool test_edge_cases() {
    std::cout << "\n=== Testing edge cases ===" << std::endl;
    
    // Test empty string
    TEST_ASSERT(!contains_path_traversal(""), "Empty string should be safe");
    
    // Test single character
    TEST_ASSERT(!contains_path_traversal("a"), "Single character should be safe");
    
    // Test string with only dots (not parent directory)
    // Note: "..." contains ".." so it will be detected as path traversal
    TEST_ASSERT(contains_path_traversal("..."), "Three dots should be detected as path traversal");
    TEST_ASSERT(contains_path_traversal("...."), "Four dots should be detected as path traversal");
    
    // Test string with dots in middle
    // Note: "file..txt" contains ".." so it will be detected as path traversal
    TEST_ASSERT(contains_path_traversal("file..txt"), "Dots in middle should be detected as path traversal");
    TEST_ASSERT(contains_path_traversal("file...txt"), "Three dots in middle should be detected as path traversal");
    
    // Test string starting with dots but not parent directory
    TEST_ASSERT(!contains_path_traversal(".hidden"), "Hidden file should be safe");
    // Note: "..hidden" contains ".." so it will be detected as path traversal
    TEST_ASSERT(contains_path_traversal("..hidden"), "Double dot hidden file should be detected as path traversal");
    
    // Test mixed separators
    TEST_ASSERT(contains_path_traversal("file\\..\\..\\etc\\passwd"), "Mixed separators with traversal should be blocked");
    TEST_ASSERT(contains_path_traversal("file//..//..//etc//passwd"), "Multiple slashes with traversal should be blocked");
    
    // Test normalization edge cases
    try {
        std::string result = validate_file_path("test/./file.txt");
        TEST_ASSERT(result.find("..") == std::string::npos, "Normalized path should not contain ..");
        TEST_PASS("Path normalization with ./");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: Path with ./ should be normalized: " << e.what() << std::endl;
        return false;
    }
    
    TEST_PASS("Edge cases tests completed");
    return true;
}

bool test_error_messages() {
    std::cout << "\n=== Testing error messages ===" << std::endl;
    
    // Test that error messages contain the problematic path
    try {
        validate_file_path("../malicious.txt");
        std::cerr << "FAIL: Should have thrown exception" << std::endl;
        return false;
    } catch (const std::runtime_error& e) {
        std::string error_msg = e.what();
        TEST_ASSERT(error_msg.find("../malicious.txt") != std::string::npos, 
                   "Error message should contain the problematic path");
        TEST_PASS("Error message contains problematic path");
    }
    
    // Test null byte error message
    std::string path_with_null = "file";
    path_with_null += '\0';
    path_with_null += ".txt";
    try {
        validate_file_path(path_with_null);
        std::cerr << "FAIL: Should have thrown exception" << std::endl;
        return false;
    } catch (const std::runtime_error& e) {
        std::string error_msg = e.what();
        TEST_ASSERT(error_msg.find("null bytes") != std::string::npos, 
                   "Error message should mention null bytes");
        TEST_PASS("Null byte error message");
    }
    
    // Test path too long error message
    std::string long_path(PATH_MAX + 1, 'a');
    try {
        validate_file_path(long_path);
        std::cerr << "FAIL: Should have thrown exception" << std::endl;
        return false;
    } catch (const std::runtime_error& e) {
        std::string error_msg = e.what();
        TEST_ASSERT(error_msg.find("too long") != std::string::npos, 
                   "Error message should mention path too long");
        TEST_PASS("Path too long error message");
    }
    
    TEST_PASS("Error message tests completed");
    return true;
}

int main() {
    std::cout << "Running path validation security tests..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_contains_path_traversal();
    all_passed &= test_validate_file_path();
    all_passed &= test_safe_file_operations();
    all_passed &= test_edge_cases();
    all_passed &= test_error_messages();
    
    if (all_passed) {
        std::cout << "\n✅ All path validation security tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\n❌ Some path validation security tests failed!" << std::endl;
        return 1;
    }
} 