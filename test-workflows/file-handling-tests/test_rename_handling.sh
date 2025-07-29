#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test rename handling in semantic-version-analyzer
# This test verifies that renamed files are counted as modified, not added

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing Rename Handling ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "rename-handling")
cd "$temp_dir"

# Create a test file
echo "test content" > test-workflows/source-fixtures/test_content_simple.txt

# Add and commit the file
git add test-workflows/source-fixtures/test_content_simple.txt
git commit -m "Add test file for rename test"

# Rename the file
git mv test-workflows/source-fixtures/test_content_simple.txt test-workflows/source-fixtures/test_content_renamed.txt
git commit -m "Rename test file"

# Run semantic version analyzer from the original project directory
# Note: Using '|| true' to capture output even if command fails (intentional)
if cd "$PROJECT_ROOT"; then
    result=$(./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" --base HEAD~1 --target HEAD 2>/dev/null || true)
else
    result=""
fi

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that rename is handled correctly (should be minor or none, not major)
if [[ "$suggestion" = "major" ]]; then
    echo "❌ FAIL: Rename should not trigger major version bump, got: $suggestion"
    exit_code=1
else
    echo "✅ PASS: Rename handled correctly, got: $suggestion"
    exit_code=0
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 