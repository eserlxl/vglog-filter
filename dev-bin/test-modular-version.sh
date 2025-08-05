#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for modular version management components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
test_passed() {
    printf '%s✓ PASS: %s%s\n' "${GREEN}" "$1" "${RESET}"
    ((TESTS_PASSED++))
}

test_failed() {
    printf '%s✗ FAIL: %s%s\n' "${RED}" "$1" "${RESET}"
    printf '  Error: %s\n' "$2"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    local command="$2"
    local expected_output="$3"
    
    printf '%sRunning: %s%s\n' "${CYAN}" "$test_name" "${RESET}"
    
    local output
    if output=$(eval "$command" 2>&1); then
        if [[ "$output" == *"$expected_output"* ]]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Expected '$expected_output' in output, got: $output"
        fi
    else
        test_failed "$test_name" "Command failed with exit code $?"
    fi
}

# Test version-utils
test_version_utils() {
    printf '\n%s=== Testing version-utils ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test last-tag command
    run_test "version-utils last-tag" \
        "./dev-bin/version-utils last-tag v" \
        ""
    
    # Test hash-file command
    run_test "version-utils hash-file" \
        "./dev-bin/version-utils hash-file VERSION" \
        ""
    
    # Test read-version command
    run_test "version-utils read-version" \
        "./dev-bin/version-utils read-version VERSION" \
        "10.5.12"
}

# Test version-validator
test_version_validator() {
    printf '\n%s=== Testing version-validator ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test validate command
    run_test "version-validator validate" \
        "./dev-bin/version-validator validate 1.0.0" \
        "Version format is valid"
    
    # Test compare command
    run_test "version-validator compare" \
        "./dev-bin/version-validator compare 1.0.0 1.0.1" \
        "-1"
    
    # Test parse command
    run_test "version-validator parse" \
        "./dev-bin/version-validator parse 1.2.3" \
        "1"
    
    # Test is-prerelease command
    run_test "version-validator is-prerelease" \
        "./dev-bin/version-validator is-prerelease 1.0.0-rc.1" \
        "true"
}

# Test version-calculator-loc
test_version_calculator() {
    printf '\n%s=== Testing version-calculator-loc ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test basic calculation
    run_test "version-calculator-loc basic" \
        "./dev-bin/version-calculator-loc --current-version 1.0.0 --bump-type patch" \
        "1.0.1"
    
    # Test help command
    run_test "version-calculator-loc help" \
        "./dev-bin/version-calculator-loc --help" \
        "Usage:"
}

# Test cmake-updater
test_cmake_updater() {
    printf '\n%s=== Testing cmake-updater ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test detect command
    run_test "cmake-updater detect" \
        "./dev-bin/cmake-updater detect CMakeLists.txt" \
        "variable"
    
    # Test help command
    run_test "cmake-updater help" \
        "./dev-bin/cmake-updater" \
        "Usage:"
}

# Test git-operations
test_git_operations() {
    printf '\n%s=== Testing git-operations ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test help command
    run_test "git-operations help" \
        "./dev-bin/git-operations" \
        "Usage:"
}

# Test cli-parser
test_cli_parser() {
    printf '\n%s=== Testing cli-parser ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test help command
    run_test "cli-parser help" \
        "./dev-bin/cli-parser help" \
        "Usage:"
    
    # Test validate command
    run_test "cli-parser validate" \
        "./dev-bin/cli-parser validate patch --commit" \
        "CLI arguments are valid"
}

# Test bump-version-core
test_bump_version_core() {
    printf '\n%s=== Testing bump-version-core ===%s\n' "${YELLOW}" "${RESET}"
    
    # Test help command
    run_test "bump-version-core help" \
        "./dev-bin/bump-version-core --help" \
        "Usage:"
    
    # Test dry run
    run_test "bump-version-core dry-run" \
        "./dev-bin/bump-version-core patch --dry-run" \
        "10.5.13"
}

# Test comparison with original
test_comparison() {
    printf '\n%s=== Testing comparison with original ===%s\n' "${YELLOW}" "${RESET}"
    
    # Compare dry run outputs
    local original_output
    local modular_output
    
    original_output=$(./dev-bin/bump-version patch --dry-run 2>/dev/null | tail -1)
    modular_output=$(./dev-bin/bump-version-core patch --dry-run 2>/dev/null | tail -1)
    
    if [[ "$original_output" == "$modular_output" ]]; then
        test_passed "Output comparison"
    else
        test_failed "Output comparison" "Original: '$original_output', Modular: '$modular_output'"
    fi
}

# Main test execution
main() {
    printf '%sStarting modular version management tests...%s\n' "${CYAN}" "${RESET}"
    
    # Check if we're in the right directory
    if [[ ! -f "VERSION" ]]; then
        printf '%sError: VERSION file not found. Run this script from the project root.%s\n' "${RED}" "${RESET}"
        exit 1
    fi
    
    # Run all tests
    test_version_utils
    test_version_validator
    test_version_calculator
    test_cmake_updater
    test_git_operations
    test_cli_parser
    test_bump_version_core
    test_comparison
    
    # Print summary
    printf '\n%s=== Test Summary ===%s\n' "${YELLOW}" "${RESET}"
    printf 'Tests passed: %s%d%s\n' "${GREEN}" "$TESTS_PASSED" "${RESET}"
    printf 'Tests failed: %s%d%s\n' "${RED}" "$TESTS_FAILED" "${RESET}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf '\n%sAll tests passed! Modular version management is working correctly.%s\n' "${GREEN}" "${RESET}"
        exit 0
    else
        printf '\n%sSome tests failed. Please check the output above.%s\n' "${RED}" "${RESET}"
        exit 1
    fi
}

# Run main function
main "$@" 