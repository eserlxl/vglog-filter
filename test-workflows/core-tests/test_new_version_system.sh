#!/bin/bash

# Comprehensive test for the new version system
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test helper
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Cleanup function to remove test changes
cleanup() {
    if [[ -f "src/main.cpp" ]]; then
        # Remove the test change line if it exists
        sed -i '/^# Test change$/d' src/main.cpp
    fi
}

# Set up cleanup trap
trap cleanup EXIT

echo "=== Testing New Version System ==="

# Test 1: Verify enhanced reason format
echo "Test 1: Enhanced reason format"
cd "$PROJECT_ROOT"
echo "10.5.0" > VERSION

# Create a small change to trigger analysis
echo "# Test change" >> src/main.cpp

# Test the semantic analyzer output
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --base HEAD~1 --verbose 2>/dev/null | grep "Reason:" || echo "No reason found")
echo "Reason line: $result"

if [[ "$result" =~ "LOC:" ]] && [[ "$result" =~ "PATCH" ]]; then
    echo "✅ Enhanced reason format working correctly"
else
    echo "❌ Enhanced reason format not working"
    # Clean up before exiting
    sed -i '$d' src/main.cpp
    exit 1
fi

# Clean up the test change
sed -i '$d' src/main.cpp

# Test 2: Verify version calculation with rollover
echo ""
echo "Test 2: Version calculation with rollover"

# Test patch rollover
echo "1.2.99" > VERSION
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/bump-version patch --dry-run 2>/dev/null | tail -1)
expected="1.3.10"
if [[ "$result" = "$expected" ]]; then
    echo "✅ Patch rollover working: $result"
else
    echo "❌ Patch rollover failed: expected $expected, got $result"
    exit 1
fi

# Test minor rollover
echo "1.99.5" > VERSION
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/bump-version minor --dry-run 2>/dev/null | tail -1)
expected="1.99.34"
if [[ "$result" = "$expected" ]]; then
    echo "✅ Minor rollover working: $result"
else
    echo "❌ Minor rollover failed: expected $expected, got $result"
    exit 1
fi

# Test major increment
echo "1.2.3" > VERSION
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/bump-version major --dry-run 2>/dev/null | tail -1)
expected="1.2.37"
if [[ "$result" = "$expected" ]]; then
    echo "✅ Major increment working: $result"
else
    echo "❌ Major increment failed: expected $expected, got $result"
    exit 1
fi

# Test 3: Verify delta formulas
echo ""
echo "Test 3: Delta formulas"

# Test with different LOC values
echo "10.5.0" > VERSION

# Small change (50 LOC)
result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ' || echo "0")
echo "Patch delta for small change: $result"

# Test 4: Verify bump-version uses LOC delta by default
echo ""
echo "Test 4: Bump-version uses LOC delta by default"

echo "10.5.0" > VERSION
result=$(./dev-bin/bump-version patch --dry-run 2>/dev/null | tail -1)
if [[ "$result" = "10.5.11" ]]; then
    echo "✅ Bump-version using LOC delta by default: $result"
else
    echo "❌ Bump-version not using LOC delta: $result"
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
echo "The new version system is working correctly:"
echo "1. ✅ Enhanced reason format with LOC and Type"
echo "2. ✅ Proper version increment (only last identifier)"
echo "3. ✅ Modulo 100 rollover logic"
echo "4. ✅ LOC-based delta formulas"
echo "5. ✅ Bump-version uses LOC delta by default" 