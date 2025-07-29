#!/bin/bash
# Test for breaking case detection across C file extensions
# Verifies that removing a case in .c files triggers major version bump

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Testing breaking case detection across C file extensions..."

# Create a test branch
git checkout -b test-breaking-case-detection 2>/dev/null || git checkout test-breaking-case-detection

# Create a test C file with a switch statement
cat > test-workflows/source-fixtures/test_switch.c << 'EOF'
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

git add test-workflows/source-fixtures/test_switch.c
git commit -m "Add test C file with switch statement"

# Remove a case (breaking change)
cat > test-workflows/source-fixtures/test_switch.c << 'EOF'
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

git add test-workflows/source-fixtures/test_switch.c
git commit -m "Remove case 2 (breaking change)"

# Run semantic version analyzer
result=$(./dev-bin/semantic-version-analyzer --machine 2>/dev/null || true)

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
git checkout main
git branch -D test-breaking-case-detection 2>/dev/null || true
rm -f test-workflows/source-fixtures/test_switch.c

exit $exit_code
