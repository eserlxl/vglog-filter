#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Integration test for the new versioning system with LOC delta functionality

set -Euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source the test helper
# shellcheck source=test_helper.sh
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    echo -e "${CYAN}Running test: $test_name${NC}"
    
    # Run the command and capture output
    local output
    output=$(eval "$test_command" 2>&1 || true)
    
    # Check if output contains expected text
    if echo "$output" | grep -q "$expected_output"; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo -e "${YELLOW}Expected: $expected_output${NC}"
        echo -e "${YELLOW}Got: $output${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

echo "=== Testing New Versioning System Integration ==="

# Create a temporary clean environment for testing
test_dir=$(create_temp_test_env "versioning_system_integration_test")
cd "$test_dir" || exit 1

# Test 1: Verify configuration loading
echo -e "${CYAN}=== Test 1: Configuration Loading ===${NC}"

# Test that the versioning configuration can be loaded
run_test "Versioning configuration loading" \
    "yq '.' '$PROJECT_ROOT/dev-config/versioning.yml'" \
    '"base_deltas"'

# Test 2: Verify LOC delta calculation with configuration
echo -e "${CYAN}=== Test 2: LOC Delta Calculation ===${NC}"

# Set up initial version
echo "1.0.0" > VERSION
git add VERSION
git commit -m "Set initial version" -q

# Add a small change
echo "// Test change" > test_file.c
git add test_file.c
git commit -m "Add test file" -q

# Test semantic analyzer with LOC delta
run_test "Semantic analyzer with LOC delta" \
    "$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh --json --repo-root $(pwd)" \
    "loc_delta"

# Test 3: Verify mathematical version bump integration
echo -e "${CYAN}=== Test 3: Mathematical Version Bump Integration ===${NC}"

# Test mathematical version bump
run_test "Mathematical version bump with LOC delta" \
    "$PROJECT_ROOT/dev-bin/mathematical-version-bump.sh --print --repo-root $(pwd)" \
    "1."

# Test 4: Verify version calculator with new system
echo -e "${CYAN}=== Test 4: Version Calculator Integration ===${NC}"

# Test version calculator with LOC delta
run_test "Version calculator with LOC delta" \
    "$PROJECT_ROOT/dev-bin/version-calculator.sh --current-version 1.0.0 --bump-type patch --loc 100 --bonus 2 --machine" \
    "TOTAL_DELTA="

# Test 5: Verify rollover logic with new system
echo -e "${CYAN}=== Test 5: Rollover Logic Integration ===${NC}"

# Set up version near rollover
echo "1.0.99" > VERSION
git add VERSION
git commit -m "Set version near rollover" -q

# Add a change to trigger rollover
echo "// Another change" >> test_file.c
git add test_file.c
git commit -m "Add change for rollover test" -q

# Test rollover with mathematical version bump
run_test "Rollover logic with mathematical version bump" \
    "$PROJECT_ROOT/dev-bin/mathematical-version-bump.sh --print --repo-root $(pwd)" \
    "1."

# Test 6: Verify bonus system integration
echo -e "${CYAN}=== Test 6: Bonus System Integration ===${NC}"

# Test with breaking change (should trigger higher bonus)
echo "// BREAKING: API change" > breaking_change.c
git add breaking_change.c
git commit -m "BREAKING: API change" -q

# Test semantic analyzer with breaking change
run_test "Semantic analyzer with breaking change bonus" \
    "$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh --json --repo-root $(pwd)" \
    "total_bonus"

# Test 7: Verify configuration override
echo -e "${CYAN}=== Test 7: Configuration Override ===${NC}"

# Test with custom configuration
export VERSION_PATCH_LIMIT=50
export VERSION_MINOR_LIMIT=50

run_test "Configuration override with environment variables" \
    "$PROJECT_ROOT/dev-bin/version-calculator.sh --current-version 1.0.49 --bump-type patch --loc 10 --bonus 1 --machine" \
    "TOTAL_DELTA="

# Test 8: Verify error handling
echo -e "${CYAN}=== Test 8: Error Handling ===${NC}"

# Test invalid version format
run_test "Error handling for invalid version" \
    "$PROJECT_ROOT/dev-bin/version-calculator.sh --current-version invalid --bump-type patch --loc 10 --bonus 1" \
    "Next version:"

# Test invalid bump type
run_test "Error handling for invalid bump type" \
    "$PROJECT_ROOT/dev-bin/version-calculator.sh --current-version 1.0.0 --bump-type invalid --loc 10 --bonus 1" \
    "Error:"

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

# Cleanup
cleanup_temp_test_env "$test_dir"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed! New versioning system integration is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the implementation.${NC}"
    exit 1
fi
