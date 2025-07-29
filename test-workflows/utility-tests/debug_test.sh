#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "Testing debug functionality..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "debug-test")
cd "$temp_dir"

# Create some test files and commits
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
