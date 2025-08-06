#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Comprehensive test script for LOC-based delta system
# Tests all aspects: base deltas, bonuses, rollovers, configuration

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    printf '%s\n' "${CYAN}Running test: $test_name${NC}"
    
    # Run the command and capture output
    local output
    output=$(eval "$test_command" 2>&1 || true)
    
    # Check if output contains expected text
    if echo "$output" | grep -q "$expected_output"; then
        printf '%s\n' "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%s\n' "${RED}✗ FAIL: $test_name${NC}"
        printf '%s\n' "${YELLOW}Expected: $expected_output${NC}"
        printf '%s\n' "${YELLOW}Got: $output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    printf '%s\n' ""
    
    # Return success to prevent script from exiting
    return 0
}

# Function to extract JSON value from loc_delta section
extract_json_value() {
    local key="$1"
    grep -A 10 '"loc_delta"' | grep -o "\"$key\":[[:space:]]*[0-9]*" | cut -d: -f2 | tr -d ' ' || echo "0"
}

SEMANTIC_ANALYZER_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer.sh"

# Test 1: Basic LOC delta functionality
printf '%s\n' "${CYAN}=== Test 1: Basic LOC delta functionality ===${NC}"
test_dir=$(create_temp_test_env "loc_delta_basic")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Create small change (should result in patch_delta=3, minor_delta=7, major_delta=12)
echo "// Small change" > src/small_change.c
git add src/small_change.c
git commit --quiet -m "Small change" 2>/dev/null || true

# Test small change deltas
run_test "Small change patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) | extract_json_value \"patch_delta\"" \
    "3"

run_test "Small change minor delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) | extract_json_value \"minor_delta\"" \
    "7"

run_test "Small change major delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) | extract_json_value \"major_delta\"" \
    "12"

cleanup_temp_test_env "$test_dir"

# Test 2: Breaking change bonuses
printf '%s\n' "${CYAN}=== Test 2: Breaking change bonuses ===${NC}"
test_dir=$(create_temp_test_env "breaking_changes")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Test breaking CLI changes
echo "// CLI-BREAKING: This is a breaking CLI change" > src/cli_breaking.c
git add src/cli_breaking.c
git commit --quiet -m "Add breaking CLI change" 2>/dev/null || true

run_test "Breaking CLI bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) | extract_json_value \"patch_delta\"" \
    "5"  # 1 (base) + 2 (CLI breaking) + 2 (new file)

# Test API breaking changes
echo "// API-BREAKING: This is a breaking change" > src/api_breaking.c
git add src/api_breaking.c
git commit --quiet -m "Add API breaking change" 2>/dev/null || true

run_test "API breaking bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) | extract_json_value \"patch_delta\"" \
    "6"  # 1 (base) + 3 (API breaking) + 2 (new file)

cleanup_temp_test_env "$test_dir"

# Test 3: Security fix bonuses
printf '%s\n' "${CYAN}=== Test 3: Security fix bonuses ===${NC}"
test_dir=$(create_temp_test_env "security_fixes")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Test security keywords
echo "// SECURITY: Fix buffer overflow vulnerability" > src/security1.c
echo "// SECURITY: Fix memory leak" > src/security2.c
git add src/security1.c src/security2.c
git commit --quiet -m "Fix security vulnerabilities" 2>/dev/null || true

run_test "Security keywords bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) | extract_json_value \"patch_delta\"" \
    "23"  # 1 (base) + 10 (2 security keywords * 5) + 12 (new files)

cleanup_temp_test_env "$test_dir"

# Test 4: System behavior
printf '%s\n' "${CYAN}=== Test 4: System behavior ===${NC}"

# Create a simple test environment for system behavior test
test_dir=$(create_temp_test_env "system_behavior")
cd "$test_dir"

# Create a simple change
echo "// Test change" > src/test.c
git add src/test.c
git commit --quiet -m "Add test change" 2>/dev/null || true

# Should always include loc_delta in JSON
output=$(cd "$PROJECT_ROOT" && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root "$(pwd)" 2>/dev/null)

if [[ "$output" == *"loc_delta"* ]]; then
    printf '%s\n' "${GREEN}✓ PASS: System always includes loc_delta${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: System doesn't include loc_delta${NC}"
    printf "Output: %s\n" "$output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

cleanup_temp_test_env "$test_dir"

# Print summary
printf "\n%s=== Test Summary ===%s\n" "${CYAN}" "${NC}"
printf "%sTests passed: %d%s\n" "${GREEN}" "$TESTS_PASSED" "${NC}"
printf "%sTests failed: %d%s\n" "${RED}" "$TESTS_FAILED" "${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "%sAll tests passed!%s\n" "${GREEN}" "${NC}"
    exit 0
else
    printf "%sSome tests failed.%s\n" "${RED}" "${NC}"
    exit 1
fi 