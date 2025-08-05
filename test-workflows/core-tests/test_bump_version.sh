#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for bump-version improvements with new versioning system

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

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

BUMP_VERSION_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/bump-version"

# Test 1: Early --print behavior (should exit before validations)
printf '%s\n' "${CYAN}=== Test 1: Early --print behavior ===${RESET}"
test_dir=$(create_temp_test_env "test_print_early")
cd "$test_dir"
run_test "Early --print exits without git checks" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"
cleanup_temp_test_env "$test_dir"

# Test 2: Dry-run accuracy for CMakeLists.txt
printf '%s\n' "${CYAN}=== Test 2: Dry-run CMakeLists.txt accuracy ===${RESET}"
test_dir=$(create_temp_test_env "test_dry_run_cmake")
cd "$test_dir"
run_test "Dry-run shows CMake update when version field exists" \
    "echo 'project(test VERSION 9.3.0)' > CMakeLists.txt && $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would update CMakeLists.txt to 9.3.1"
cleanup_temp_test_env "$test_dir"

test_dir=$(create_temp_test_env "test_dry_run_cmake_no_field")
cd "$test_dir"
run_test "Dry-run skips CMake when no version field" \
    "echo 'project(test)' > CMakeLists.txt && $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would skip CMakeLists.txt update (no recognizable version field)"
cleanup_temp_test_env "$test_dir"

# Test 3: New versioning system with LOC delta
printf '%s\n' "${CYAN}=== Test 3: New versioning system with LOC delta ===${RESET}"
test_dir=$(create_temp_test_env "test_loc_delta_system")
cd "$test_dir"

# Enable LOC delta system
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test patch bump with LOC delta
run_test "Patch bump with LOC delta enabled" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

# Test that minor bump increments version
minor_result=$("$BUMP_VERSION_SCRIPT" minor --print --repo-root "$(pwd)" 2>/dev/null)
if [[ "$minor_result" =~ ^9\.3\.[0-9]+$ ]] && [[ "$minor_result" != "9.3.0" ]]; then
    echo "✓ PASS: Minor bump with LOC delta enabled ($minor_result)"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Minor bump with LOC delta enabled (expected 9.3.x, got $minor_result)"
    ((TESTS_FAILED++))
fi

# Test that major bump increments version
major_result=$("$BUMP_VERSION_SCRIPT" major --print --repo-root "$(pwd)" 2>/dev/null)
if [[ "$major_result" =~ ^9\.3\.[0-9]+$ ]] && [[ "$major_result" != "9.3.0" ]]; then
    echo "✓ PASS: Major bump with LOC delta enabled ($major_result)"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Major bump with LOC delta enabled (expected 9.3.x, got $major_result)"
    ((TESTS_FAILED++))
fi

cleanup_temp_test_env "$test_dir"

# Test 4: Rollover logic with new versioning system
printf '%s\n' "${CYAN}=== Test 4: Rollover logic with new versioning system ===${RESET}"
test_dir=$(create_temp_test_env "test_rollover_logic")
cd "$test_dir"

# Set version to test rollover
echo "9.3.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.3.95" 2>/dev/null || true

# Test patch rollover
run_test "Patch rollover (9.3.95 + 6 = 9.3.96)" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.96"

# Set version to test minor rollover
echo "9.99.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.99.95" 2>/dev/null || true

# Test minor rollover
run_test "Minor rollover (9.99.95 + 6 = 10.0.0)" \
    "$BUMP_VERSION_SCRIPT minor --print --repo-root $(pwd)" \
    "10.0.0"

cleanup_temp_test_env "$test_dir"

# Test 5: Dirty file detection (only when committing/tagging)
printf '%s\n' "${CYAN}=== Test 5: Dirty file detection ===${RESET}"
test_dir=$(create_temp_test_env "test_dirty_files")
cd "$test_dir"
echo "original content" > some_file.txt
git add some_file.txt
git commit --quiet -m "Add some_file.txt" 2>/dev/null || true
echo "modified content" > some_file.txt
run_test "Dirty file detection works with commit" \
    "$BUMP_VERSION_SCRIPT patch --commit --repo-root $(pwd)" \
    "Error: working tree has disallowed changes"
cleanup_temp_test_env "$test_dir"

# Test 6: Version format validation
printf '%s\n' "${CYAN}=== Test 6: Version format validation ===${RESET}"
test_dir=$(create_temp_test_env "test_version_format")
cd "$test_dir"
echo "invalid-version" > VERSION
git add VERSION
git commit --quiet -m "Set invalid version" 2>/dev/null || true
run_test "Invalid version format detection" \
    "$BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Error: Invalid version format"
cleanup_temp_test_env "$test_dir"

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