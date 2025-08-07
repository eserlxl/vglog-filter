#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter test suite and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test fixture for CLI detection
set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "=== Testing Semantic Version Analyzer Fixes ==="

# Create a temporary test environment
temp_dir=$(create_temp_test_env)
trap 'cleanup_temp_test_env "$temp_dir"' EXIT

# Test 1: Manual CLI detection in nested directories
echo "Test 1: Manual CLI detection (nested test-workflows/source-fixtures/cli/main.c)"
cd "$temp_dir"

# Create a basic main function first
mkdir -p src
cat > src/main.c << EOF
$(generate_license_header "c" "Test fixture for CLI detection")
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    printf("Hello, world!\n");
    return 0;
}
EOF

git add src/main.c
git commit -m "Add basic main function"

# Now add CLI options
cat > src/main.c << EOF
$(generate_license_header "c" "Test fixture for CLI detection")
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s [--help] [--version]\n", argv[0]);
        return 1;
    }
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help message\n");
        } else if (strcmp(argv[i], "--version") == 0) {
            printf("Version 1.0\n");
        } else if (strcmp(argv[i], "--new-option") == 0) {
            printf("New option added\n");
        }
    }
    return 0;
}
EOF

git add src/main.c
git commit -m "Add CLI with new option"

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Run semantic version analyzer
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --verbose --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" 2>&1 || true)

# Debug: Show the full result
echo "Debug: Full result:"
echo "$result"
echo "Debug: End of result"

# Extract suggestion
suggestion=$(echo "$result" | grep "^SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

if [[ "$suggestion" = "minor" ]]; then
    echo "✅ PASS: CLI changes detected correctly"
else
    echo "❌ FAIL: Expected minor, got $suggestion"
    exit 1
fi

echo

# Test 2: API breaking changes detection
echo "Test 2: API breaking changes (removed prototype from header - single line change)"
cd "$temp_dir"

# Create a header file with a function prototype
mkdir -p include
cat > include/header.h << EOF
$(generate_license_header "h" "Test fixture for API breaking change detection")
#ifndef HEADER_H
#define HEADER_H

int test_function(int param);
void another_function(void);

#endif
EOF

git add include/header.h
git commit -m "Add header with function prototypes"

# Remove a function prototype
cat > include/header.h << EOF
$(generate_license_header "h" "Test fixture for API breaking change detection")
#ifndef HEADER_H
#define HEADER_H

int test_function(int param);

#endif
EOF

git add include/header.h
git commit -m "Remove function prototype (breaking change)"

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Run semantic version analyzer
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --verbose --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" 2>&1 || true)

# Debug: Show the full result
echo "Debug: Full result for Test 2:"
echo "$result"
echo "Debug: End of result for Test 2"

# Extract suggestion
suggestion=$(echo "$result" | grep "^SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

if [[ "$suggestion" = "major" ]]; then
    echo "✅ PASS: Function prototype removal correctly classified as API breaking change"
else
    echo "❌ FAIL: Expected major, got $suggestion"
    exit 1
fi

echo

# Test 3: CLI breaking changes detection
echo "Test 3: CLI breaking changes (removed --bar option)"
cd "$temp_dir"

# Create a CLI file with an option
cat > src/cli.c << EOF
$(generate_license_header "c" "Test fixture for CLI breaking change detection")
#include <stdio.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help\n");
        } else if (strcmp(argv[i], "--bar") == 0) {
            printf("Bar option\n");
        }
    }
    return 0;
}
EOF

git add src/cli.c
git commit -m "Add CLI with --bar option"

# Remove the --bar option
cat > src/cli.c << EOF
$(generate_license_header "c" "Test fixture for CLI breaking change detection")
#include <stdio.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help\n");
        }
        // --bar option removed
    }
    return 0;
}
EOF

git add src/cli.c
git commit -m "Remove --bar option"

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Run semantic version analyzer
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --machine --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" 2>&1 || true)

# Extract suggestion
suggestion=$(echo "$result" | grep "^SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

if [[ "$suggestion" = "minor" ]]; then
    echo "✅ PASS: CLI breaking changes detected correctly"
else
    echo "❌ FAIL: Expected minor, got $suggestion"
    exit 1
fi

echo

# Test 4: Whitespace handling
echo "Test 4: Whitespace-only changes with --ignore-whitespace"
cd "$temp_dir"

# Create a file with some content
cat > src/test.c << EOF
$(generate_license_header "c" "Test fixture for whitespace handling")
int main() {
    return 0;
}
EOF

git add src/test.c
git commit -m "Add test file"

# Change only whitespace
cat > src/test.c << EOF
$(generate_license_header "c" "Test fixture for whitespace handling")
int main() {    
    return 0;    
}    
EOF

git add src/test.c
git commit -m "Change whitespace only"

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Run semantic version analyzer with --ignore-whitespace
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --machine --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" --ignore-whitespace 2>&1 || true)

# Extract suggestion
suggestion=$(echo "$result" | grep "^SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

if [[ "$suggestion" = "none" ]]; then
    echo "✅ PASS: Whitespace changes ignored correctly"
else
    echo "❌ FAIL: Expected none, got $suggestion"
    exit 1
fi

echo

# Test 5: --print-base functionality
echo "Test 5: --print-base functionality"

# Run --print-base from the temporary directory
base_ref=$("$PROJECT_ROOT/dev-bin/ref-resolver.sh" --print-base --repo-root "$temp_dir" 2>&1 | tail -1 || echo "unknown")

if [[ "$base_ref" != "unknown" ]] && [[ "$base_ref" =~ ^[a-f0-9]+$ ]]; then
    echo "✅ PASS: --print-base returned valid SHA: $base_ref"
else
    echo "❌ FAIL: --print-base failed or returned invalid SHA: $base_ref"
    exit 1
fi

echo

echo "=== All tests completed successfully ===" 
exit 0