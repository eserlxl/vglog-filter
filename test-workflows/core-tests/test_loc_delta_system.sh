#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for LOC-based delta system with new versioning system

set -uo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

echo "=== Testing LOC-based Delta System with New Versioning System ==="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

echo "Test 1: Verify LOC delta system is working"
export VERSION_USE_LOC_DELTA=true

# Simple test: just check if the command runs and produces output
output=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null || echo "FAILED")
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

# Test patch rollover
echo "1.2.99" > VERSION
result_rollover=$(VERSION_USE_LOC_DELTA=true ./dev-bin/bump-version patch --dry-run 2>/dev/null | tail -1)
echo "  Patch rollover test: 1.2.99 -> $result_rollover"

if [[ "$result_rollover" =~ ^1\.3\.[0-9]+$ ]]; then
    echo "✓ PASS: Patch rollover working correctly"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Patch rollover not working: $result_rollover"
    ((TESTS_FAILED++))
fi

# Restore original version
echo "10.5.0" > VERSION

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo "✓ All tests passed! LOC delta system is working correctly."
    exit 0
else
    echo "✗ Some tests failed. Please check the implementation."
    exit 1
fi 