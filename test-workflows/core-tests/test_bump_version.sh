#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for bump-version improvements with new versioning system

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
    echo "9.3.0" > VERSION
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
    "9.3.1"
cleanup_test "test_print_early"

# Test 2: Dry-run accuracy for CMakeLists.txt
printf '%s\n' "${CYAN}=== Test 2: Dry-run CMakeLists.txt accuracy ===${RESET}"
setup_test "test_dry_run_cmake"
run_test "Dry-run shows CMake update when version field exists" \
    "echo 'project(test VERSION 9.3.0)' > CMakeLists.txt && $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would update CMakeLists.txt to 9.3.1"
cleanup_test "test_dry_run_cmake"

setup_test "test_dry_run_cmake_no_field"
run_test "Dry-run skips CMake when no version field" \
    "echo 'project(test)' > CMakeLists.txt && $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would skip CMakeLists.txt update (no recognizable version field)"
cleanup_test "test_dry_run_cmake_no_field"

# Test 3: New versioning system with LOC delta
printf '%s\n' "${CYAN}=== Test 3: New versioning system with LOC delta ===${RESET}"
setup_test "test_loc_delta_system"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test patch bump with LOC delta
run_test "Patch bump with LOC delta enabled" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

# Test minor bump with LOC delta
run_test "Minor bump with LOC delta enabled" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT minor --print --repo-root $(pwd)" \
    "9.3.5"

# Test major bump with LOC delta
run_test "Major bump with LOC delta enabled" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT major --print --repo-root $(pwd)" \
    "9.3.10"

cleanup_test "test_loc_delta_system"

# Test 4: Rollover logic with new versioning system
printf '%s\n' "${CYAN}=== Test 4: Rollover logic with new versioning system ===${RESET}"
setup_test "test_rollover_logic"

# Set version to test rollover
echo "9.3.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.3.95" 2>/dev/null || true

# Test patch rollover
run_test "Patch rollover (9.3.95 + 6 = 9.4.1)" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.4.1"

# Set version to test minor rollover
echo "9.99.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.99.95" 2>/dev/null || true

# Test minor rollover
run_test "Minor rollover (9.99.95 + 6 = 10.0.1)" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.0.1"

cleanup_test "test_rollover_logic"

# Test 5: Dirty file detection
printf '%s\n' "${CYAN}=== Test 5: Dirty file detection ===${RESET}"
setup_test "test_dirty_files"
echo "modified" > some_file.txt
run_test "Dirty file detection works" \
    "$BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Error: Working directory is not clean"
cleanup_test "test_dirty_files"

# Test 6: Version format validation
printf '%s\n' "${CYAN}=== Test 6: Version format validation ===${RESET}"
setup_test "test_version_format"
echo "invalid-version" > VERSION
git add VERSION
git commit --quiet -m "Set invalid version" 2>/dev/null || true
run_test "Invalid version format detection" \
    "$BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Error: Invalid version format"
cleanup_test "test_version_format"

# Print summary
printf '%s\n' "${CYAN}=== Test Summary ===${RESET}"
printf '%s\n' "${GREEN}Tests passed: $TESTS_PASSED${RESET}"
printf '%s\n' "${RED}Tests failed: $TESTS_FAILED${RESET}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '%s\n' "${GREEN}All tests passed!${RESET}"
    exit 0
else
    printf '%s\n' "${RED}Some tests failed!${RESET}"
    exit 1
fi 