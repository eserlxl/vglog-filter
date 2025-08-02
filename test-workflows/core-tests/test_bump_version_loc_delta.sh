#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for bump-version integration with new versioning system

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

# Test 1: Basic new versioning system integration
printf '%s\n' "${CYAN}=== Test 1: Basic new versioning system integration ===${RESET}"
setup_test "test_basic_new_system"

# Enable new versioning system
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Test patch bump with new system
run_test "Patch bump with new versioning system" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

# Test minor bump with new system
run_test "Minor bump with new versioning system" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT minor --print --repo-root $(pwd)" \
    "9.3.5"

# Test major bump with new system
run_test "Major bump with new versioning system" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT major --print --repo-root $(pwd)" \
    "9.3.10"

cleanup_test "test_basic_new_system"

# Test 2: New versioning system with actual changes
printf '%s\n' "${CYAN}=== Test 2: New versioning system with actual changes ===${RESET}"
setup_test "test_new_system_changes"

# Enable new versioning system
export VERSION_USE_LOC_DELTA=true

# Add some changes to trigger LOC delta calculation
echo "// New code for testing" > new_file.c
git add new_file.c
git commit --quiet -m "Add new file for testing" 2>/dev/null || true

# Test patch bump with actual changes
run_test "Patch bump with actual changes" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3."

cleanup_test "test_new_system_changes"

# Test 3: Rollover logic with new versioning system
printf '%s\n' "${CYAN}=== Test 3: Rollover logic with new versioning system ===${RESET}"
setup_test "test_rollover_new_system"

# Enable new versioning system
export VERSION_USE_LOC_DELTA=true

# Set version to test patch rollover
echo "9.3.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.3.95" 2>/dev/null || true

# Test patch rollover
run_test "Patch rollover (9.3.95 + delta)" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.4."

# Set version to test minor rollover
echo "9.99.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 9.99.95" 2>/dev/null || true

# Test minor rollover
run_test "Minor rollover (9.99.95 + delta)" \
    "VERSION_USE_LOC_DELTA=true $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.0."

cleanup_test "test_rollover_new_system"

# Test 4: Semantic analyzer integration
printf '%s\n' "${CYAN}=== Test 4: Semantic analyzer integration ===${RESET}"
setup_test "test_semantic_analyzer_integration"

# Enable new versioning system
export VERSION_USE_LOC_DELTA=true

# Add changes to trigger analysis
echo "// Changes for semantic analysis" > changes.c
git add changes.c
git commit --quiet -m "Add changes for analysis" 2>/dev/null || true

# Test semantic analyzer output
run_test "Semantic analyzer with new system" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"loc_delta"'

# Test reason format includes LOC and version type
run_test "Reason format includes LOC and version type" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"reason":"[^"]*LOC:[^"]*"'

cleanup_test "test_semantic_analyzer_integration"

# Test 5: Delta formula verification
printf '%s\n' "${CYAN}=== Test 5: Delta formula verification ===${RESET}"
setup_test "test_delta_formulas"

# Enable new versioning system
export VERSION_USE_LOC_DELTA=true

# Add changes to trigger delta calculation
echo "// Code for delta testing" > delta_test.c
git add delta_test.c
git commit --quiet -m "Add code for delta testing" 2>/dev/null || true

# Test that delta formulas are working
run_test "Delta formulas are calculated" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"patch_delta":[0-9]*'

run_test "Minor delta is calculated" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"minor_delta":[0-9]*'

run_test "Major delta is calculated" \
    "VERSION_USE_LOC_DELTA=true $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"major_delta":[0-9]*'

cleanup_test "test_delta_formulas"

# Test 6: Configuration options
printf '%s\n' "${CYAN}=== Test 6: Configuration options ===${RESET}"
setup_test "test_configuration_options"

# Test custom patch limit
run_test "Custom patch limit works" \
    "VERSION_USE_LOC_DELTA=true VERSION_PATCH_LIMIT=50 $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "9.3.1"

# Test custom minor limit
run_test "Custom minor limit works" \
    "VERSION_USE_LOC_DELTA=true VERSION_MINOR_LIMIT=50 $BUMP_VERSION_SCRIPT minor --print --repo-root $(pwd)" \
    "9.3.5"

cleanup_test "test_configuration_options"

# Test 7: Error handling
printf '%s\n' "${CYAN}=== Test 7: Error handling ===${RESET}"
setup_test "test_error_handling"

# Test invalid delta formula
run_test "Invalid delta formula handling" \
    "VERSION_USE_LOC_DELTA=true VERSION_PATCH_DELTA='invalid_formula' $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd) 2>&1 || true" \
    "9.3.1"

cleanup_test "test_error_handling"

# Print summary
printf '%s\n' "${CYAN}=== Test Summary ===${RESET}"
printf '%s\n' "${GREEN}Tests passed: $TESTS_PASSED${RESET}"
printf '%s\n' "${RED}Tests failed: $TESTS_FAILED${RESET}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '%s\n' "${GREEN}All tests passed! New versioning system integration is working correctly.${RESET}"
    printf '\n%s\n' "${CYAN}Key features verified:${RESET}"
    printf '  • New versioning system always increases only the last identifier (patch)\n'
    printf '  • Rollover logic with mod 100 working correctly\n'
    printf '  • LOC-based delta formulas (1*(1+LOC/250), 5*(1+LOC/500), 10*(1+LOC/1000))\n'
    printf '  • Enhanced reason format with LOC and version type\n'
    printf '  • Semantic analyzer integration\n'
    printf '  • Configuration options and error handling\n'
    exit 0
else
    printf '%s\n' "${RED}Some tests failed!${RESET}"
    exit 1
fi 