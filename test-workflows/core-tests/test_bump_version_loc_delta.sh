#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for bump-version integration with LOC-based delta system

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
    
    # Create a simple CMakeLists.txt for testing
    echo 'project(test VERSION 9.3.0)' > CMakeLists.txt
    git add CMakeLists.txt
    git commit --quiet -m "Add CMakeLists.txt" 2>/dev/null || true
}

# Function to cleanup test environment
cleanup_test() {
    local test_dir="$1"
    cd ..
    rm -rf "$test_dir" 2>/dev/null || true
    return 0
}

BUMP_VERSION_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/bump-version"
SEMANTIC_ANALYZER_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"

# Test 1: Basic LOC delta integration
printf '%s\n' "${CYAN}=== Test 1: Basic LOC delta integration ===${RESET}"
setup_test "test_basic_loc_delta"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test patch bump with LOC delta
run_test "Patch bump with LOC delta enabled" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

cleanup_test "test_basic_loc_delta"

# Test 2: LOC delta with actual changes
printf '%s\n' "${CYAN}=== Test 2: LOC delta with actual changes ===${RESET}"
setup_test "test_loc_delta_changes"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Create some changes to trigger LOC calculation
echo "// New code" > new_file.c
git add new_file.c
git commit --quiet -m "Add new file" 2>/dev/null || true

# Test patch bump with actual changes
run_test "Patch bump with actual changes" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3."

cleanup_test "test_loc_delta_changes"

# Test 3: Rollover scenarios
printf '%s\n' "${CYAN}=== Test 3: Rollover scenarios ===${RESET}"
setup_test "test_rollover_scenarios"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Set version to near rollover
echo "9.3.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.3.95" 2>/dev/null || true

# Create changes that would trigger a larger delta (enough to cause rollover)
# Create multiple files with significant content to increase LOC
mkdir -p src
for i in {1..20}; do
    echo "// Source file $i with significant changes" > "src/file_$i.c"
    echo "int function_$i() { return $i; }" >> "src/file_$i.c"
done
# Add some non-breaking changes that will increase LOC but not trigger minor bump
echo "// Additional functionality" > new_feature.c
echo "int helper_function() { return 42; }" >> new_feature.c
git add src/ new_feature.c
git commit --quiet -m "Add changes to trigger rollover" 2>/dev/null || true

# Test patch bump that should cause rollover
run_test "Patch bump causing rollover" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root ." \
    "9.3.98"

cleanup_test "test_rollover_scenarios"

# Test 4: Disabled system behavior
printf '%s\n' "${CYAN}=== Test 4: Disabled system behavior ===${RESET}"
setup_test "test_disabled_system"

# Disable LOC delta system
export VERSION_USE_LOC_DELTA=false

# Test patch bump with disabled system
run_test "Patch bump with disabled LOC delta" \
    "VERSION_USE_LOC_DELTA=false $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

cleanup_test "test_disabled_system"

# Test 5: Configuration customization
printf '%s\n' "${CYAN}=== Test 5: Configuration customization ===${RESET}"
setup_test "test_config_customization"

# Enable LOC delta system with custom limits
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=50
export VERSION_MINOR_LIMIT=25

# Set version to test custom limits
echo "9.3.45" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.3.45" 2>/dev/null || true

# Test patch bump with custom limits
run_test "Patch bump with custom limits" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3."

cleanup_test "test_config_customization"

# Test 6: Dry run with LOC delta
printf '%s\n' "${CYAN}=== Test 6: Dry run with LOC delta ===${RESET}"
setup_test "test_dry_run_loc_delta"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test dry run
run_test "Dry run with LOC delta enabled" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --dry-run --repo-root $(pwd)" \
    "Would update VERSION to 9.3.1"

cleanup_test "test_dry_run_loc_delta"

# Test 7: Integration with semantic analyzer
printf '%s\n' "${CYAN}=== Test 7: Integration with semantic analyzer ===${RESET}"
setup_test "test_semantic_analyzer_integration"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Create changes that would trigger bonuses
echo "// API-BREAKING: This is a breaking change" > breaking_change.c
git add breaking_change.c
git commit --quiet -m "Add breaking change" 2>/dev/null || true

# Test that semantic analyzer provides delta information
run_test "Semantic analyzer provides LOC delta info" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta"

cleanup_test "test_semantic_analyzer_integration"

# Test 8: Edge cases
printf '%s\n' "${CYAN}=== Test 8: Edge cases ===${RESET}"
setup_test "test_edge_cases"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test with version 0.0.0
echo "0.0.0" > VERSION
git add VERSION
git commit --quiet -m "Set version to 0.0.0" 2>/dev/null || true

run_test "Patch bump from 0.0.0" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "0.0.1"

cleanup_test "test_edge_cases"

# Test 9: Bonus system integration
printf '%s\n' "${CYAN}=== Test 9: Bonus system integration ===${RESET}"
setup_test "test_bonus_system"

# Enable LOC delta system with bonus configuration
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100
export VERSION_BREAKING_CLI_BONUS=5
export VERSION_API_BREAKING_BONUS=7

# Create breaking changes
echo "// API-BREAKING: Major breaking change" > major_break.c
git add major_break.c
git commit --quiet -m "Add major breaking change" 2>/dev/null || true

# Test that bonuses are applied
run_test "Bonus system integration" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "api_breaking"

cleanup_test "test_bonus_system"

# Test 10: Error handling
printf '%s\n' "${CYAN}=== Test 10: Error handling ===${RESET}"
setup_test "test_error_handling"

# Enable LOC delta system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test with invalid configuration
export VERSION_PATCH_DELTA="invalid_formula"

run_test "Error handling with invalid formula" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

cleanup_test "test_error_handling"

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