#!/bin/bash
# Test header prototype removal detection in semantic-version-analyzer
# This test verifies that removing a prototype in ../source-fixtures/test_header.h triggers api_breaking=true

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing Header Prototype Removal ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "header-removal")
cd "$temp_dir"

# Create a test header file with a prototype
mkdir -p include
cat > include/test_header.h << 'EOF'
#ifndef TEST_HEADER_H
#define TEST_HEADER_H

// Test function prototype
int test_function(int param1, const char* param2);

#endif // TEST_HEADER_H
EOF

# Add and commit the header
git add include/test_header.h
git commit -m "Add test header with prototype"

# Remove the prototype
cat > include/test_header.h << 'EOF'
#ifndef TEST_HEADER_H
#define TEST_HEADER_H

// Test function prototype removed

#endif // TEST_HEADER_H
EOF

# Commit the removal
git add include/test_header.h
git commit -m "Remove function prototype"

# Run semantic version analyzer from the original project directory
result=$(cd "$PROJECT_ROOT" && ./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" --base HEAD~1 --target HEAD 2>/dev/null || true)

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that removing a prototype triggers major version bump
if [[ "$suggestion" = "major" ]]; then
    echo "✅ PASS: Removing prototype correctly triggers major version bump"
    exit_code=0
else
    echo "❌ FAIL: Removing prototype should trigger major version bump, got: $suggestion"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir" 