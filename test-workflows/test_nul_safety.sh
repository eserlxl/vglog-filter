#!/bin/bash
# Test NUL-safe file handling in semantic-version-analyzer
# This test verifies that files with spaces in names are handled correctly

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "=== Testing NUL-Safe File Handling ==="

# Create a test source file with space in name
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

# Run semantic version analyzer
echo "Running semantic version analyzer..."
./dev-bin/semantic-version-analyzer --verbose

echo "=== Test Complete ==="
echo "Expected: Should detect CLI changes and suggest minor version bump"
echo "Check the output above to verify NUL-safe handling works correctly." 