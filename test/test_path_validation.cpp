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
#include <filesystem>
#include <stdexcept>
#include <path_validation.h>
#include "test_helpers.h"

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

bool test_valid_paths() {
    std::cout << "\n=== Testing valid paths ===" << std::endl;
    
    try {
        auto p = path_validation::validate_and_canonicalize("test.txt");
        TEST_ASSERT(p.filename() == "test.txt", "Simple filename should be valid");
        TEST_PASS("Simple filename validation");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: Simple filename should be valid: " << e.what() << std::endl;
        return false;
    }

    try {
        auto p = path_validation::validate_and_canonicalize("-");
        TEST_ASSERT(p == "-", "Stdin should be valid");
        TEST_PASS("Stdin validation");
    } catch (const std::exception& e) {
        std::cerr << "FAIL: Stdin should be valid: " << e.what() << std::endl;
        return false;
    }

    return true;
}

bool test_invalid_paths() {
    std::cout << "\n=== Testing invalid paths ===" << std::endl;

    TEST_EXPECT_EXCEPTION(
        path_validation::validate_and_canonicalize("/etc/passwd"),
        std::runtime_error,
        "Absolute path should be blocked"
    );

    TEST_EXPECT_EXCEPTION(
        path_validation::validate_and_canonicalize("../secret.txt"),
        std::runtime_error,
        "Path traversal should be blocked"
    );
    
    std::string path_with_null = "file";
    path_with_null += '\0';
    path_with_null += ".txt";
    TEST_EXPECT_EXCEPTION(
        path_validation::validate_and_canonicalize(path_with_null),
        std::runtime_error,
        "Null byte in path should be blocked"
    );

    return true;
}


int main() {
    std::cout << "Running path validation tests..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_valid_paths();
    all_passed &= test_invalid_paths();
    
    if (all_passed) {
        std::cout << "\n✅ All path validation tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\n❌ Some path validation tests failed!" << std::endl;
        return 1;
    }
}