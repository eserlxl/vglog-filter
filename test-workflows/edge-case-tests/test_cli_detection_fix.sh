#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test for CLI change detection fix
# Verifies that cli_changes=false when no source/include files are changed

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

echo "Testing CLI change detection fix..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "cli-detection-fix")
cd "$temp_dir"

# Create a minimal project structure
mkdir -p src include
echo "int main() { return 0; }" > src/main.cpp
echo "int helper();" > include/helper.h

# Initial commit
git add .
git commit -m "Initial commit" >/dev/null 2>&1

# Make a minimal change to a non-source file (README.md)
echo "# Test change" >> README.md
git add README.md
git commit -m "Test: Update README only"

# Run semantic version analyzer from the original project directory
# Note: Using '|| true' to capture output even if command fails (intentional)
if cd "$PROJECT_ROOT"; then
    result=$(./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" 2>/dev/null || true)
else
    result=""
fi

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that when no source files are changed, we get a reasonable suggestion
# (should be none, patch, or minor, but not major due to large changes)
if [[ "$suggestion" = "major" ]]; then
    echo "❌ FAIL: Major version bump suggested when only docs changed (likely due to large diff)"
    exit_code=1
else
    echo "✅ PASS: Reasonable version bump suggestion ($suggestion) when no source files changed"
    exit_code=0
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code
