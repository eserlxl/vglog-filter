#!/bin/bash
# Test whitespace ignore functionality in semantic-version-analyzer
# This test verifies that whitespace-only changes don't trigger major version bumps

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing Whitespace Ignore ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "whitespace-ignore")
cd "$temp_dir"

# Create a test source file
cat > test-workflows/source-fixtures/test_whitespace.cpp << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

# Add and commit the file
git add test-workflows/source-fixtures/test_whitespace.cpp
git commit -m "Add test file for whitespace test"

# Make whitespace-only changes
cat > test-workflows/source-fixtures/test_whitespace.cpp << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

# Commit the whitespace changes
git add test-workflows/source-fixtures/test_whitespace.cpp
git commit -m "Whitespace-only changes"

# Run semantic version analyzer without --ignore-whitespace
echo "Running semantic version analyzer (without --ignore-whitespace)..."
cd "$PROJECT_ROOT"
./dev-bin/semantic-version-analyzer --verbose --repo-root "$temp_dir"

echo ""
echo "Running semantic version analyzer (with --ignore-whitespace)..."
./dev-bin/semantic-version-analyzer --ignore-whitespace --verbose --repo-root "$temp_dir"

echo "=== Test Complete ==="
echo "Expected: With --ignore-whitespace, diff_size should be smaller"
echo "Check the output above to verify whitespace ignore works correctly."

# Clean up
cleanup_temp_test_env "$temp_dir" 