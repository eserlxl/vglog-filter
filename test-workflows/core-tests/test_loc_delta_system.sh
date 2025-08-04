#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for LOC-based delta system with new versioning system

set -Euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Create a temporary clean environment for testing
TEMP_DIR=$(mktemp -d)
# Copy everything except .git directory
find "$PROJECT_ROOT" -maxdepth 1 -not -name . -not -name .git -exec cp -r {} "$TEMP_DIR/" \;
cd "$TEMP_DIR" || exit 1

# Initialize git in the temp directory
git init
git config user.name "Test User"
git config user.email "test@example.com"

echo "=== Testing LOC-based Delta System with New Versioning System ==="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
# shellcheck disable=SC2317
run_test() {
    local test_name="$1"
    local expected_patch="$2"
    local expected_minor="$3"
    local expected_major="$4"
    
    echo "Test: $test_name"
    
    # Run semantic analyzer
    local result
    result=$(./dev-bin/semantic-version-analyzer --json 2>/dev/null || echo "{}")
    
    # Extract deltas
    local patch_delta
    patch_delta=$(echo "$result" | grep -o '"patch_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
    local minor_delta
    minor_delta=$(echo "$result" | grep -o '"minor_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
    local major_delta
    major_delta=$(echo "$result" | grep -o '"major_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
    
    # Extract reason
    local reason
    reason=$(echo "$result" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    # Check results
    if [[ "$patch_delta" = "$expected_patch" ]] && [[ "$minor_delta" = "$expected_minor" ]] && [[ "$major_delta" = "$expected_major" ]]; then
        echo "✓ PASS: Deltas match expected values"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: Expected PATCH=$expected_patch, MINOR=$expected_minor, MAJOR=$expected_major"
        echo "  Got: PATCH=$patch_delta, MINOR=$minor_delta, MAJOR=$major_delta"
        ((TESTS_FAILED++))
    fi
    
    # Check reason format
    if [[ "$reason" = *"LOC:"* ]] && [[ "$reason" = *"MAJOR"* || "$reason" = *"MINOR"* || "$reason" = *"PATCH"* ]]; then
        echo "✓ PASS: Reason format includes LOC and version type"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: Reason format incorrect: $reason"
        ((TESTS_FAILED++))
    fi
    
    echo ""
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

echo "Test 1: Verify LOC delta system is working"

# Set up initial version and commit
echo "1.0.0" > VERSION
git add VERSION
git commit -m "Set initial version" -q

# Add a small change to trigger analysis
echo "test content" >> README.md
git add README.md
git commit -m "Add test change" -q

# Simple test: just check if the command runs and produces output
output=$(./dev-bin/semantic-version-analyzer --json 2>/dev/null || echo "FAILED")
if [[ "$output" != "FAILED" ]] && [[ "$output" = *"loc_delta"* ]]; then
    echo "✓ PASS: LOC delta system is working"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: LOC delta system not working"
    ((TESTS_FAILED++))
fi

# Test 2: Verify enhanced reason format
echo ""
echo "Test 2: Verify enhanced reason format"
reason=$(echo "$output" | jq -r '.reason // ""' 2>/dev/null || echo "")
if [[ "$reason" = *"LOC:"* ]] && [[ "$reason" = *"MAJOR"* || "$reason" = *"MINOR"* || "$reason" = *"PATCH"* ]]; then
    echo "✓ PASS: Enhanced reason format working: $reason"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Enhanced reason format not working: $reason"
    ((TESTS_FAILED++))
fi

# Test 3: Verify rollover logic
echo ""
echo "Test 3: Verify rollover logic"
echo "Testing version calculation with rollover..."

# Set up initial version and commit
echo "1.2.99" > VERSION
git add VERSION
git commit -m "Set version to 1.2.99" -q

# Add a small change to trigger analysis
echo "test content" >> README.md
git add README.md
git commit -m "Add test change" -q

# Test patch rollover
result_rollover=$(./dev-bin/bump-version patch --dry-run 2>/dev/null | tail -1)
echo "  Patch rollover test: 1.2.99 -> $result_rollover"

if [[ "$result_rollover" =~ ^1\.3\.[0-9]+$ ]]; then
    echo "✓ PASS: Patch rollover working correctly"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Patch rollover not working: $result_rollover"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo "✓ All tests passed! LOC delta system is working correctly."
    exit 0
else
    echo "✗ Some tests failed. Please check the implementation."
    exit 1
fi 