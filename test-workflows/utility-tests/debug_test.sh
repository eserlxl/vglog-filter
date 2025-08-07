#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
set -euo pipefail

# Get project root (assume we're running from project root)
PROJECT_ROOT="$(pwd)"

# Source test helper functions
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "Testing debug functionality..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "debug-test")
cd "$temp_dir"

# Create some test files and commits in the temporary directory
echo "Initial content" > test_file.txt
git add test_file.txt
git commit -m "Initial commit" >/dev/null 2>&1

echo "Updated content" > test_file.txt
git add test_file.txt
git commit -m "Second commit" >/dev/null 2>&1

# Test git functionality
base_ref=$(git rev-list --max-parents=0 HEAD)
echo "Base ref: $base_ref"
commit_count=$(git rev-list --count "$base_ref"..HEAD)
echo "Commit count: $commit_count"

if [[ "$commit_count" -eq 0 ]]; then
    echo "No commits in range - should return 1"
    exit_code=1
else
    echo "Commits in range - should return 0"
    exit_code=0
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code
