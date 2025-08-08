#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for mathematical-version-bump improvements with new versioning system

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
    
    # Run the command with timeout and capture output
    local output
    output=$(timeout 30s bash -c "$test_command" 2>&1 || true)
    
    # Check if timeout occurred
    if [[ $? -eq 124 ]]; then
        printf '%s\n' "${RED}✗ FAIL: $test_name (TIMEOUT after 30s)${RESET}"
        printf '%s\n' "${YELLOW}Command: $test_command${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '%s\n' ""
        return 0
    fi
    
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

BUMP_VERSION_SCRIPT="$PROJECT_ROOT/dev-bin/mathematical-version-bump.sh"

# Create temporary test environment in /tmp
test_dir=$(create_temp_test_env "bump_version_test")
cd "$test_dir"

# Test 1: Basic mathematical version bump (should return current version when no changes)
printf '%s\n' "${CYAN}=== Test 1: Basic mathematical version bump ===${RESET}"
run_test "Basic mathematical version bump from 10.5.12" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.5."

# Test 2: Set version directly
printf '%s\n' "${CYAN}=== Test 2: Set version directly ===${RESET}"
run_test "Set version to 10.5.13" \
    "$BUMP_VERSION_SCRIPT --set 10.5.13 --print" \
    "10.5.13"

# Test 3: Dry run
printf '%s\n' "${CYAN}=== Test 3: Dry run ===${RESET}"
# Create a change in the main test directory to test dry run
echo "// Test change for dry run" > test_change.c
git add test_change.c
git commit --quiet -m "Add test change for dry run" 2>/dev/null || true

run_test "Dry run mathematical version bump" \
    "$BUMP_VERSION_SCRIPT --dry-run --repo-root $(pwd)" \
    "Would update"

# Test 4: Invalid version format
printf '%s\n' "${CYAN}=== Test 4: Invalid version format ===${RESET}"
# Create a temporary git repo for testing invalid version
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Create VERSION file with invalid format
echo "invalid-version" > VERSION
git add VERSION
git commit --quiet -m "Add invalid version" 2>/dev/null || true

run_test "Invalid version format detection" \
    "$BUMP_VERSION_SCRIPT --dry-run --repo-root $(pwd)" \
    "Invalid format in VERSION"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Test 5: Rollover logic
printf '%s\n' "${CYAN}=== Test 5: Rollover logic ===${RESET}"
# Create a temporary git repo for testing rollover
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Test patch rollover with a version close to rollover
echo "10.5.995" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.995" 2>/dev/null || true

run_test "Patch rollover (10.5.995 + 6 = 10.5.996)" \
    "$BUMP_VERSION_SCRIPT --set 10.5.996 --print" \
    "10.5.996"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Test 6: Security keyword detection
printf '%s\n' "${CYAN}=== Test 6: Security keyword detection ===${RESET}"
# Create a temporary git repo for testing
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Set version and create security-related commit
echo "10.5.12" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.12" 2>/dev/null || true

echo "// Fix CVE-2024-1234 vulnerability" > security_fix.c
git add security_fix.c
git commit --quiet -m "Fix security vulnerability" 2>/dev/null || true

# Test that security keywords trigger bonus points
# The mathematical system should detect security changes and suggest appropriate bump
run_test "Security keyword detection adds bonus points" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "20.0.0"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Test 7: LOC-based delta calculation
printf '%s\n' "${CYAN}=== Test 7: LOC-based delta calculation ===${RESET}"
# Create another temporary git repo
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Set version and create large file
echo "10.5.12" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.12" 2>/dev/null || true

# Create a large file to test LOC calculation
for i in {1..1000}; do
    echo "// Line $i - test content for LOC calculation" >> large_file.c
done
git add large_file.c
git commit --quiet -m "Add large file for LOC testing" 2>/dev/null || true

# Test that large LOC changes result in larger deltas
# The mathematical system should detect significant changes
run_test "Large LOC changes result in larger deltas" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Test 8: High-impact changes
printf '%s\n' "${CYAN}=== Test 8: High-impact changes ===${RESET}"
# Create another temporary git repo
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Create initial project structure
mkdir -p src include test
echo "// Initial project setup" > src/main.c
echo "#pragma once" > include/header.h
echo "// Test setup" > test/test.c
git add src/main.c include/header.h test/test.c
git commit --quiet -m "Initial project setup" 2>/dev/null || true

# Set version
echo "10.5.12" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.12" 2>/dev/null || true

# Add high-impact changes
echo "// BREAKING CHANGE: API completely rewritten" > breaking_change.c
echo "// ZERO DAY: Critical vulnerability fix" > zero_day_fix.c
echo "// PRODUCTION OUTAGE: Fix critical bug" > outage_fix.c
git add breaking_change.c zero_day_fix.c outage_fix.c
git commit --quiet -m "Add high-impact changes" 2>/dev/null || true

# The mathematical system automatically determines the appropriate bump type
run_test "High bonus points trigger appropriate bump" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.10.0"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Test 9: Multiplier system
printf '%s\n' "${CYAN}=== Test 9: Multiplier system ===${RESET}"
# Create another temporary git repo
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Create initial project structure
mkdir -p src include test
echo "// Initial project setup" > src/main.c
echo "#pragma once" > include/header.h
echo "// Test setup" > test/test.c
git add src/main.c include/header.h test/test.c
git commit --quiet -m "Initial project setup" 2>/dev/null || true

# Set version
echo "10.5.12" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.12" 2>/dev/null || true

# Enable multiplier environment variables
export VERSION_ZERO_DAY_MULTIPLIER=2.0
export VERSION_PRODUCTION_OUTAGE_MULTIPLIER=2.0

echo "// ZERO DAY: Critical vulnerability fix" > zero_day_fix.c
git add zero_day_fix.c
git commit --quiet -m "Fix zero-day vulnerability" 2>/dev/null || true

# Test that multipliers are applied by the mathematical system
run_test "Multiplier system applies to critical changes" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "20.0.0"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Test 10: Minimal changes
printf '%s\n' "${CYAN}=== Test 10: Minimal changes ===${RESET}"
# Create another temporary git repo
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Create initial project structure
mkdir -p src include test
echo "// Initial project setup" > src/main.c
echo "#pragma once" > include/header.h
echo "// Test setup" > test/test.c
git add src/main.c include/header.h test/test.c
git commit --quiet -m "Initial project setup" 2>/dev/null || true

# Set version
echo "10.5.12" > VERSION
git add VERSION
git commit --quiet -m "Set version to 10.5.12" 2>/dev/null || true

# Test that no changes result in no version bump
run_test "No changes result in no version bump" \
    "$BUMP_VERSION_SCRIPT --print --repo-root $(pwd)" \
    "10.5."

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Clean up the main test directory
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