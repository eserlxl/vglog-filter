#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test manual CLI detection

set -euo pipefail

# Get project root (assume we're running from project root)
PROJECT_ROOT="$(pwd)"
# Note: PROJECT_ROOT is defined but not used in this test
# PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
# shellcheck disable=SC1091
# shellcheck source=test_helper.sh
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "Testing manual CLI detection..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "debug-test")
cd "$temp_dir"

# Create test source files with CLI options
mkdir -p src
cat > src/main.cpp << 'EOF'
#include <iostream>

int main(int argc, char *argv[]) {
    // Original version with --help option
    if (argc > 1 && std::string(argv[1]) == "--help") {
        std::cout << "Help message" << std::endl;
        return 0;
    }
    return 0;
}
EOF

# Initial commit
git add src/main.cpp
git commit -m "Initial version with --help" >/dev/null 2>&1

# Store the first commit hash
base_ref=$(git rev-parse HEAD)

# Update the file to add --version option
cat > src/main.cpp << 'EOF'
#include <iostream>

int main(int argc, char *argv[]) {
    // Updated version with --help and --version options
    if (argc > 1) {
        if (std::string(argv[1]) == "--help") {
            std::cout << "Help message" << std::endl;
            return 0;
        }
        if (std::string(argv[1]) == "--version") {
            std::cout << "Version 9.3.0" << std::endl;
            return 0;
        }
    }
    return 0;
}
EOF

git add src/main.cpp
git commit -m "Add --version option" >/dev/null 2>&1

# Store the second commit hash
target_ref=$(git rev-parse HEAD)

# Test the exact commands from the script
added_long_opts=$(git -c color.ui=false diff -M -C "$base_ref".."$target_ref" -- 'src/**/*.c' 'src/**/*.cc' 'src/**/*.cpp' 'src/**/*.cxx' | grep -E '^\+.*--[[:alnum:]-]+' | sed -n 's/.*\(--[[:alnum:]-]\+\).*/\1/p' | sort -u || printf '')

removed_long_opts=$(git -c color.ui=false diff -M -C "$base_ref".."$target_ref" -- 'src/**/*.c' 'src/**/*.cc' 'src/**/*.cpp' 'src/**/*.cxx' | grep -E '^-.*--[[:alnum:]-]+' | sed -n 's/.*\(--[[:alnum:]-]\+\).*/\1/p' | sort -u || printf '')

echo "Added long options: '$added_long_opts'"
echo "Removed long options: '$removed_long_opts'"

manual_added_long_count=$(printf '%s\n' "$added_long_opts" | wc -l || printf '0')
manual_removed_long_count=$(printf '%s\n' "$removed_long_opts" | wc -l || printf '0')

echo "Manual added long count: $manual_added_long_count"
echo "Manual removed long count: $manual_removed_long_count"

manual_cli_changes=false
(( manual_added_long_count > 0 || manual_removed_long_count > 0 )) && manual_cli_changes=true

echo "Manual CLI changes: $manual_cli_changes"

# Clean up
cleanup_temp_test_env "$temp_dir" 