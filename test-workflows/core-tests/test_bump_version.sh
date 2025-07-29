#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for bump-version improvements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    printf '%s\n' "${CYAN}Running test: $test_name${RESET}"
    
    # Run the command and capture output
    local output
    output=$(eval "$test_command" 2>&1 || true)
    
    # Check if output contains expected text
    if echo "$output" | grep -q "$expected_output"; then
        printf '%s\n' "${GREEN}✓ PASS: $test_name${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%s\n' "${RED}✗ FAIL: $test_name${RESET}"
        printf '%s\n' "${YELLOW}Expected: $expected_output${RESET}"
        printf '%s\n' "${YELLOW}Got: $output${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    printf '%s\n' ""
    
    # Return success to prevent script from exiting
    return 0
}

# Function to setup test environment
setup_test() {
    local test_dir="$1"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial VERSION file
    echo "1.0.0" > VERSION
    git add VERSION
    git commit --quiet -m "Initial version" 2>/dev/null || true
}

BUMP_VERSION_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/bump-version"

# Function to cleanup test environment
cleanup_test() {
    local test_dir="$1"
    cd ..
    rm -rf "$test_dir" 2>/dev/null || true
    return 0
}

# Test 1: Early --print behavior (should exit before validations)
printf '%s\n' "${CYAN}=== Test 1: Early --print behavior ===${RESET}"
setup_test "test_print_early"
run_test "Early --print exits without git checks" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "1.0.1"
cleanup_test "test_print_early"

# Test 2: Dry-run accuracy for CMakeLists.txt
printf '%s\n' "${CYAN}=== Test 2: Dry-run CMakeLists.txt accuracy ===${RESET}"
setup_test "test_dry_run_cmake"
run_test "Dry-run shows CMake update when version field exists" \
    "echo 'project(test VERSION 1.0.0)' > CMakeLists.txt && $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would update CMakeLists.txt to 1.0.1"
cleanup_test "test_dry_run_cmake"

setup_test "test_dry_run_cmake_no_field"
run_test "Dry-run skips CMake when no version field" \
    "echo 'project(test)' > CMakeLists.txt && $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would skip CMakeLists.txt update (no recognizable version field)"
cleanup_test "test_dry_run_cmake_no_field"

# Test 3: Dirty file detection
printf '%s\n' "${CYAN}=== Test 3: Dirty file detection ===${RESET}"
setup_test "test_dirty_files"
echo "modified" > some_file.txt
git add some_file.txt
git commit --quiet -m "Add some_file.txt" 2>/dev/null || true
echo "modified again" > some_file.txt
run_test "Dirty tree detection shows file names" \
    "$BUMP_VERSION_SCRIPT patch --commit --repo-root $(pwd) 2>&1 || true" \
    "Dirty files:"
cleanup_test "test_dirty_files"

# Test 4: Prerelease behavior
printf '%s\n' "${CYAN}=== Test 4: Prerelease behavior ===${RESET}"
setup_test "test_prerelease"
run_test "Prerelease --print works" \
    "$BUMP_VERSION_SCRIPT --set 1.0.0-rc.1 --allow-prerelease --print --repo-root $(pwd)" \
    "1.0.0-rc.1"
cleanup_test "test_prerelease"

setup_test "test_prerelease_tag_fail"
run_test "Prerelease tag creation fails" \
    "$BUMP_VERSION_SCRIPT --set 1.0.0-rc.1 --allow-prerelease --tag --repo-root $(pwd) 2>&1 || true" \
    "Cannot create tag for pre-release version"
cleanup_test "test_prerelease_tag_fail"

# Test 5: Commit file restriction
printf '%s\n' "${CYAN}=== Test 5: Commit file restriction ===${RESET}"
setup_test "test_commit_restriction"
echo "staged" > staged_file.txt
git add staged_file.txt
run_test "Commit only includes VERSION and CMakeLists.txt" \
    "$BUMP_VERSION_SCRIPT patch --commit --dry-run --repo-root $(pwd)" \
    "Would commit files: VERSION"
cleanup_test "test_commit_restriction"

# Test 6: Usage documentation
printf '%s\n' "${CYAN}=== Test 6: Usage documentation ===${RESET}"
run_test "Usage shows behavior notes" \
    "$BUMP_VERSION_SCRIPT --help" \
    "Behavior notes:"
run_test "Usage shows file tracking requirements" \
    "$BUMP_VERSION_SCRIPT --help" \
    "File Tracking Requirements:"

# Print summary
printf '%s\n' "${CYAN}=== Test Summary ===${RESET}"
printf '%s\n' "${GREEN}Tests passed: $TESTS_PASSED${RESET}"
printf '%s\n' "${RED}Tests failed: $TESTS_FAILED${RESET}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '%s\n' "${GREEN}All tests passed!${RESET}"
    exit 0
else
    printf '%s\n' "${RED}Some tests failed.${RESET}"
    exit 1
fi 