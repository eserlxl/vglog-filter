#!/bin/bash
# Test for environment variable normalization
# Verifies that MAJOR_REQUIRE_BREAKING accepts various boolean values

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Testing environment variable normalization..."

# Test with MAJOR_REQUIRE_BREAKING=TRUE
echo "Testing MAJOR_REQUIRE_BREAKING=TRUE..."
result1=$(MAJOR_REQUIRE_BREAKING=TRUE ./dev-bin/semantic-version-analyzer --machine 2>/dev/null || true)
suggestion1=$(echo "$result1" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

# Test with MAJOR_REQUIRE_BREAKING=1
echo "Testing MAJOR_REQUIRE_BREAKING=1..."
result2=$(MAJOR_REQUIRE_BREAKING=1 ./dev-bin/semantic-version-analyzer --machine 2>/dev/null || true)
suggestion2=$(echo "$result2" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

# Test with MAJOR_REQUIRE_BREAKING=true (default)
echo "Testing MAJOR_REQUIRE_BREAKING=true (default)..."
result3=$(./dev-bin/semantic-version-analyzer --machine 2>/dev/null || true)
suggestion3=$(echo "$result3" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Results:"
echo "  TRUE: $suggestion1"
echo "  1:    $suggestion2"
echo "  true: $suggestion3"

# Verify that all results are identical
if [[ "$suggestion1" = "$suggestion2" ]] && [[ "$suggestion2" = "$suggestion3" ]]; then
    echo "✅ PASS: Environment variable normalization works correctly"
    exit_code=0
else
    echo "❌ FAIL: Environment variable normalization failed - results differ"
    echo "  Expected all to be identical, got: $suggestion1, $suggestion2, $suggestion3"
    exit_code=1
fi

exit $exit_code 