#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for ERE fix and other improvements in semantic-version-analyzer

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

# Source test helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="$3"
    local expected_output="$4"
    
    printf '%sRunning: %s%s\n' "${YELLOW}" "$test_name" "${NC}"
    
    # Run the test command
    local output
    output=$(eval "$test_cmd" 2>&1)
    local exit_code=$?
    
    # Check exit code
    if [[ $exit_code -eq $expected_exit ]]; then
        printf '%s✓ Exit code correct (%d)%s\n' "${GREEN}" "$exit_code" "${NC}"
    else
        printf '%s✗ Exit code wrong: got %d, expected %d%s\n' "${RED}" "$exit_code" "$expected_exit" "${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Check output if specified
    if [[ -n "$expected_output" ]]; then
        if echo "$output" | grep -q "$expected_output"; then
            printf '%s✓ Output contains expected text%s\n' "${GREEN}" "${NC}"
        else
            printf '%s✗ Output missing expected text: %s%s\n' "${RED}" "$expected_output" "${NC}"
            printf 'Actual output:\n%s\n' "$output"
            ((TESTS_FAILED++))
            return 1
        fi
    fi
    
    ((TESTS_PASSED++))
    printf '%s✓ Test passed%s\n\n' "${GREEN}" "${NC}"
    return 0
}

# Create temporary test environment
temp_dir=$(create_temp_test_env "ere-fix")
cd "$temp_dir"

# Test 1: ERE fix - manual CLI detection should work with escaped +
printf '%s=== Test 1: ERE Fix for Manual CLI Detection ===%s\n' "${YELLOW}" "${NC}"

# Create a test file with manual CLI parsing
mkdir -p test-workflows/source-fixtures/cli
{
    generate_license_header "c" "Test fixture for CLI detection testing"
    cat << 'EOF'
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help message\n");
            return 0;
        }
        if (strcmp(argv[i], "--version") == 0) {
            printf("Version 1.0.0\n");
            return 0;
        }
        if (strcmp(argv[i], "--verbose") == 0) {
            printf("Verbose mode\n");
            return 0;
        }
    }
    return 1;
}
EOF
} > test-workflows/source-fixtures/cli/simple_cli_test.c

# Add the file
git add test-workflows/source-fixtures/cli/simple_cli_test.c
git commit -m "Add manual CLI parser test" --no-verify

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Test that manual CLI detection works (should not crash with ERE error)
run_test "Manual CLI detection with escaped +" \
    "cd '$PROJECT_ROOT' && ./dev-bin/semantic-version-analyzer --verbose --base '$first_commit' --target '$second_commit' --repo-root '$temp_dir'" \
    11 \
    "manual_cli_changes=true"

# Test 2: Manual counts should not be added to getopt totals
printf '%s=== Test 2: Manual Counts Separation ===%s\n' "${YELLOW}" "${NC}"

# Create a file with getopt
{
    generate_license_header "c" "Test fixture for getopt CLI detection"
    cat << 'EOF'
#include <stdio.h>
#include <getopt.h>

int main(int argc, char *argv[]) {
    static struct option long_options[] = {
        {"help", no_argument, 0, 'h'},
        {"version", no_argument, 0, 'v'},
        {0, 0, 0, 0}
    };
    
    int c;
    while ((c = getopt_long(argc, argv, "hv", long_options, NULL)) != -1) {
        switch (c) {
            case 'h':
                printf("Help\n");
                break;
            case 'v':
                printf("Version\n");
                break;
        }
    }
    return 0;
}
EOF
} > test_getopt.c

git add test_getopt.c
git commit -m "Add getopt test" --no-verify

# Get the commit hashes
first_commit=$(git rev-parse HEAD~2)
second_commit=$(git rev-parse HEAD)

# Test that getopt and manual counts are separate
run_test "Getopt and manual counts separation" \
    "cd '$PROJECT_ROOT' && ./dev-bin/semantic-version-analyzer --verbose --base '$first_commit' --target '$second_commit' --json --repo-root '$temp_dir'" \
    11 \
    '"manual_added_long_count": 0'

# Test 3: Breaking changes detection
printf '%s=== Test 3: Breaking Changes Detection ===%s\n' "${YELLOW}" "${NC}"

# Remove a long option from getopt
sed -i 's/"version"/"old-option"/' test_getopt.c
git add test_getopt.c
git commit -m "Remove --version option (breaking change)" --no-verify

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

run_test "Breaking CLI change detection" \
    "cd '$PROJECT_ROOT' && ./dev-bin/semantic-version-analyzer --base '$first_commit' --target '$second_commit' --repo-root '$temp_dir'" \
    10 \
    "breaking_cli"

