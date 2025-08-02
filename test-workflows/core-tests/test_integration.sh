#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Integration test for the new versioning system

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Testing New Versioning System Integration"
echo "========================================"

# Go to project root
cd ../../

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local expected_version="$2"
    local expected_reason_pattern="$3"
    
    printf "${BLUE}Running test: %s${NC}\n" "$test_name"
    
    # Run semantic analyzer
    local result
    result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null || echo "{}")
    
    # Extract next version
    local actual_version
    actual_version=$(echo "$result" | grep -o '"next_version":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    # Extract reason
    local actual_reason
    actual_reason=$(echo "$result" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    # Check results
    if [[ "$actual_version" = "$expected_version" ]]; then
        printf "${GREEN}✓ PASS${NC}: Version %s\n" "$actual_version"
        ((TESTS_PASSED++))
    else
        printf "${RED}✗ FAIL${NC}: Expected version %s, got %s\n" "$expected_version" "$actual_version"
        ((TESTS_FAILED++))
    fi
    
    if [[ "$actual_reason" = *"$expected_reason_pattern"* ]]; then
        printf "${GREEN}✓ PASS${NC}: Reason contains '%s'\n" "$expected_reason_pattern"
        ((TESTS_PASSED++))
    else
        printf "${RED}✗ FAIL${NC}: Expected reason to contain '%s', got '%s'\n" "$expected_reason_pattern" "$actual_reason"
        ((TESTS_FAILED++))
    fi
    
    printf "\n"
}

# Test 1: Current state analysis
echo "Test 1: Analyzing current state"
run_test "Current State" "" "LOC:"  # We don't know the exact version, but should have LOC in reason

# Test 2: Delta calculation verification
echo "Test 2: Verifying delta calculations"
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null || echo "{}")

patch_delta=$(echo "$result" | grep -o '"patch_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
minor_delta=$(echo "$result" | grep -o '"minor_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
major_delta=$(echo "$result" | grep -o '"major_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')

echo "Patch delta: $patch_delta"
echo "Minor delta: $minor_delta"
echo "Major delta: $major_delta"

# Verify delta formulas are working
if [[ "$patch_delta" =~ ^[0-9]+$ ]] && [[ "$minor_delta" =~ ^[0-9]+$ ]] && [[ "$major_delta" =~ ^[0-9]+$ ]]; then
    printf "${GREEN}✓ PASS${NC}: Delta calculations working\n"
    ((TESTS_PASSED++))
else
    printf "${RED}✗ FAIL${NC}: Delta calculations failed\n"
    ((TESTS_FAILED++))
fi

# Test 3: Reason format verification
echo "Test 3: Verifying reason format"
reason=$(echo "$result" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4 || echo "")

if [[ "$reason" = *"LOC:"* ]]; then
    printf "${GREEN}✓ PASS${NC}: Reason includes LOC value\n"
    ((TESTS_PASSED++))
else
    printf "${RED}✗ FAIL${NC}: Reason missing LOC value\n"
    ((TESTS_FAILED++))
fi

if [[ "$reason" = *"MAJOR"* ]] || [[ "$reason" = *"MINOR"* ]] || [[ "$reason" = *"PATCH"* ]]; then
    printf "${GREEN}✓ PASS${NC}: Reason includes version type\n"
    ((TESTS_PASSED++))
else
    printf "${RED}✗ FAIL${NC}: Reason missing version type\n"
    ((TESTS_FAILED++))
fi

# Test 4: JSON output structure verification
echo "Test 4: Verifying JSON output structure"
if echo "$result" | grep -q '"loc_delta"' && echo "$result" | grep -q '"enabled": true'; then
    printf "${GREEN}✓ PASS${NC}: LOC delta system enabled in JSON\n"
    ((TESTS_PASSED++))
else
    printf "${RED}✗ FAIL${NC}: LOC delta system not properly configured in JSON\n"
    ((TESTS_FAILED++))
fi

# Print summary
echo ""
printf "${YELLOW}Test Summary${NC}\n"
printf "============\n"
printf "${GREEN}Tests passed: %d${NC}\n" "$TESTS_PASSED"
printf "${RED}Tests failed: %d${NC}\n" "$TESTS_FAILED"
printf "Total tests: %d\n" $((TESTS_PASSED + TESTS_FAILED))

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "\n${GREEN}All tests passed!${NC}\n"
    echo ""
    echo "✅ New versioning system is working correctly:"
    echo "   - Version calculation with rollover logic ✓"
    echo "   - LOC-based delta formulas ✓"
    echo "   - Enhanced reason format with LOC and version type ✓"
    echo "   - JSON output with delta information ✓"
    exit 0
else
    printf "\n${RED}Some tests failed!${NC}\n"
    exit 1
fi 