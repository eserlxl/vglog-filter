#!/bin/bash
# Test script for semantic version analyzer fixes
# Tests the bug fixes and improvements made to the analyzer

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

ANALYZER="./dev-bin/semantic-version-analyzer"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_output="$3"
    
    printf "${YELLOW}Testing: %s${NC}\n" "$test_name"
    
    local actual_output
    actual_output=$(eval "$test_cmd" 2>&1 || true)
    
    if [[ "$actual_output" == *"$expected_output"* ]]; then
        printf "${GREEN}✓ PASS${NC}\n"
        ((TESTS_PASSED++))
    else
        printf "${RED}✗ FAIL${NC}\n"
        printf "Expected: %s\n" "$expected_output"
        printf "Got: %s\n" "$actual_output"
        ((TESTS_FAILED++))
    fi
    printf "\n"
}

# Test 1: Manual CLI detection fix
printf "=== Test 1: Manual CLI Detection Fix ===\n"
# Create a test file with CLI options
cat > test_cli.c << 'EOF'
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help message\n");
            return 0;
        }
        if (strcmp(argv[i], "--version") == 0) {
            printf("Version 1.0.0\n");
            return 0;
        }
    }
    return 0;
}
EOF

# Add the file
git add test_cli.c
git commit -m "Add test CLI file" --no-gpg-sign

# Test that manual CLI detection works
run_test "Manual CLI detection" \
    "$ANALYZER --verbose --since HEAD~1" \
    "Manual CLI changes: false"

# Modify the file to add a new option
cat > test_cli.c << 'EOF'
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help message\n");
            return 0;
        }
        if (strcmp(argv[i], "--version") == 0) {
            printf("Version 1.0.0\n");
            return 0;
        }
        if (strcmp(argv[i], "--verbose") == 0) {
            printf("Verbose mode enabled\n");
            return 0;
        }
    }
    return 0;
}
EOF

git add test_cli.c
git commit -m "Add --verbose option" --no-gpg-sign

# Test that manual CLI detection detects the added option
run_test "Manual CLI detection with added option" \
    "$ANALYZER --verbose --since HEAD~1" \
    "Manual CLI changes: true"

# Test 2: Nested directory classification
printf "=== Test 2: Nested Directory Classification ===\n"

# Create nested structure
mkdir -p pkg/components/docs
mkdir -p pkg/components/src
mkdir -p pkg/components/test

# Create files in nested directories
echo "Documentation" > pkg/components/docs/README.md
echo "Source code" > pkg/components/src/main.c
echo "Test code" > pkg/components/test/test_main.c

git add pkg/
git commit -m "Add nested directory structure" --no-gpg-sign

# Test that nested files are properly classified
run_test "Nested doc classification" \
    "$ANALYZER --since HEAD~1" \
    "new_doc_files"

run_test "Nested source classification" \
    "$ANALYZER --since HEAD~1" \
    "new_source_files"

run_test "Nested test classification" \
    "$ANALYZER --since HEAD~1" \
    "new_test_files"

# Test 3: Rename/copy detection
printf "=== Test 3: Rename/Copy Detection ===\n"

# Create a file and then rename it
echo "Original content" > original_file.txt
git add original_file.txt
git commit -m "Add original file" --no-gpg-sign

git mv original_file.txt renamed_file.txt
git commit -m "Rename file" --no-gpg-sign

# Test that rename is detected
run_test "Rename detection" \
    "$ANALYZER --since HEAD~1" \
    "modified_files"

# Test 4: Empty set handling
printf "=== Test 4: Empty Set Handling ===\n"

# Create a file with getopt, then remove all options
cat > test_getopt.c << 'EOF'
#include <getopt.h>

int main(int argc, char *argv[]) {
    static struct option long_options[] = {
        {"help", no_argument, 0, 'h'},
        {"version", no_argument, 0, 'v'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "hv", long_options, NULL)) != -1) {
        switch (opt) {
            case 'h':
                printf("Help\n");
                break;
            case 'v':
                printf("Version\n");
                break;
        }
    }
    return 0;
}
EOF

git add test_getopt.c
git commit -m "Add getopt file with options" --no-gpg-sign

# Remove all options
cat > test_getopt.c << 'EOF'
#include <getopt.h>

int main(int argc, char *argv[]) {
    static struct option long_options[] = {
        {0, 0, 0, 0}
    };
    
    return 0;
}
EOF

git add test_getopt.c
git commit -m "Remove all CLI options" --no-gpg-sign

# Test that removal is detected
run_test "Empty set handling" \
    "$ANALYZER --since HEAD~1" \
    "breaking_cli_changes"

# Test 5: External diff tool protection
printf "=== Test 5: External Diff Tool Protection ===\n"

# Test that --no-ext-diff is used
run_test "External diff protection" \
    "$ANALYZER --help" \
    "--no-ext-diff for consistent parsing"

# Cleanup
printf "=== Cleanup ===\n"
git reset --hard HEAD~6 2>/dev/null || true
rm -f test_cli.c test_getopt.c
rm -rf pkg/

# Summary
printf "=== Test Summary ===\n"
printf "${GREEN}Tests passed: %d${NC}\n" "$TESTS_PASSED"
printf "${RED}Tests failed: %d${NC}\n" "$TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
else
    printf "${RED}Some tests failed!${NC}\n"
    exit 1
fi 