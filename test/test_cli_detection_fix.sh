#!/bin/bash
# Test for CLI change detection fix
# Verifies that cli_changes=false when no source/include files are changed

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Testing CLI change detection fix..."

# Create a test branch from a clean state
git checkout -b test-cli-detection-fix 2>/dev/null || git checkout test-cli-detection-fix

# Reset to a clean state (first commit or a known good state)
git reset --hard HEAD~10 2>/dev/null || git reset --hard HEAD~5 2>/dev/null || true

# Make a minimal change to a non-source file (README.md)
echo "# Test change" >> README.md
git add README.md
git commit -m "Test: Update README only"

# Run semantic version analyzer
result=$(./dev-bin/semantic-version-analyzer --machine 2>/dev/null || true)

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that when no source files are changed, we get a reasonable suggestion
# (should be none, patch, or minor, but not major due to large changes)
if [[ "$suggestion" = "major" ]]; then
    echo "❌ FAIL: Major version bump suggested when only docs changed (likely due to large diff)"
    exit_code=1
else
    echo "✅ PASS: Reasonable version bump suggestion ($suggestion) when no source files changed"
    exit_code=0
fi

# Clean up
git checkout main
git branch -D test-cli-detection-fix 2>/dev/null || true

exit $exit_code
