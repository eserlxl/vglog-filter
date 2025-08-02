#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Dedicated test runner for LOC-based delta system tests
# This script runs all LOC delta related tests

set -Euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "=========================================="
echo "    LOC-BASED DELTA SYSTEM TEST SUITE"
echo "=========================================="
echo ""

# Function to run a test file
run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file")
    
    echo -n "Running $test_name... "
    
    # Check if file exists
    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}SKIPPED (file not found)${NC}"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
        return
    fi
    
    # Make executable if needed
    if [[ ! -x "$test_file" ]]; then
        chmod +x "$test_file" 2>/dev/null || true
    fi
    
    # Change to the script directory before running the test
    cd "$SCRIPT_DIR" || exit 1
    
    # Run the test
    if bash "$test_file" >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}FAILED${NC}"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
}

# Main execution
echo "Starting LOC delta system tests at $(date)"
echo ""

# Run LOC delta specific tests
echo -e "${CYAN}=== Core LOC Delta Tests ===${NC}"
run_test "$SCRIPT_DIR/core-tests/test_loc_delta_system.sh"
run_test "$SCRIPT_DIR/core-tests/test_loc_delta_system_comprehensive.sh"
run_test "$SCRIPT_DIR/core-tests/test_bump_version_loc_delta.sh"

# Note: Other tests are run by the main test suite
echo ""
echo -e "${CYAN}=== Note ===${NC}"
echo "Other tests (test_semantic_version_analyzer.sh, test_bump_version.sh) are"
echo "run by the main test suite and include LOC delta functionality."

# Generate summary
echo ""
echo "=========================================="
echo "          LOC DELTA TEST SUMMARY"
echo "=========================================="
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

# Calculate success rate
if [[ $TOTAL_TESTS -gt 0 ]]; then
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo "Success rate: $success_rate%"
fi

echo ""
echo "Test files run:"
echo "  - test_loc_delta_system.sh (basic demonstration)"
echo "  - test_loc_delta_system_comprehensive.sh (comprehensive tests)"
echo "  - test_bump_version_loc_delta.sh (bump-version integration)"
echo "  - test_semantic_version_analyzer.sh (updated with LOC delta tests)"
echo "  - test_bump_version.sh (updated with LOC delta tests)"

# Exit with appropriate code
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo ""
    echo -e "${RED}Some LOC delta tests failed!${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All LOC delta tests passed!${NC}"
    exit 0
fi 