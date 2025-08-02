#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Focused test script for version calculation logic

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Testing Version Calculation Logic"
echo "================================"

# Go to project root
cd ../../

# Test 1: Basic version calculation
echo ""
echo "Test 1: Basic version calculation"
echo "9.3.0 + patch delta 6 = 9.3.6"

# Set version to 9.3.0
echo "9.3.0" > VERSION
git add VERSION
git commit -m "Set version to 9.3.0" -q

# Add a small change
echo "// Test change" >> src/main.cpp
git add src/main.cpp
git commit -m "Add test change" -q

# Run semantic analyzer and extract next version
base_commit=$(git rev-parse HEAD~1)
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --base "$base_commit" --json 2>/dev/null)

# Parse JSON properly
next_version=$(echo "$result" | grep -o '"next_version":"[^"]*"' | cut -d'"' -f4)
echo "Expected: 9.3.6"
echo "Actual: $next_version"

if [[ "$next_version" = "9.3.6" ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
fi

# Test 2: Patch rollover
echo ""
echo "Test 2: Patch rollover"
echo "9.3.95 + patch delta 6 = 9.4.1"

# Set version to 9.3.95
echo "9.3.95" > VERSION
git add VERSION
git commit -m "Set version to 9.3.95" -q

# Add another change
echo "// Another test change" >> src/main.cpp
git add src/main.cpp
git commit -m "Add another test change" -q

# Run semantic analyzer
base_commit2=$(git rev-parse HEAD~1)
result2=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --base "$base_commit2" --json 2>/dev/null)
next_version2=$(echo "$result2" | grep -o '"next_version":"[^"]*"' | cut -d'"' -f4)
echo "Expected: 9.4.1"
echo "Actual: $next_version2"

if [[ "$next_version2" = "9.4.1" ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
fi

# Test 3: Minor rollover
echo ""
echo "Test 3: Minor rollover"
echo "9.99.95 + patch delta 6 = 10.0.1"

# Set version to 9.99.95
echo "9.99.95" > VERSION
git add VERSION
git commit -m "Set version to 9.99.95" -q

# Add another change
echo "// Third test change" >> src/main.cpp
git add src/main.cpp
git commit -m "Add third test change" -q

# Run semantic analyzer
base_commit3=$(git rev-parse HEAD~1)
result3=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --base "$base_commit3" --json 2>/dev/null)
next_version3=$(echo "$result3" | grep -o '"next_version":"[^"]*"' | cut -d'"' -f4)
echo "Expected: 10.0.1"
echo "Actual: $next_version3"

if [[ "$next_version3" = "10.0.1" ]]; then
    echo "${GREEN}✓ PASS${NC}"
else
    echo "${RED}✗ FAIL${NC}"
fi

# Test 4: Reason format
echo ""
echo "Test 4: Reason format"
echo "Should include LOC value and version type"

reason=$(echo "$result" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4)
echo "Reason: $reason"

if [[ "$reason" = *"LOC:"* ]] && [[ "$reason" = *"MINOR"* ]]; then
    echo "${GREEN}✓ PASS${NC} - Reason includes LOC and version type"
else
    echo "${RED}✗ FAIL${NC} - Reason format incorrect"
fi

# Test 5: Delta calculation
echo ""
echo "Test 5: Delta calculation"
echo "Testing delta formulas"

patch_delta=$(echo "$result" | grep -o '"patch_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
minor_delta=$(echo "$result" | grep -o '"minor_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
major_delta=$(echo "$result" | grep -o '"major_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')

echo "Patch delta: $patch_delta"
echo "Minor delta: $minor_delta"
echo "Major delta: $major_delta"

# Cleanup
echo ""
echo "Cleaning up..."
git reset --hard HEAD~6 -q
git clean -fd -q

echo "Test completed!" 