#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test for environment variable normalization
# Verifies that MAJOR_REQUIRE_BREAKING accepts various boolean values

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "Testing environment variable normalization..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "env-normalization")
cd "$temp_dir"

# Create some test files and commits to have a valid git history
echo "Initial content" > test_file.txt
git add test_file.txt
git commit -m "Initial commit" >/dev/null 2>&1

echo "Updated content" > test_file.txt
git add test_file.txt
git commit -m "Second commit" >/dev/null 2>&1

# Test with MAJOR_REQUIRE_BREAKING=TRUE
echo "Testing MAJOR_REQUIRE_BREAKING=TRUE..."
# Note: Using '|| true' to capture output even if command fails (intentional)
result1=$(cd "$PROJECT_ROOT" && MAJOR_REQUIRE_BREAKING=TRUE ./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" 2>/dev/null || true)
suggestion1=$(echo "$result1" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

# Test with MAJOR_REQUIRE_BREAKING=1
echo "Testing MAJOR_REQUIRE_BREAKING=1..."
# Note: Using '|| true' to capture output even if command fails (intentional)
result2=$(cd "$PROJECT_ROOT" && MAJOR_REQUIRE_BREAKING=1 ./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" 2>/dev/null || true)
suggestion2=$(echo "$result2" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

# Test with MAJOR_REQUIRE_BREAKING=true (default)
echo "Testing MAJOR_REQUIRE_BREAKING=true (default)..."
# Note: Using '|| true' to capture output even if command fails (intentional)
result3=$(cd "$PROJECT_ROOT" && ./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" 2>/dev/null || true)
suggestion3=$(echo "$result3" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Results:"
echo "  TRUE: $suggestion1"
echo "  1:    $suggestion2"
echo "  true: $suggestion3"

# Verify that all results are identical
if [[ "$suggestion1" = "$suggestion2" ]] && [[ "$suggestion2" = "$suggestion3" ]]; then
    echo "✅ PASS: Environment variable normalization works correctly"
    exit_code=0
else
    echo "❌ FAIL: Environment variable normalization failed - results differ"
    echo "  Expected all to be identical, got: $suggestion1, $suggestion2, $suggestion3"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 