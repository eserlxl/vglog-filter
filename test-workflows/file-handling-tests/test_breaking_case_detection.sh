#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test for breaking case detection across C file extensions
# Verifies that removing a case in .c files triggers major version bump

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "Testing breaking case detection across C file extensions..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "breaking-case-detection")
cd "$temp_dir"

# Create a test C file with a switch statement
mkdir -p src
cat > src/test_switch.c << 'EOF'
#include <stdio.h>

int main(int argc, char *argv[]) {
    int option = 1;
    
    switch (option) {
        case 1:
            printf("Option 1\n");
            break;
        case 2:
            printf("Option 2\n");
            break;
        case 3:
            printf("Option 3\n");
            break;
        default:
            printf("Default\n");
            break;
    }
    
    return 0;
}
EOF

git add src/test_switch.c
git commit -m "Add test C file with switch statement"

# Debug: Check the commit
echo "Debug: First commit created"
git log --oneline
ls -la src/

# Remove a case (breaking change)
cat > src/test_switch.c << 'EOF'
#include <stdio.h>

int main(int argc, char *argv[]) {
    int option = 1;
    
    switch (option) {
        case 1:
            printf("Option 1\n");
            break;
        case 3:
            printf("Option 3\n");
            break;
        default:
            printf("Default\n");
            break;
    }
    
    return 0;
}
EOF

git add src/test_switch.c
git commit -m "Remove case 2 (breaking change)"

# Debug: Check the commits
echo "Debug: Second commit created"
git log --oneline
ls -la src/
cat src/test_switch.c

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Run CLI analyzer directly to debug
echo "Debug: Running CLI analyzer directly..."
cli_result=$("$PROJECT_ROOT/dev-bin/cli-options-analyzer.sh" --machine --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" 2>&1 || true)
echo "CLI analyzer output:"
echo "$cli_result"

# Run semantic version analyzer from the original project directory
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --verbose --machine --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" 2>&1 || true)

echo "Semantic analyzer output:"
echo "$result"

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that removing a case triggers major version bump
if [[ "$suggestion" = "major" ]]; then
    echo "✅ PASS: Removing case in .c file correctly triggers major version bump"
    exit_code=0
else
    echo "❌ FAIL: Removing case in .c file should trigger major version bump, got: $suggestion"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

echo "Exit code: $exit_code"
exit $exit_code
