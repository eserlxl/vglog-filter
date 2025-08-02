#!/bin/bash

# Test script for version calculation logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test helper
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Test function to verify version calculation
test_version_calculation() {
    local current_version="$1"
    local bump_type="$2"
    local expected_delta="$3"
    local expected_result="$4"
    local test_name="$5"
    
    echo "Testing: $test_name"
    echo "  Current: $current_version"
    echo "  Bump type: $bump_type"
    echo "  Expected delta: $expected_delta"
    echo "  Expected result: $expected_result"
    
    # Create temporary test environment
    local temp_dir
    temp_dir=$(create_temp_test_env "version_calc_${current_version//./_}")
    
    # Set up test environment
    cd "$temp_dir"
    echo "$current_version" > VERSION
    git add VERSION
    git commit --quiet -m "Set version to $current_version" 2>/dev/null || true
    
    # Mock the LOC delta calculation by setting environment variables
    export VERSION_USE_LOC_DELTA=true
    export R_diff_size=100  # Mock LOC value
    
    # Test the bump-version script's version calculation
    local result
    result=$(VERSION_USE_LOC_DELTA=true "$PROJECT_ROOT/dev-bin/bump-version" "$bump_type" --print --repo-root "$temp_dir" 2>/dev/null | tail -1)
    
    echo "  Actual result: $result"
    
    # Cleanup
    cleanup_temp_test_env "$temp_dir"
    
    if [[ "$result" = "$expected_result" ]]; then
        echo "  ✅ PASS"
        return 0
    else
        echo "  ❌ FAIL: Expected $expected_result, got $result"
        return 1
    fi
}

# Test cases
echo "=== Testing Version Calculation Logic ==="

# Test 1: Simple patch increment
test_version_calculation "1.2.3" "patch" "1" "1.2.4" "Simple patch increment"

# Test 2: Patch rollover
test_version_calculation "1.2.99" "patch" "5" "1.3.0" "Patch rollover (99 + 1 = 100, becomes 1.3.0)"

# Test 3: Minor increment
test_version_calculation "1.2.3" "minor" "5" "1.7.0" "Minor increment (2 + 5 = 7, patch reset to 0)"

# Test 4: Minor rollover
test_version_calculation "1.99.5" "minor" "10" "2.4.0" "Minor rollover (99 + 5 = 104, becomes 2.4.0)"

# Test 5: Major increment
test_version_calculation "1.2.3" "major" "10" "11.0.0" "Major increment (1 + 10 = 11, others reset to 0)"

# Test 6: Double rollover
test_version_calculation "1.99.99" "patch" "5" "2.0.0" "Double rollover (99 + 1 = 100, becomes 2.0.0)"

echo "=== All tests completed ===" 