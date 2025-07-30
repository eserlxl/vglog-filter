#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Consolidated test for path classification functionality
# Tests all path classification scenarios in a single file

echo "=== Testing Path Classification (Consolidated) ==="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a classification test
test_classification() {
    local path="$1"
    local expected_result="$2"
    local test_name="$3"
    
    # Define the classify_path function with simpler patterns
    classify_path() {
        local path="$1"
        
        # Check for build/artifact directories
        if [[ "$path" =~ ^build/ ]] || [[ "$path" =~ ^dist/ ]] || [[ "$path" =~ ^out/ ]] || [[ "$path" =~ ^third_party/ ]] || [[ "$path" =~ ^vendor/ ]] || [[ "$path" =~ ^\.git/ ]] || [[ "$path" =~ ^node_modules/ ]] || [[ "$path" =~ ^target/ ]] || [[ "$path" =~ ^bin/ ]] || [[ "$path" =~ ^obj/ ]]; then
            return 0
        fi
        
        # Check for build/artifact file extensions
        if [[ "$path" =~ \.lock$ ]] || [[ "$path" =~ \.exe$ ]] || [[ "$path" =~ \.dll$ ]] || [[ "$path" =~ \.so$ ]] || [[ "$path" =~ \.dylib$ ]] || [[ "$path" =~ \.jar$ ]] || [[ "$path" =~ \.war$ ]] || [[ "$path" =~ \.ear$ ]] || [[ "$path" =~ \.zip$ ]] || [[ "$path" =~ \.tar$ ]] || [[ "$path" =~ \.gz$ ]] || [[ "$path" =~ \.bz2$ ]] || [[ "$path" =~ \.xz$ ]] || [[ "$path" =~ \.7z$ ]] || [[ "$path" =~ \.rar$ ]]; then
            return 0
        fi
        
        # Check for test directories
        if [[ "$path" =~ ^test/ ]] || [[ "$path" =~ ^tests/ ]]; then
            return 10
        fi
        
        # Check for documentation
        if [[ "$path" =~ ^doc/ ]] || [[ "$path" =~ ^docs/ ]] || [[ "$path" =~ ^README ]]; then
            return 20
        fi
        
        # Check for source files
        if [[ "$path" =~ \.c$ ]] || [[ "$path" =~ \.cc$ ]] || [[ "$path" =~ \.cpp$ ]] || [[ "$path" =~ \.cxx$ ]] || [[ "$path" =~ \.h$ ]] || [[ "$path" =~ \.hpp$ ]] || [[ "$path" =~ \.hh$ ]] || [[ "$path" =~ ^src/ ]] || [[ "$path" =~ ^source/ ]] || [[ "$path" =~ ^app/ ]]; then
            return 30
        fi
        
        return 0
    }
    
    # Run the classification
    classify_path "$path"
    local result=$?
    
    # Check result
    if [[ $result -eq $expected_result ]]; then
        echo -e "\033[0;32m✓ $test_name: $path -> $result (expected: $expected_result)\033[0m"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "\033[0;31m✗ $test_name: $path -> $result (expected: $expected_result)\033[0m"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Documentation files (should return 20)
echo "Testing documentation file classification..."
test_classification "doc/README.md" 20 "Documentation file"
test_classification "docs/api.md" 20 "Documentation file"
test_classification "README" 20 "README file"

# Test 2: Source files (should return 30)
echo "Testing source file classification..."
test_classification "src/main.cpp" 30 "C++ source file"
test_classification "src/header.h" 30 "C header file"
test_classification "app/helper.cc" 30 "C++ source file"
test_classification "source/utils.c" 30 "C source file"

# Test 3: Test files (should return 10)
echo "Testing test file classification..."
test_classification "test/unit_test.cpp" 10 "Test file"
test_classification "tests/integration_test.c" 10 "Test file"

# Test 4: Build/artifact files (should return 0)
echo "Testing build/artifact file classification..."
test_classification "build/object.o" 0 "Build artifact"
test_classification "dist/app.exe" 0 "Executable"
test_classification "node_modules/package" 0 "Node modules"
test_classification "target/debug" 0 "Build target"
test_classification "vendor/lib.so" 0 "Shared library"
test_classification "package-lock.json" 0 "Lock file"

# Test 5: Edge cases
echo "Testing edge cases..."
test_classification "" 0 "Empty path"
test_classification "unknown.txt" 0 "Unknown file type"
test_classification "src/test/helper.cpp" 30 "Source file in test directory (prioritizes source over test)"

# Print summary
echo ""
echo "=== Classification Test Summary ==="
echo -e "\033[0;32mTests passed: $TESTS_PASSED\033[0m"
echo -e "\033[0;31mTests failed: $TESTS_FAILED\033[0m"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\033[0;32mAll classification tests passed!\033[0m"
    exit 0
else
    echo -e "\033[0;31mSome classification tests failed!\033[0m"
    exit 1
fi 