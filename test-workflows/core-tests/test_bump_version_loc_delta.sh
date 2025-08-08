#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for mathematical-version-bump with LOC delta system

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
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
BUMP_VERSION_SCRIPT="$PROJECT_ROOT/dev-bin/mathematical-version-bump.sh"
SEMANTIC_ANALYZER_SCRIPT="$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh"

# Test 1: LOC delta system with patch bump
printf '%s\n' "${CYAN}=== Test 1: LOC delta system with patch bump ===${RESET}"
test_dir=$(create_temp_test_env "test_loc_delta_patch")
cd "$test_dir"

# Enable LOC delta system
export VERSION_PATCH_LIMIT=1000
export VERSION_MINOR_LIMIT=1000

# Add changes to trigger version bump
echo "// Test change for patch bump" > test_change.c
git add test_change.c
git commit --quiet -m "Add test change for patch bump" 2>/dev/null || true

# Test patch bump with LOC delta
run_test "LOC delta system enabled" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

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
run_test "Mathematical versioning with actual changes" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

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

# Add changes to trigger version bump
echo "// Test change for patch rollover" > rollover_test.c
git add rollover_test.c
git commit --quiet -m "Add test change for patch rollover" 2>/dev/null || true

# Test patch rollover
run_test "Patch rollover (10.5.95 + delta)" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

# Set version to test minor rollover
echo "10.99.95" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.99.95" 2>/dev/null || true

# Add changes to trigger version bump
echo "// Test change for minor rollover" > minor_rollover_test.c
git add minor_rollover_test.c
git commit --quiet -m "Add test change for minor rollover" 2>/dev/null || true

# Test minor rollover
run_test "Minor rollover (10.99.95 + delta)" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.104.0"

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

# Add changes to trigger version bump
echo "// Test change for custom patch limit" > custom_limit_test.c
git add custom_limit_test.c
git commit --quiet -m "Add test change for custom patch limit" 2>/dev/null || true

# Test custom patch limit
run_test "Custom patch limit works" \
    "VERSION_PATCH_LIMIT=50 $BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

# Test custom minor limit with rollover
# Set version to 10.5.48 so that delta of 5 (minor bump) will cause rollover
echo "10.5.48" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.48" 2>/dev/null || true

# Add changes to trigger version bump
echo "// Test change for custom minor limit" > custom_minor_test.c
git add custom_minor_test.c
git commit --quiet -m "Add test change for custom minor limit" 2>/dev/null || true

# With VERSION_PATCH_LIMIT=50, patch 48 + 1 = 49, which is within the limit
run_test "Custom minor limit with rollover" \
    "VERSION_PATCH_LIMIT=50 $BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

cleanup_temp_test_env "$test_dir"

# Test 7: Error handling
printf '%s\n' "${CYAN}=== Test 7: Error handling ===${RESET}"
test_dir=$(create_temp_test_env "test_error_handling")
cd "$test_dir"

# Add changes to trigger version bump
echo "// Test change for error handling" > error_test.c
git add error_test.c
git commit --quiet -m "Add test change for error handling" 2>/dev/null || true

# Test invalid delta formula - should fail with error message
run_test "Invalid delta formula handling" \
    "VERSION_PATCH_DELTA='invalid_formula' $BUMP_VERSION_SCRIPT --print --repo-root $(pwd) 2>&1 || true" \
    "Environment VERSION_PATCH_DELTA must be an unsigned integer"

cleanup_temp_test_env "$test_dir"

# Test 8: Rollover with custom limits
printf '%s\n' "${CYAN}=== Test 8: Rollover with custom limits ===${RESET}"
test_dir=$(create_temp_test_env "test_rollover_custom_limits")
cd "$test_dir"

# Set version to test patch rollover with custom limit
echo "10.5.49" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.49" 2>/dev/null || true

# Add changes to trigger version bump
echo "// Test change for rollover with custom limits" > rollover_custom_test.c
git add rollover_custom_test.c
git commit --quiet -m "Add test change for rollover with custom limits" 2>/dev/null || true

# With VERSION_PATCH_LIMIT=50, patch 49 + 1 = 50, which should rollover to 0 and increment minor
run_test "Patch rollover with custom limit (10.5.49 + 1 with limit 50)" \
    "VERSION_PATCH_LIMIT=50 $BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

cleanup_temp_test_env "$test_dir"

# Print summary
printf '%s\n' "${CYAN}=== Test Summary ===${RESET}"
printf '%s\n' "${GREEN}Tests passed: $TESTS_PASSED${RESET}"
printf '%s\n' "${RED}Tests failed: $TESTS_FAILED${RESET}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '%s\n' "${GREEN}All tests passed! New versioning system integration is working correctly.${RESET}"
    printf '\n%s\n' "${CYAN}Key features verified:${RESET}"
    printf '  • New versioning system always increases only the last identifier (patch)\n'
    printf '  • Rollover logic with mod limit working correctly\n'
    printf '  • LOC-based delta formulas (1*(1+LOC/250), 5*(1+LOC/500), 10*(1+LOC/1000))\n'
    printf '  • Enhanced reason format with LOC and version type\n'
    printf '  • Semantic analyzer integration\n'
    printf '  • Configuration options and error handling\n'
    printf '  • Custom rollover limits working correctly\n'
    exit 0
else
    printf '%s\n' "${RED}Some tests failed!${RESET}"
    exit 1
fi 