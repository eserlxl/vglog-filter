#!/bin/bash
# Test for breaking case detection across C file extensions
# Verifies that removing a case in .c files triggers major version bump

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helper functions
source "$SCRIPT_DIR/../test_helper.sh"

echo "Testing breaking case detection across C file extensions..."

# Create temporary test environment
temp_dir=$(create_temp_test_env "breaking-case-detection")
cd "$temp_dir"

# Create a test C file with a switch statement
mkdir -p src
cat > src/test_switch.c << 'EOF'
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

git add src/test_switch.c
git commit -m "Add test C file with switch statement"

# Remove a case (breaking change)
cat > src/test_switch.c << 'EOF'
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

git add src/test_switch.c
git commit -m "Remove case 2 (breaking change)"

# Run semantic version analyzer from the original project directory
result=$(cd "$PROJECT_ROOT" && ./dev-bin/semantic-version-analyzer --machine --repo-root "$temp_dir" --base HEAD~1 --target HEAD 2>/dev/null || true)

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
cleanup_temp_test_env "$temp_dir"

exit $exit_code