# Test 4: API breaking changes
printf '%s=== Test 4: API Breaking Changes ===%s\n' "${YELLOW}" "${NC}"

# Create header with prototype
mkdir -p include
{
    generate_license_header "h" "Test fixture for API breaking change detection"
    cat << 'EOF'
#ifndef TEST_H
#define TEST_H

int test_function(int param);
void another_function(void);

#endif
EOF
} > include/test.h

git add include/test.h
git commit -m "Add header with prototypes" --no-verify

# Remove a prototype
sed -i '/another_function/d' include/test.h
git add include/test.h
git commit -m "Remove function prototype (API break)" --no-verify

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

run_test "API breaking change detection" \
    "cd '$PROJECT_ROOT' && ./dev-bin/semantic-version-analyzer --base '$first_commit' --target '$second_commit' --repo-root '$temp_dir'" \
    10 \
    "api_break"

# Test 5: Whitespace-only changes with --ignore-whitespace
printf '%s=== Test 5: Whitespace Ignore ===%s\n' "${YELLOW}" "${NC}"

# Add whitespace-only changes
echo "   " >> test-workflows/source-fixtures/cli/simple_cli_test.c
git add test-workflows/source-fixtures/cli/simple_cli_test.c
git commit -m "Add whitespace changes" --no-verify

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

run_test "Whitespace ignore with --ignore-whitespace" \
    "cd '$PROJECT_ROOT' && ./dev-bin/semantic-version-analyzer --ignore-whitespace --base '$first_commit' --target '$second_commit' --repo-root '$temp_dir'" \
    20 \
    "NONE"

# Test 6: Repository without tags fallback
printf '%s=== Test 6: No Tags Fallback ===%s\n' "${YELLOW}" "${NC}"

# Create a temporary repo without tags
TEMP_REPO=$(mktemp -d)
cd "$TEMP_REPO"
git init
echo "test" > test.txt
git add test.txt
git commit -m "Initial commit"
echo "test2" > test2.txt
git add test2.txt
git commit -m "Second commit"

# Copy the analyzer script
cp "$PROJECT_ROOT/dev-bin/semantic-version-analyzer" .

run_test "No tags fallback to HEAD~1" \
    "./semantic-version-analyzer --print-base" \
    0 \
    ""

# Cleanup
cd "$PROJECT_ROOT"
rm -rf "$TEMP_REPO"

# Test 7: MAJOR_REQUIRE_BREAKING environment variable
printf '%s=== Test 7: MAJOR_REQUIRE_BREAKING Environment Variable ===%s\n' "${YELLOW}" "${NC}"

# Test with different truthy values
# Get the commit hashes
first_commit=$(git rev-parse HEAD~3)
second_commit=$(git rev-parse HEAD)

run_test "MAJOR_REQUIRE_BREAKING=true" \
    "cd '$PROJECT_ROOT' && MAJOR_REQUIRE_BREAKING=true ./dev-bin/semantic-version-analyzer --base '$first_commit' --target '$second_commit' --repo-root '$temp_dir'" \
    10 \
    ""

run_test "MAJOR_REQUIRE_BREAKING=1" \
    "cd '$PROJECT_ROOT' && MAJOR_REQUIRE_BREAKING=1 ./dev-bin/semantic-version-analyzer --since HEAD~3 --repo-root '$temp_dir'" \
    10 \
    ""

run_test "MAJOR_REQUIRE_BREAKING=yes" \
    "cd '$PROJECT_ROOT' && MAJOR_REQUIRE_BREAKING=yes ./dev-bin/semantic-version-analyzer --since HEAD~3 --repo-root '$temp_dir'" \
    10 \
    ""

# Test 8: JSON output includes manual fields
printf '%s=== Test 8: JSON Output Fields ===%s\n' "${YELLOW}" "${NC}"

run_test "JSON includes manual CLI fields" \
    "cd '$PROJECT_ROOT' && ./dev-bin/semantic-version-analyzer --verbose --since HEAD~4 --json --repo-root '$temp_dir'" \
    11 \
    '"manual_added_long_count"'

# Cleanup test files
cleanup_temp_test_env "$temp_dir"

# Summary
printf '%s=== Test Summary ===%s\n' "${YELLOW}" "${NC}"
printf '%sTests passed: %d%s\n' "${GREEN}" "$TESTS_PASSED" "${NC}"
printf '%sTests failed: %d%s\n' "${RED}" "$TESTS_FAILED" "${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '%sAll tests passed!%s\n' "${GREEN}" "${NC}"
    exit 0
else
    printf '%sSome tests failed!%s\n' "${RED}" "${NC}"
    exit 1
fi 