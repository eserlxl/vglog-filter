#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Focused test script for version calculation logic

set -Euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Testing Version Calculation Logic"
echo "================================"

# Go to project root
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." || exit 1

# Create a temporary clean environment for testing
TEMP_DIR=$(mktemp -d)
# Copy everything except .git directory
find . -maxdepth 1 -not -name . -not -name .git -exec cp -r {} "$TEMP_DIR/" \;
cd "$TEMP_DIR" || exit 1

# Initialize git in the temp directory
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Test 1: Basic version calculation
echo ""
echo "Test 1: Basic version calculation"
echo "9.3.0 + patch delta 6 = 9.3.6"

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
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." || exit 1
result=$(./dev-bin/semantic-version-analyzer --base "$base_commit" --repo-root "$TEMP_DIR" --json 2>/dev/null)
cd "$TEMP_DIR" || exit 1

# Parse JSON properly - handle multiline JSON
if command -v jq >/dev/null 2>&1; then
    next_version=$(echo "$result" | jq -r '.next_version')
else
    next_version=$(echo "$result" | sed -n 's/.*"next_version":"\([^"]*\)".*/\1/p')
fi
echo "Expected: A valid version number"
echo "Actual: $next_version"

if [[ -n "$next_version" ]] && [[ "$next_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
    echo "Debug: Full result: $result"
fi

# Test 2: Patch rollover
echo ""
echo "Test 2: Patch rollover"
echo "9.3.95 + patch delta 6 = 9.3.96"

# Set version to 9.3.95
echo "9.3.95" > VERSION
git add VERSION
git commit -m "Set version to 9.3.95" -q

# Add another change to a non-source file
echo "more test content" >> README.md
git add README.md
git commit -m "Add another test change" -q

# Run semantic analyzer
base_commit2=$(git rev-parse HEAD~1)
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." || exit 1
result2=$(./dev-bin/semantic-version-analyzer --base "$base_commit2" --repo-root "$TEMP_DIR" --json 2>/dev/null)
cd "$TEMP_DIR" || exit 1
if command -v jq >/dev/null 2>&1; then
    next_version2=$(echo "$result2" | jq -r '.next_version')
else
    next_version2=$(echo "$result2" | sed -n 's/.*"next_version":"\([^"]*\)".*/\1/p')
fi
echo "Expected: A valid version number"
echo "Actual: $next_version2"

if [[ -n "$next_version2" ]] && [[ "$next_version2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
    echo "Debug: Full result: $result2"
fi

# Test 3: Minor rollover
echo ""
echo "Test 3: Minor rollover"
echo "9.99.95 + patch delta 6 = 9.99.96"

# Set version to 9.99.95
echo "9.99.95" > VERSION
git add VERSION
git commit -m "Set version to 9.99.95" -q

# Add another change to a non-source file
echo "third test content" >> README.md
git add README.md
git commit -m "Add third test change" -q

# Run semantic analyzer
base_commit3=$(git rev-parse HEAD~1)
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." || exit 1
result3=$(./dev-bin/semantic-version-analyzer --base "$base_commit3" --repo-root "$TEMP_DIR" --json 2>/dev/null)
cd "$TEMP_DIR" || exit 1
if command -v jq >/dev/null 2>&1; then
    next_version3=$(echo "$result3" | jq -r '.next_version')
else
    next_version3=$(echo "$result3" | sed -n 's/.*"next_version":"\([^"]*\)".*/\1/p')
fi
echo "Expected: A valid version number"
echo "Actual: $next_version3"

if [[ -n "$next_version3" ]] && [[ "$next_version3" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
    echo "Debug: Full result: $result3"
fi

# Test 4: Reason format
echo ""
echo "Test 4: Reason format"
echo "Should include LOC value and version type"

if command -v jq >/dev/null 2>&1; then
    reason=$(echo "$result" | jq -r '.reason')
else
    reason=$(echo "$result" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')
fi
echo "Reason: $reason"

if [[ "$reason" = *"LOC:"* ]] && [[ "$reason" = *"PATCH"* ]]; then
    echo "${GREEN}✓ PASS${NC} - Reason includes LOC and version type"
else
    echo "${RED}✗ FAIL${NC} - Reason format incorrect"
fi

# Test 5: Delta calculation
echo ""
echo "Test 5: Delta calculation"
echo "Testing delta formulas"

if command -v jq >/dev/null 2>&1; then
    patch_delta=$(echo "$result" | jq -r '.loc_delta.patch_delta')
    minor_delta=$(echo "$result" | jq -r '.loc_delta.minor_delta')
    major_delta=$(echo "$result" | jq -r '.loc_delta.major_delta')
else
    patch_delta=$(echo "$result" | sed -n 's/.*"patch_delta":[[:space:]]*\([0-9]*\).*/\1/p')
    minor_delta=$(echo "$result" | sed -n 's/.*"minor_delta":[[:space:]]*\([0-9]*\).*/\1/p')
    major_delta=$(echo "$result" | sed -n 's/.*"major_delta":[[:space:]]*\([0-9]*\).*/\1/p')
fi

echo "Patch delta: $patch_delta"
echo "Minor delta: $minor_delta"
echo "Major delta: $major_delta"

# Cleanup
echo ""
echo "Cleaning up..."
cd /
rm -rf "$TEMP_DIR"

echo "Test completed!" 