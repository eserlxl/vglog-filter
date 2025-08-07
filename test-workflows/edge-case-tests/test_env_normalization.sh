#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test for pure mathematical versioning system
# Verifies that the system works with pure mathematical logic

set -euo pipefail

# Get project root (assume we're running from project root)
PROJECT_ROOT="$(pwd)"

# Source test helper functions
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "Testing semantic version analysis system..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "pure-math-versioning")
cd "$temp_dir"

# Create some test files and commits to have a valid git history
echo "Initial content" > test_file.txt
git add test_file.txt
git commit -m "Initial commit" >/dev/null 2>&1

echo "Updated content" > test_file.txt
git add test_file.txt
git commit -m "Second commit" >/dev/null 2>&1

# Test that the system shows pure mathematical versioning in verbose output
echo "Testing pure mathematical versioning output..."
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --verbose --repo-root "$temp_dir" 2>/dev/null || true)

# Check for semantic version analysis indicators
if [[ "$result" == *"Semantic Version Analysis v2"* ]]; then
    echo "✅ PASS: Semantic version analysis system detected"
else
    echo "❌ FAIL: Semantic version analysis system not detected"
    echo "Expected: Semantic Version Analysis v2"
    echo "Got: $result"
    exit_code=1
    cleanup_temp_test_env "$temp_dir"
    exit $exit_code
fi

# Check for bonus points information
if [[ "$result" == *"Total bonus points:"* ]]; then
    echo "✅ PASS: Bonus points information displayed"
else
    echo "❌ FAIL: Bonus points information not displayed"
    echo "Expected: Total bonus points"
    echo "Got: $result"
    exit_code=1
    cleanup_temp_test_env "$temp_dir"
    exit $exit_code
fi

# Check for suggested bump information
if [[ "$result" == *"Suggested bump:"* ]]; then
    echo "✅ PASS: Suggested bump information displayed"
else
    echo "❌ FAIL: Suggested bump information not displayed"
    echo "Expected: Suggested bump"
    echo "Got: $result"
    exit_code=1
    cleanup_temp_test_env "$temp_dir"
    exit $exit_code
fi

# Test that the system produces consistent results
echo "Testing consistent results..."
result1=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --machine --repo-root "$temp_dir" 2>/dev/null || true)
result2=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --machine --repo-root "$temp_dir" 2>/dev/null || true)

suggestion1=$(echo "$result1" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")
suggestion2=$(echo "$result2" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Results:"
echo "  Run 1: $suggestion1"
echo "  Run 2: $suggestion2"

# Verify that results are identical (consistency)
if [[ "$suggestion1" = "$suggestion2" ]]; then
    echo "✅ PASS: Version analysis produces consistent results"
    exit_code=0
else
    echo "❌ FAIL: Version analysis failed - results differ"
    echo "  Expected identical results, got: $suggestion1, $suggestion2"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 