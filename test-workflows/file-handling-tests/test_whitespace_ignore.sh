#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test whitespace ignore functionality in semantic-version-analyzer
# This test verifies that whitespace-only changes don't trigger major version bumps

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing Whitespace Ignore ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "whitespace-ignore")
cd "$temp_dir"

# Create a test source file
mkdir -p src
{
    generate_license_header "cpp" "Test fixture for whitespace change detection"
    cat << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF
} > src/test_whitespace.cpp

# Add and commit the file
git add src/test_whitespace.cpp
git commit -m "Add test file for whitespace test"

# Make whitespace-only changes
sed -i 's/    std::cout/        std::cout/' src/test_whitespace.cpp

# Commit the whitespace changes
git add src/test_whitespace.cpp
git commit -m "Whitespace-only changes"

# Run semantic version analyzer without --ignore-whitespace
echo "Running semantic version analyzer (without --ignore-whitespace)..."
# Note: Using '|| true' to capture output even if command fails (intentional)
if cd "$PROJECT_ROOT"; then
    result1=$(./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" --base HEAD~1 --target HEAD 2>/dev/null || true)
else
    result1=""
fi

echo ""
echo "Running semantic version analyzer (with --ignore-whitespace)..."
# Note: Using '|| true' to capture output even if command fails (intentional)
if cd "$PROJECT_ROOT"; then
    result2=$(./dev-bin/semantic-version-analyzer --ignore-whitespace --machine --repo-root "$temp_dir" --base HEAD~1 --target HEAD 2>/dev/null || true)
else
    result2=""
fi

# Extract suggestions
suggestion1=$(echo "$result1" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")
suggestion2=$(echo "$result2" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Without --ignore-whitespace: $suggestion1"
echo "With --ignore-whitespace: $suggestion2"

# Verify that whitespace ignore works correctly
if [[ "$suggestion1" = "$suggestion2" ]]; then
    echo "✅ PASS: Whitespace ignore works correctly"
    exit_code=0
else
    echo "❌ FAIL: Whitespace ignore should not change suggestion, got: $suggestion1 vs $suggestion2"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 