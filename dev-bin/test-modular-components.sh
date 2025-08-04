#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for modular semantic version analyzer components

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit="$3"
    
    printf '%bRunning test: %s%b\n' "$BLUE" "$test_name" "$NC"
    printf 'Command: %s\n' "$command"
    
    if eval "$command" >/dev/null 2>&1; then
        local exit_code=$?
        if [[ "$exit_code" -eq "$expected_exit" ]]; then
            printf '%b✓ PASS%b\n' "$GREEN" "$NC"
            ((TESTS_PASSED++))
        else
            printf '%b✗ FAIL - Expected exit %d, got %d%b\n' "$RED" "$expected_exit" "$exit_code" "$NC"
            ((TESTS_FAILED++))
        fi
    else
        local exit_code=$?
        if [[ "$exit_code" -eq "$expected_exit" ]]; then
            printf '%b✓ PASS%b\n' "$GREEN" "$NC"
            ((TESTS_PASSED++))
        else
            printf '%b✗ FAIL - Expected exit %d, got %d%b\n' "$RED" "$expected_exit" "$exit_code" "$NC"
            ((TESTS_FAILED++))
        fi
    fi
    printf '\n'
}

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%bError: Not in a git repository. Please run this script from a git repository.%b\n' "$RED" "$NC"
    exit 1
fi

# Get the last commit for testing
LAST_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "HEAD")
PARENT_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "$LAST_COMMIT")

printf '%bTesting Modular Semantic Version Analyzer Components%b\n' "$YELLOW" "$NC"
printf 'Last commit: %s\n' "$LAST_COMMIT"
printf 'Parent commit: %s\n' "$PARENT_COMMIT"
printf '\n'

# Test 1: Check if all required binaries exist
printf '%b=== Testing Binary Availability ===%b\n' "$BLUE" "$NC"
run_test "ref-resolver exists" "test -x ./dev-bin/ref-resolver" 0
run_test "version-config-loader exists" "test -x ./dev-bin/version-config-loader" 0
run_test "file-change-analyzer exists" "test -x ./dev-bin/file-change-analyzer" 0
run_test "cli-options-analyzer exists" "test -x ./dev-bin/cli-options-analyzer" 0
run_test "security-keyword-analyzer exists" "test -x ./dev-bin/security-keyword-analyzer" 0
run_test "version-calculator exists" "test -x ./dev-bin/version-calculator" 0
run_test "semantic-version-analyzer-v2 exists" "test -x ./dev-bin/semantic-version-analyzer-v2" 0

# Test 2: Test help functionality
printf '%b=== Testing Help Functionality ===%b\n' "$BLUE" "$NC"
run_test "ref-resolver help" "./dev-bin/ref-resolver --help" 0
run_test "version-config-loader help" "./dev-bin/version-config-loader --help" 0
run_test "file-change-analyzer help" "./dev-bin/file-change-analyzer --help" 0
run_test "cli-options-analyzer help" "./dev-bin/cli-options-analyzer --help" 0
run_test "security-keyword-analyzer help" "./dev-bin/security-keyword-analyzer --help" 0
run_test "version-calculator help" "./dev-bin/version-calculator --help" 0
run_test "semantic-version-analyzer-v2 help" "./dev-bin/semantic-version-analyzer-v2 --help" 0

# Test 3: Test configuration loading
printf '%b=== Testing Configuration Loading ===%b\n' "$BLUE" "$NC"
run_test "version-config-loader validate" "./dev-bin/version-config-loader --validate-only" 0
run_test "version-config-loader machine output" "./dev-bin/version-config-loader --machine" 0

# Test 4: Test reference resolution
printf '%b=== Testing Reference Resolution ===%b\n' "$BLUE" "$NC"
run_test "ref-resolver print base" "./dev-bin/ref-resolver --base HEAD~1 --target HEAD --print-base" 0
run_test "ref-resolver machine output" "./dev-bin/ref-resolver --base HEAD~1 --target HEAD --machine" 0

# Test 5: Test file change analysis
printf '%b=== Testing File Change Analysis ===%b\n' "$BLUE" "$NC"
run_test "file-change-analyzer basic" "./dev-bin/file-change-analyzer --base HEAD~1 --target HEAD" 0
run_test "file-change-analyzer machine output" "./dev-bin/file-change-analyzer --base HEAD~1 --target HEAD --machine" 0

# Test 6: Test CLI options analysis
printf '%b=== Testing CLI Options Analysis ===%b\n' "$BLUE" "$NC"
run_test "cli-options-analyzer basic" "./dev-bin/cli-options-analyzer --base HEAD~1 --target HEAD" 0
run_test "cli-options-analyzer machine output" "./dev-bin/cli-options-analyzer --base HEAD~1 --target HEAD --machine" 0

# Test 7: Test security keyword analysis
printf '%b=== Testing Security Keyword Analysis ===%b\n' "$BLUE" "$NC"
run_test "security-keyword-analyzer basic" "./dev-bin/security-keyword-analyzer --base HEAD~1 --target HEAD" 0
run_test "security-keyword-analyzer machine output" "./dev-bin/security-keyword-analyzer --base HEAD~1 --target HEAD --machine" 0

# Test 8: Test version calculation
printf '%b=== Testing Version Calculation ===%b\n' "$BLUE" "$NC"
run_test "version-calculator basic" "./dev-bin/version-calculator --current-version 1.2.3 --bump-type minor --loc 500" 0
run_test "version-calculator machine output" "./dev-bin/version-calculator --current-version 1.2.3 --bump-type minor --loc 500 --machine" 0

# Test 9: Test orchestrator
printf '%b=== Testing Orchestrator ===%b\n' "$BLUE" "$NC"
run_test "semantic-version-analyzer-v2 basic" "./dev-bin/semantic-version-analyzer-v2 --base HEAD~1 --target HEAD" 0
run_test "semantic-version-analyzer-v2 suggest-only" "./dev-bin/semantic-version-analyzer-v2 --base HEAD~1 --target HEAD --suggest-only" 0

# Test 10: Test error handling
printf '%b=== Testing Error Handling ===%b\n' "$BLUE" "$NC"
run_test "invalid base reference" "./dev-bin/ref-resolver --base INVALID_REF --target HEAD" 1
run_test "missing required argument" "./dev-bin/file-change-analyzer" 1
run_test "invalid bump type" "./dev-bin/version-calculator --current-version 1.2.3 --bump-type invalid" 1

# Summary
printf '%b=== Test Summary ===%b\n' "$YELLOW" "$NC"
printf 'Tests passed: %b%d%b\n' "$GREEN" "$TESTS_PASSED" "$NC"
printf 'Tests failed: %b%d%b\n' "$RED" "$TESTS_FAILED" "$NC"
printf 'Total tests: %d\n' $((TESTS_PASSED + TESTS_FAILED))

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    printf '%bAll tests passed! Modular components are working correctly.%b\n' "$GREEN" "$NC"
    exit 0
else
    printf '%bSome tests failed. Please check the output above.%b\n' "$RED" "$NC"
    exit 1
fi 