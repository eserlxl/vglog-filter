#!/bin/bash
# Test NUL-safe file handling in semantic-version-analyzer
# This test verifies that files with spaces in names are handled correctly

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing NUL-Safe File Handling ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "nul-safety")
cd "$temp_dir"

# Create a test source file with space in name
cat > "test-workflows/source-fixtures/file with space.cpp" << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

# Add and commit the file
git add "test-workflows/source-fixtures/file with space.cpp"
git commit -m "Add source file with space in name"

# Modify the file to add CLI options
cat > "test-workflows/source-fixtures/file with space.cpp" << 'EOF'
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
git add "test-workflows/source-fixtures/file with space.cpp"
git commit -m "Add CLI options to source file"

# Run semantic version analyzer
echo "Running semantic version analyzer..."
cd "$PROJECT_ROOT"
./dev-bin/semantic-version-analyzer --verbose --repo-root "$temp_dir"

echo "=== Test Complete ==="
echo "Expected: Should detect CLI changes and suggest minor version bump"
echo "Check the output above to verify NUL-safe handling works correctly."

# Clean up
cleanup_temp_test_env "$temp_dir" 