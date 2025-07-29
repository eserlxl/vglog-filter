#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test NUL-safe file handling in semantic-version-analyzer
# This test verifies that files with spaces in names are handled correctly

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing NUL-Safe File Handling ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "nul-safety")
cd "$temp_dir"

# Create a test source file with space in name
mkdir -p src
cat > "src/file with space.cpp" << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

# Add and commit the file
git add "src/file with space.cpp"
git commit -m "Add source file with space in name"

# Modify the file to add CLI options
cat > "src/file with space.cpp" << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hv")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version" << std::endl;
                break;
        }
    }
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

# Commit the modification
git add "src/file with space.cpp"
git commit -m "Add CLI options to source file"

# Run semantic version analyzer from the original project directory
result=$(cd "$PROJECT_ROOT" && ./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" --base HEAD~1 --target HEAD 2>/dev/null || true)

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that CLI changes trigger minor version bump
if [[ "$suggestion" = "minor" ]]; then
    echo "✅ PASS: CLI changes correctly trigger minor version bump"
    exit_code=0
else
    echo "❌ FAIL: CLI changes should trigger minor version bump, got: $suggestion"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 