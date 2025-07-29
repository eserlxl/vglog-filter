#!/bin/bash
# Test header prototype removal detection in semantic-version-analyzer
# This test verifies that removing a prototype in test-workflows/source-fixtures/test_header.h triggers api_breaking=true

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "=== Testing Header Prototype Removal ==="

# Create a test header file with a prototype
cat > test-workflows/source-fixtures/test_header.h << 'EOF'
#ifndef TEST_HEADER_H
#define TEST_HEADER_H

// Test function prototype
int test_function(int param1, const char* param2);

#endif // TEST_HEADER_H
EOF

# Add and commit the header
git add test-workflows/source-fixtures/test_header.h
git commit -m "Add test header with prototype"

# Remove the prototype
cat > test-workflows/source-fixtures/test_header.h << 'EOF'
#ifndef TEST_HEADER_H
#define TEST_HEADER_H

// Test function prototype removed

#endif // TEST_HEADER_H
EOF

# Commit the removal
git add test-workflows/source-fixtures/test_header.h
git commit -m "Remove function prototype"

# Run semantic version analyzer
echo "Running semantic version analyzer..."
./dev-bin/semantic-version-analyzer --verbose

echo "=== Test Complete ==="
echo "Expected: Should show api_breaking=true and suggest major version bump"
echo "Check the output above to verify header removal detection works correctly." 