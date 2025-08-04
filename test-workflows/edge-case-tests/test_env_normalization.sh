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

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source test helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

echo "Testing pure mathematical versioning system..."

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
if cd "$PROJECT_ROOT"; then
    result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --verbose --repo-root "$temp_dir" 2>/dev/null || true)
else
    result=""
fi

# Check for pure mathematical versioning indicators
if [[ "$result" == *"PURE MATHEMATICAL VERSIONING SYSTEM"* ]]; then
    echo "✅ PASS: Pure mathematical versioning system detected"
else
    echo "❌ FAIL: Pure mathematical versioning system not detected"
    echo "Expected: PURE MATHEMATICAL VERSIONING SYSTEM"
    echo "Got: $result"
    exit_code=1
    cleanup_temp_test_env "$temp_dir"
    exit $exit_code
fi

# Check for bonus threshold information
if [[ "$result" == *"Major: Total bonus >="* ]] && [[ "$result" == *"Minor: Total bonus >="* ]] && [[ "$result" == *"Patch: Total bonus >="* ]]; then
    echo "✅ PASS: Bonus threshold information displayed"
else
    echo "❌ FAIL: Bonus threshold information not displayed"
    echo "Expected: Major/Minor/Patch bonus thresholds"
    echo "Got: $result"
    exit_code=1
    cleanup_temp_test_env "$temp_dir"
    exit $exit_code
fi

# Check for "No minimum thresholds or extra rules" message
if [[ "$result" == *"No minimum thresholds or extra rules"* ]]; then
    echo "✅ PASS: No extra rules message displayed"
else
    echo "❌ FAIL: No extra rules message not displayed"
    echo "Expected: No minimum thresholds or extra rules"
    echo "Got: $result"
    exit_code=1
    cleanup_temp_test_env "$temp_dir"
    exit $exit_code
fi

# Test that the system produces consistent results
echo "Testing consistent mathematical results..."
if cd "$PROJECT_ROOT"; then
    result1=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --machine --repo-root "$temp_dir" 2>/dev/null || true)
    result2=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --machine --repo-root "$temp_dir" 2>/dev/null || true)
else
    result1=""
    result2=""
fi

suggestion1=$(echo "$result1" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")
suggestion2=$(echo "$result2" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Results:"
echo "  Run 1: $suggestion1"
echo "  Run 2: $suggestion2"

# Verify that results are identical (mathematical consistency)
if [[ "$suggestion1" = "$suggestion2" ]]; then
    echo "✅ PASS: Pure mathematical versioning produces consistent results"
    exit_code=0
else
    echo "❌ FAIL: Pure mathematical versioning failed - results differ"
    echo "  Expected identical results, got: $suggestion1, $suggestion2"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 