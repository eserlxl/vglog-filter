#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive test script for LOC-based delta system
# Tests all aspects: base deltas, bonuses, rollovers, configuration

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=test_helper.sh
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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
# shellcheck disable=SC2329,SC2317
extract_json_value() {
    local key="$1"
    grep -A 10 '"loc_delta"' | grep -o "\"$key\":[[:space:]]*[0-9]*" | cut -d: -f2 | tr -d ' ' || echo "0"
}

# Function to create a simple test environment
# shellcheck disable=SC2317
create_simple_test_env() {
    local test_name="$1"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Initialize git repository
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    echo "$temp_dir"
}

SEMANTIC_ANALYZER_SCRIPT="$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh"

# Test 1: Basic LOC delta functionality
printf '%s\n' "${CYAN}=== Test 1: Basic LOC delta functionality ===${NC}"
test_dir=$(create_simple_test_env "loc_delta_basic")
cd "$test_dir"

# Create initial commit with a source file
mkdir -p src
echo "// Initial source file" > src/main.c
echo "1.0.0" > VERSION
git add src/main.c VERSION
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Create a tag for the initial state
git tag "v1.0.0" 2>/dev/null || true

# Create small change (1 line addition)
echo "// Small change" > src/small_change.c
git add src/small_change.c
git commit --quiet -m "Small change" 2>/dev/null || true

# Test small change deltas (new system: base + bonus for new source file)
# Base deltas: patch=6, minor=10, major=15 (includes LOC scaling)
# Bonus: 5 points total (new source file + manual CLI changes + other bonuses)
run_test "Small change patch delta" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0 | extract_json_value \"patch_delta\"" \
    "6"

run_test "Small change minor delta" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0 | extract_json_value \"minor_delta\"" \
    "10"

run_test "Small change major delta" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0 | extract_json_value \"major_delta\"" \
    "15"

cleanup_temp_test_env "$test_dir"

# Test 2: Breaking change bonuses
printf '%s\n' "${CYAN}=== Test 2: Breaking change bonuses ===${NC}"
test_dir=$(create_simple_test_env "breaking_changes")
cd "$test_dir"

# Create initial commit
mkdir -p src
echo "// Initial source file" > src/main.c
echo "1.0.0" > VERSION
git add src/main.c VERSION
git commit --quiet -m "Add initial source file" 2>/dev/null || true
git tag "v1.0.0" 2>/dev/null || true

# Test breaking CLI changes (CLI breaking = 4 bonus points)
echo "// CLI-BREAKING: This is a breaking CLI change" > src/cli_breaking.c
git add src/cli_breaking.c
git commit --quiet -m "Add breaking CLI change" 2>/dev/null || true

run_test "Breaking CLI bonus" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0 | extract_json_value \"patch_delta\"" \
    "15"  # Base (6) + CLI breaking (4) + new source (1) + manual CLI (2) + other bonuses = 15

# Test API breaking changes (API breaking = 5 bonus points)
echo "// API-BREAKING: This is a breaking change" > src/api_breaking.c
git add src/api_breaking.c
git commit --quiet -m "Add API breaking change" 2>/dev/null || true

run_test "API breaking bonus" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0 | extract_json_value \"patch_delta\"" \
    "20"  # Base (6) + API breaking (5) + new sources (2) + manual CLI (4) + other bonuses = 20

cleanup_temp_test_env "$test_dir"

# Test 3: Security fix bonuses
printf '%s\n' "${CYAN}=== Test 3: Security fix bonuses ===${NC}"
test_dir=$(create_simple_test_env "security_fixes")
cd "$test_dir"

# Create initial commit
mkdir -p src
echo "// Initial source file" > src/main.c
echo "1.0.0" > VERSION
git add src/main.c VERSION
git commit --quiet -m "Add initial source file" 2>/dev/null || true
git tag "v1.0.0" 2>/dev/null || true

# Test security keywords (security_vuln = 5 bonus points each)
echo "// SECURITY: Fix buffer overflow vulnerability" > src/security1.c
echo "// SECURITY: Fix memory leak" > src/security2.c
git add src/security1.c src/security2.c
git commit --quiet -m "Fix security vulnerabilities" 2>/dev/null || true

run_test "Security keywords bonus" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0 | extract_json_value \"patch_delta\"" \
    "21"  # Base (6) + security (10) + new sources (2) + manual CLI (4) + other bonuses = 21

cleanup_temp_test_env "$test_dir"

# Test 4: System behavior
printf '%s\n' "${CYAN}=== Test 4: System behavior ===${NC}"

# Create a simple test environment for system behavior test
test_dir=$(create_simple_test_env "system_behavior")
cd "$test_dir"

# Create initial commit
mkdir -p src
echo "// Initial source file" > src/main.c
echo "1.0.0" > VERSION
git add src/main.c VERSION
git commit --quiet -m "Add initial source file" 2>/dev/null || true
git tag "v1.0.0" 2>/dev/null || true

# Create a simple change
echo "// Test change" > src/test.c
git add src/test.c
git commit --quiet -m "Add test change" 2>/dev/null || true

# Should always include loc_delta in JSON
run_test "System always includes loc_delta" \
    "$SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd) --since v1.0.0" \
    "loc_delta"

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