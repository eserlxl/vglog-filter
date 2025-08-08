#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Dedicated test runner for LOC-based delta system tests
# This script runs all LOC delta related tests with enhanced error handling

set -Euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to log test results
log_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✓ $test_name: $message${NC}"
            ((PASSED_TESTS++))
            ;;
        "FAIL")
            echo -e "${RED}✗ $test_name: $message${NC}"
            ((FAILED_TESTS++))
            ;;
        "SKIP")
            echo -e "${YELLOW}⚠ $test_name: $message${NC}"
            ((SKIPPED_TESTS++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ $test_name: $message${NC}"
            ;;
    esac
    ((TOTAL_TESTS++))
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${CYAN}=== Checking Prerequisites ===${NC}"
    
    # Check for required tools
    local missing_tools=()
    
    for tool in git jq yq bash; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        return 1
    fi
    
    # Check for required scripts
    local missing_scripts=()
    local required_scripts=(
        "dev-bin/semantic-version-analyzer.sh"
        "dev-bin/version-calculator.sh"
        "dev-bin/mathematical-version-bump.sh"
        "dev-bin/version-calculator-loc.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -x "$SCRIPT_DIR/../$script" ]]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required scripts: ${missing_scripts[*]}${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites satisfied${NC}"
    return 0
}

# Function to run a test file with enhanced error handling
run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file")
    
    echo -e "${CYAN}Running $test_name...${NC}"
    
    # Check if file exists
    if [[ ! -f "$test_file" ]]; then
        log_test_result "$test_name" "SKIP" "file not found"
        return
    fi
    
    # Make executable if needed
    if [[ ! -x "$test_file" ]]; then
        chmod +x "$test_file" 2>/dev/null || true
    fi
    
    # Change to the script directory before running the test
    cd "$SCRIPT_DIR" || exit 1
    
    # Run the test with timeout and capture output
    local output
    local exit_code
    output=$(timeout 120 bash "$test_file" 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_test_result "$test_name" "PASS" "completed successfully"
    elif [[ $exit_code -eq 124 ]]; then
        log_test_result "$test_name" "FAIL" "timed out after 120 seconds"
    else
        log_test_result "$test_name" "FAIL" "exited with code $exit_code"
        echo -e "${YELLOW}Test output:${NC}"
        echo "${output//^/  }"
    fi
}

# Function to run system validation tests
run_system_validation() {
    echo -e "${CYAN}=== System Validation Tests ===${NC}"
    
    # Test 1: Check versioning configuration
    local config_file="$SCRIPT_DIR/../dev-config/versioning.yml"
    if [[ -f "$config_file" ]]; then
        if yq '.' "$config_file" >/dev/null 2>&1; then
            log_test_result "Versioning Config" "PASS" "valid YAML configuration"
        else
            log_test_result "Versioning Config" "FAIL" "invalid YAML configuration"
        fi
    else
        log_test_result "Versioning Config" "SKIP" "configuration file not found"
    fi
    
    # Test 2: Check semantic analyzer functionality
    local analyzer_script="$SCRIPT_DIR/../dev-bin/semantic-version-analyzer.sh"
    if [[ -x "$analyzer_script" ]]; then
        if "$analyzer_script" --help >/dev/null 2>&1; then
            log_test_result "Semantic Analyzer" "PASS" "script is executable and functional"
        else
            log_test_result "Semantic Analyzer" "FAIL" "script failed to run"
        fi
    else
        log_test_result "Semantic Analyzer" "SKIP" "script not found or not executable"
    fi
    
    # Test 3: Check version calculator functionality
    local calculator_script="$SCRIPT_DIR/../dev-bin/version-calculator.sh"
    if [[ -x "$calculator_script" ]]; then
        if "$calculator_script" --help >/dev/null 2>&1; then
            log_test_result "Version Calculator" "PASS" "script is executable and functional"
        else
            log_test_result "Version Calculator" "FAIL" "script failed to run"
        fi
    else
        log_test_result "Version Calculator" "SKIP" "script not found or not executable"
    fi
}

# Main execution
echo "=========================================="
echo "    LOC-BASED DELTA SYSTEM TEST SUITE"
echo "=========================================="
echo ""

echo "Starting LOC delta system tests at $(date)"
echo ""

# Check prerequisites first
if ! check_prerequisites; then
    echo -e "${RED}Prerequisites check failed. Exiting.${NC}"
    exit 1
fi

# Run system validation tests
run_system_validation

# Run LOC delta specific tests
echo ""
echo -e "${CYAN}=== Core LOC Delta Tests ===${NC}"
run_test "$SCRIPT_DIR/core-tests/test_loc_delta_system.sh"
run_test "$SCRIPT_DIR/core-tests/test_loc_delta_system_comprehensive.sh"
run_test "$SCRIPT_DIR/core-tests/test_bump_version_loc_delta.sh"
run_test "$SCRIPT_DIR/core-tests/test_versioning_system_integration.sh"

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
echo -e "Skipped: ${YELLOW}$SKIPPED_TESTS${NC}"

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
echo "  - test_versioning_system_integration.sh (new versioning system integration)"
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