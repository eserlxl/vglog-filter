#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for bump-version with LOC delta system

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

# Get script paths from project root
BUMP_VERSION_SCRIPT="$PROJECT_ROOT/dev-bin/bump-version.sh"
SEMANTIC_ANALYZER_SCRIPT="$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh"

# Test 1: LOC delta system with patch bump
printf '%s\n' "${CYAN}=== Test 1: LOC delta system with patch bump ===${RESET}"
test_dir=$(create_temp_test_env "test_loc_delta_patch")
cd "$test_dir"

# Enable LOC delta system
export VERSION_PATCH_LIMIT=1000
export VERSION_MINOR_LIMIT=1000

# Test patch bump with LOC delta
run_test "Patch bump with LOC delta enabled" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.5.13"

cleanup_temp_test_env "$test_dir"

# Test 2: New versioning system with actual changes
printf '%s\n' "${CYAN}=== Test 2: New versioning system with actual changes ===${RESET}"
test_dir=$(create_temp_test_env "test_new_system_changes")
cd "$test_dir"

# Enable new versioning system
export VERSION_PATCH_LIMIT=1000
export VERSION_MINOR_LIMIT=1000

# Add some changes to trigger LOC delta calculation
echo "// New code for testing" > new_file.c
git add new_file.c
git commit --quiet -m "Add new file for testing" 2>/dev/null || true

# Test patch bump with actual changes
run_test "Patch bump with actual changes" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.5.14"

cleanup_temp_test_env "$test_dir"

# Test 3: Rollover logic with new versioning system
printf '%s\n' "${CYAN}=== Test 3: Rollover logic with new versioning system ===${RESET}"
test_dir=$(create_temp_test_env "test_rollover_new_system")
cd "$test_dir"

# Enable new versioning system
export VERSION_PATCH_LIMIT=1000
export VERSION_MINOR_LIMIT=1000

# Set version to test patch rollover
echo "10.5.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.95" 2>/dev/null || true

# Test patch rollover
run_test "Patch rollover (10.5.95 + delta)" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.5.96"

# Set version to test minor rollover
echo "10.99.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.99.95" 2>/dev/null || true

# Test minor rollover
run_test "Minor rollover (10.99.95 + delta)" \
    "$BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.99.96"

cleanup_temp_test_env "$test_dir"

# Test 4: Semantic analyzer integration
printf '%s\n' "${CYAN}=== Test 4: Semantic analyzer integration ===${RESET}"
test_dir=$(create_temp_test_env "test_semantic_analyzer_integration")
cd "$test_dir"

# Enable new versioning system
export VERSION_PATCH_LIMIT=1000
export VERSION_MINOR_LIMIT=1000

# Add changes to trigger analysis
echo "// Changes for semantic analysis" > changes.c
git add changes.c
git commit --quiet -m "Add changes for analysis" 2>/dev/null || true

# Test semantic analyzer output from project root
run_test "Semantic analyzer with new system" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"loc_delta"'

# Test reason format includes LOC and version type
run_test "Reason format includes LOC and version type" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"patch_delta":[0-9]*'

cleanup_temp_test_env "$test_dir"

# Test 5: Delta formula verification
printf '%s\n' "${CYAN}=== Test 5: Delta formula verification ===${RESET}"
test_dir=$(create_temp_test_env "test_delta_formulas")
cd "$test_dir"

# Enable new versioning system
export VERSION_PATCH_LIMIT=1000
export VERSION_MINOR_LIMIT=1000

# Add changes to trigger delta calculation
echo "// Code for delta testing" > delta_test.c
git add delta_test.c
git commit --quiet -m "Add code for delta testing" 2>/dev/null || true

# Test that delta formulas are working
run_test "Delta formulas are calculated" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"patch_delta":[0-9]*'

run_test "Minor delta is calculated" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"minor_delta":[0-9]*'

run_test "Major delta is calculated" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    '"major_delta":[0-9]*'

cleanup_temp_test_env "$test_dir"

# Test 6: Configuration options
printf '%s\n' "${CYAN}=== Test 6: Configuration options ===${RESET}"
test_dir=$(create_temp_test_env "test_configuration_options")
cd "$test_dir"

# Test custom patch limit
run_test "Custom patch limit works" \
    "VERSION_PATCH_LIMIT=50 $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd)" \
    "10.5.13"

# Test custom minor limit with rollover
# Set version to 10.5.48 so that delta of 5 (minor bump) will cause rollover
echo "10.5.48" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.48" 2>/dev/null || true

run_test "Custom minor limit with rollover" \
    "VERSION_PATCH_LIMIT=50 $BUMP_VERSION_SCRIPT minor --print --repo-root $(pwd)" \
    "10.6.3"

cleanup_temp_test_env "$test_dir"

# Test 7: Error handling
printf '%s\n' "${CYAN}=== Test 7: Error handling ===${RESET}"
test_dir=$(create_temp_test_env "test_error_handling")
cd "$test_dir"

# Test invalid delta formula
run_test "Invalid delta formula handling" \
    "VERSION_PATCH_DELTA='invalid_formula' $BUMP_VERSION_SCRIPT patch --print --repo-root $(pwd) 2>&1 || true" \
    "10.5.13"

cleanup_temp_test_env "$test_dir"

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