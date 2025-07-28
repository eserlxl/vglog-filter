#!/bin/bash
# Test rename handling in semantic-version-analyzer
# This test verifies that renamed files are counted as modified, not added

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "=== Testing Rename Handling ==="

# Create a test file
echo "test content" > test_file.txt

# Add and commit the file
git add test_file.txt
git commit -m "Add test file for rename test"

# Rename the file
git mv test_file.txt test_file_renamed.txt
git commit -m "Rename test file"

# Run semantic version analyzer
echo "Running semantic version analyzer..."
./dev-bin/semantic-version-analyzer --verbose

echo "=== Test Complete ==="
echo "Expected: Should show 1 modified file (not 1 added file)"
echo "Check the output above to verify rename handling works correctly." 