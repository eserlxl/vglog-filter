#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test runner for all tests in test-workflows directory
# This script executes all test files and provides a summary of results

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Fixed output directory
TEST_OUTPUT_DIR="test_results"
SUMMARY_FILE="$TEST_OUTPUT_DIR/summary.txt"
DETAILED_LOG="$TEST_OUTPUT_DIR/detailed.log"

# Clean and recreate output directory
rm -rf "$TEST_OUTPUT_DIR"
mkdir -p "$TEST_OUTPUT_DIR"

echo "=========================================="
echo "    VGLOG-FILTER WORKFLOW TEST SUITE"
echo "=========================================="
echo "Output directory: $TEST_OUTPUT_DIR"
echo "Summary file: $SUMMARY_FILE"
echo "Detailed log: $DETAILED_LOG"
echo ""

# Function to log test results
log_test() {
    local test_name="$1"
    local status="$2"
    local output="$3"
    
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $test_name: $status"
        if [[ -n "$output" ]]; then
            echo "Output:"
            echo "$output"
            echo "---"
        fi
    } >> "$DETAILED_LOG"
}

# Function to run a test file
run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file")
    
    # Skip this script itself to prevent recursion
    if [[ "$test_file" == *"run_workflow_tests.sh" ]]; then
        return
    fi
    
    echo -n "Running $test_name... "
    
    # Check if file exists
    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}SKIPPED (file not found)${NC}"
        log_test "$test_name" "SKIPPED" "File not found"
        ((SKIPPED_TESTS++))
        ((TOTAL_TESTS++))
        return
    fi
    
    # Run the test based on file type
    if [[ "$test_file" == *.sh ]]; then
        # Shell script test
        if [[ ! -x "$test_file" ]]; then
            chmod +x "$test_file" 2>/dev/null || true
        fi
        
        # Run with timeout and capture output
        local output_file="$TEST_OUTPUT_DIR/${test_name}.out"
        timeout 30s bash "$test_file" > "$output_file" 2>&1
        local exit_code=$?
        
        # Check if this is a test that returns a specific exit code (like test_func.sh)
        if [[ "$test_name" == "test_func.sh" ]] && [[ $exit_code -eq 20 ]]; then
            echo -e "${GREEN}PASSED${NC}"
            log_test "$test_name" "PASSED" "$(cat "$output_file")"
            ((PASSED_TESTS++))
        elif [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}PASSED${NC}"
            log_test "$test_name" "PASSED" "$(cat "$output_file")"
            ((PASSED_TESTS++))
        else
            echo -e "${RED}FAILED${NC}"
            log_test "$test_name" "FAILED" "$(cat "$output_file")"
            ((FAILED_TESTS++))
        fi
    elif [[ "$test_file" == *.c ]]; then
        # C file test - compile and run if possible
        local test_bin="$TEST_OUTPUT_DIR/${test_name%.c}"
        local output_file="$TEST_OUTPUT_DIR/${test_name}.out"
        
        if gcc -o "$test_bin" "$test_file" > "$output_file" 2>&1; then
            if timeout 30s "$test_bin" > "$output_file" 2>&1; then
                echo -e "${GREEN}PASSED${NC}"
                log_test "$test_name" "PASSED" "$(cat "$output_file")"
                ((PASSED_TESTS++))
            else
                echo -e "${RED}FAILED${NC}"
                log_test "$test_name" "FAILED" "$(cat "$output_file")"
                ((FAILED_TESTS++))
            fi
        else
            echo -e "${YELLOW}SKIPPED (compilation failed)${NC}"
            log_test "$test_name" "SKIPPED" "Compilation failed: $(cat "$output_file")"
            ((SKIPPED_TESTS++))
        fi
    else
        echo -e "${YELLOW}SKIPPED (unknown file type)${NC}"
        log_test "$test_name" "SKIPPED" "Unknown file type"
        ((SKIPPED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
}

# Function to run tests in a directory
run_tests_in_directory() {
    local dir="$1"
    local dir_name
    dir_name=$(basename "$dir")
    
    if [[ ! -d "$dir" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BLUE}=== Testing $dir_name ===${NC}"
    
    # Find all test files in the directory, excluding this script
    local test_files
    mapfile -t test_files < <(find "$dir" -maxdepth 1 -type f \( -name "test_*" -o -name "*.sh" -o -name "*.c" \) -not -name "run_workflow_tests.sh" | sort)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "No test files found in $dir_name"
        return
    fi
    
    for test_file in "${test_files[@]}"; do
        run_test "$test_file"
    done
}

# Main execution
echo "Starting test execution at $(date)"
echo ""

# Run tests in each subdirectory
run_tests_in_directory "test-workflows/core-tests"
run_tests_in_directory "test-workflows/file-handling-tests"
run_tests_in_directory "test-workflows/edge-case-tests"
run_tests_in_directory "test-workflows/utility-tests"
run_tests_in_directory "test-workflows/cli-tests"
run_tests_in_directory "test-workflows/debug-tests"
run_tests_in_directory "test-workflows/ere-tests"
run_tests_in_directory "test-workflows"

# Generate summary
echo ""
echo "=========================================="
echo "          WORKFLOW TEST SUMMARY"
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

# Save summary to file
{
    echo "VGLOG-FILTER WORKFLOW TEST SUITE SUMMARY"
    echo "Generated: $(date)"
    echo ""
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Skipped: $SKIPPED_TESTS"
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        echo "Success rate: $success_rate%"
    fi
    echo ""
    echo "Detailed results available in: $DETAILED_LOG"
    echo "Test outputs available in: $TEST_OUTPUT_DIR/"
} > "$SUMMARY_FILE"

echo ""
echo "Summary saved to: $SUMMARY_FILE"
echo "Detailed log: $DETAILED_LOG"
echo "Test outputs: $TEST_OUTPUT_DIR/"

# Exit with appropriate code
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi 