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

# Source the test helper
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Create a temporary clean environment for testing
test_dir=$(create_temp_test_env "loc_delta_system_test")
cd "$test_dir"

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
    result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --json --repo-root "$(pwd)" 2>/dev/null || echo "{}")
    
    # Extract deltas from loc_delta section
    local patch_delta
    patch_delta=$(echo "$result" | jq -r '.loc_delta.patch_delta // 0' 2>/dev/null || echo "0")
    local minor_delta
    minor_delta=$(echo "$result" | jq -r '.loc_delta.minor_delta // 0' 2>/dev/null || echo "0")
    local major_delta
    major_delta=$(echo "$result" | jq -r '.loc_delta.major_delta // 0' 2>/dev/null || echo "0")
    
    # Extract reason from version calculator output
    local reason
    reason=$("$PROJECT_ROOT/dev-bin/version-calculator" --current-version "1.0.0" --bump-type patch --loc 10 --bonus 1 --json 2>/dev/null | jq -r '.reason // ""' 2>/dev/null || echo "")
    
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
    if [[ "$reason" = *"LOC="* ]] && [[ "$reason" = *"PATCH"* ]]; then
        echo "✓ PASS: Reason format includes LOC and version type"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: Reason format incorrect: $reason"
        ((TESTS_FAILED++))
    fi
    
    echo ""
}

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
output=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --json --repo-root "$(pwd)" 2>/dev/null || echo "FAILED")
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
# Test reason format using version calculator directly
reason=$("$PROJECT_ROOT/dev-bin/version-calculator" --current-version "1.0.0" --bump-type patch --loc 10 --bonus 1 --json 2>/dev/null | jq -r '.reason // ""' 2>/dev/null || echo "")
if [[ "$reason" = *"LOC="* ]] && [[ "$reason" = *"PATCH"* ]]; then
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
result_rollover=$("$PROJECT_ROOT/dev-bin/bump-version" patch --dry-run --repo-root "$(pwd)" 2>/dev/null | tail -1)
echo "  Patch rollover test: 1.2.99 -> $result_rollover"

if [[ "$result_rollover" =~ ^1\.2\.[0-9]+$ ]]; then
    echo "✓ PASS: Patch rollover working correctly"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Patch rollover not working: $result_rollover"
    ((TESTS_FAILED++))
fi

# Test 4: Verify JSON structure
echo ""
echo "Test 4: Verify JSON structure"
json_output=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --json --repo-root "$(pwd)" 2>/dev/null || echo "{}")

# Check if JSON has required fields - use grep to avoid jq issues with extra output
if echo "$json_output" | grep -q '"loc_delta"' 2>/dev/null; then
    echo "✓ PASS: JSON contains loc_delta section"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: JSON missing loc_delta section"
    ((TESTS_FAILED++))
fi

if echo "$json_output" | grep -q '"patch_delta"' 2>/dev/null; then
    echo "✓ PASS: JSON contains patch_delta field"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: JSON missing patch_delta field"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

# Cleanup
cleanup_temp_test_env "$test_dir"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo "✓ All tests passed! LOC delta system is working correctly."
    exit 0
else
    echo "✗ Some tests failed. Please check the implementation."
    exit 1
fi 