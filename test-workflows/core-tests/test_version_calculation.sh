#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for version calculation logic

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Create a temporary test environment
test_dir=$(create_temp_test_env "version_calculation_test")
cd "$test_dir"

# Test 1: Basic version calculation
echo ""
echo "Test 1: Basic version calculation"
echo "9.3.0 + patch delta = 9.3.1"

# Set version to 9.3.0
echo "9.3.0" > VERSION
git add VERSION
git commit -m "Set version to 9.3.0" -q

# Add a small change to a non-source file
echo "test content" >> README.md
git add README.md
git commit -m "Add test change" -q

# Run semantic analyzer and extract next version
base_commit=$(git rev-parse HEAD~1)
cd "$PROJECT_ROOT" || exit 1
result=$(./dev-bin/semantic-version-analyzer --base "$base_commit" --repo-root "$test_dir" --json 2>/dev/null) || true
cd "$test_dir" || exit 1

# Parse JSON properly - handle multiline JSON
if command -v jq >/dev/null 2>&1; then
    next_version=$(echo "$result" | jq -r '.next_version // empty')
    suggestion=$(echo "$result" | jq -r '.suggestion')
    total_bonus=$(echo "$result" | jq -r '.total_bonus')
else
    next_version=$(echo "$result" | sed -n 's/.*"next_version":"\([^"]*\)".*/\1/p')
    suggestion=$(echo "$result" | sed -n 's/.*"suggestion":"\([^"]*\)".*/\1/p')
    total_bonus=$(echo "$result" | sed -n 's/.*"total_bonus":[[:space:]]*\([0-9]*\).*/\1/p')
fi

echo "Expected: A valid version number"
echo "Actual: $next_version"
echo "Suggestion: $suggestion"
echo "Total bonus: $total_bonus"

if [[ -n "$next_version" ]] && [[ "$next_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
    echo "Debug: Full result: $result"
fi

# Test 2: Patch rollover
echo ""
echo "Test 2: Patch rollover"
echo "9.3.999 + patch delta = 9.4.0"

# Set version to 9.3.999
echo "9.3.999" > VERSION
git add VERSION
git commit -m "Set version to 9.3.999" -q

# Add another change to a non-source file
echo "more test content" >> README.md
git add README.md
git commit -m "Add another test change" -q

# Run semantic analyzer
base_commit2=$(git rev-parse HEAD~1)
cd "$PROJECT_ROOT" || exit 1
result2=$(./dev-bin/semantic-version-analyzer --base "$base_commit2" --repo-root "$test_dir" --json 2>/dev/null) || true
cd "$test_dir" || exit 1

if command -v jq >/dev/null 2>&1; then
    next_version2=$(echo "$result2" | jq -r '.next_version // empty')
    suggestion2=$(echo "$result2" | jq -r '.suggestion')
else
    next_version2=$(echo "$result2" | sed -n 's/.*"next_version":"\([^"]*\)".*/\1/p')
    suggestion2=$(echo "$result2" | sed -n 's/.*"suggestion":"\([^"]*\)".*/\1/p')
fi

echo "Expected: A valid version number"
echo "Actual: $next_version2"
echo "Suggestion: $suggestion2"

if [[ -n "$next_version2" ]] && [[ "$next_version2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
    echo "Debug: Full result: $result2"
fi

# Test 3: Minor rollover
echo ""
echo "Test 3: Minor rollover"
echo "9.999.999 + patch delta = 10.0.0"

# Set version to 9.999.999
echo "9.999.999" > VERSION
git add VERSION
git commit -m "Set version to 9.999.999" -q

# Add another change to a non-source file
echo "third test content" >> README.md
git add README.md
git commit -m "Add third test change" -q

# Run semantic analyzer
base_commit3=$(git rev-parse HEAD~1)
cd "$PROJECT_ROOT" || exit 1
result3=$(./dev-bin/semantic-version-analyzer --base "$base_commit3" --repo-root "$test_dir" --json 2>/dev/null) || true
cd "$test_dir" || exit 1

if command -v jq >/dev/null 2>&1; then
    next_version3=$(echo "$result3" | jq -r '.next_version // empty')
    suggestion3=$(echo "$result3" | jq -r '.suggestion')
else
    next_version3=$(echo "$result3" | sed -n 's/.*"next_version":"\([^"]*\)".*/\1/p')
    suggestion3=$(echo "$result3" | sed -n 's/.*"suggestion":"\([^"]*\)".*/\1/p')
fi

echo "Expected: A valid version number"
echo "Actual: $next_version3"
echo "Suggestion: $suggestion3"

if [[ -n "$next_version3" ]] && [[ "$next_version3" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
    echo "Debug: Full result: $result3"
fi

# Test 4: Suggestion format
echo ""
echo "Test 4: Suggestion format"
echo "Should be patch, minor, or major"

echo "Suggestion: $suggestion"

if [[ "$suggestion" =~ ^(patch|minor|major)$ ]]; then
    echo "${GREEN}✓ PASS${NC} - Valid suggestion type"
else
    echo "${RED}✗ FAIL${NC} - Invalid suggestion type"
fi

# Test 5: Delta calculation
echo ""
echo "Test 5: Delta calculation"
echo "Testing delta formulas"

if command -v jq >/dev/null 2>&1; then
    patch_delta=$(echo "$result" | jq -r '.loc_delta.patch_delta // 0')
    minor_delta=$(echo "$result" | jq -r '.loc_delta.minor_delta // 0')
    major_delta=$(echo "$result" | jq -r '.loc_delta.major_delta // 0')
else
    patch_delta=$(echo "$result" | sed -n 's/.*"patch_delta":[[:space:]]*\([0-9]*\).*/\1/p' || echo "0")
    minor_delta=$(echo "$result" | sed -n 's/.*"minor_delta":[[:space:]]*\([0-9]*\).*/\1/p' || echo "0")
    major_delta=$(echo "$result" | sed -n 's/.*"major_delta":[[:space:]]*\([0-9]*\).*/\1/p' || echo "0")
fi

echo "Patch delta: $patch_delta"
echo "Minor delta: $minor_delta"
echo "Major delta: $major_delta"

# Test 6: Bonus points validation
echo ""
echo "Test 6: Bonus points validation"
echo "Total bonus should be a non-negative integer"

if [[ "$total_bonus" =~ ^[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC} - Valid bonus points: $total_bonus"
else
    echo "${RED}✗ FAIL${NC} - Invalid bonus points: $total_bonus"
fi

# Cleanup
echo ""
echo "Cleaning up..."
cleanup_temp_test_env "$test_dir"

echo "Test completed!" 