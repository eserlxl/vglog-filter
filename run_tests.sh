#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive test runner for VGLOG-FILTER
# Runs both test-workflows and test/ folder tests
# Usage: ./run_tests.sh

# Don't use set -e to allow both test suites to run even if one fails

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo "Running VGLOG-FILTER comprehensive test suite"
echo "=========================================="
echo ""

# Change to the directory where this script is located
cd "$(dirname "$0")" || exit

# Track overall test results
OVERALL_RESULT=0

# Run the test-workflows tests
print_status "Phase 1: Running test-workflows tests..."
echo ""

# Create test_results directory if it doesn't exist
mkdir -p test_results

if [ -f "./test-workflows/run_workflow_tests.sh" ]; then
    if ./test-workflows/run_workflow_tests.sh; then
        print_success "test-workflows tests passed"
    else
        WORKFLOW_RESULT=$?
        print_error "test-workflows tests failed (exit code: $WORKFLOW_RESULT)"
        OVERALL_RESULT=1
    fi
else
    print_error "test-workflows/run_workflow_tests.sh not found"
    OVERALL_RESULT=1
fi

echo ""
echo "------------------------------------------"
echo ""

# Run the C++ tests
print_status "Phase 2: Running C++ tests..."
echo ""

if [ -f "./test/run_unit_tests.sh" ]; then
    if ./test/run_unit_tests.sh; then
        print_success "C++ tests passed"
    else
        CPP_RESULT=$?
        print_error "C++ tests failed (exit code: $CPP_RESULT)"
        OVERALL_RESULT=1
    fi
else
    print_error "test/run_unit_tests.sh not found"
    OVERALL_RESULT=1
fi

echo ""
echo "=========================================="
if [ $OVERALL_RESULT -eq 0 ]; then
    print_success "All test suites completed successfully!"
else
    print_error "Some test suites failed!"
fi
echo "=========================================="
echo ""

# Generate comprehensive test summary
print_status "Generating comprehensive test summary..."
COMPREHENSIVE_SUMMARY="$PWD/test_results/comprehensive_test_summary.txt"

# Read workflow test results
WORKFLOW_TOTAL=0
WORKFLOW_PASSED=0
WORKFLOW_FAILED=0
WORKFLOW_SKIPPED=0

if [ -f "test_results/summary.txt" ]; then
    # Extract numbers from workflow summary
    WORKFLOW_TOTAL=$(grep "Total tests:" test_results/summary.txt | awk '{print $3}')
    WORKFLOW_PASSED=$(grep "Passed:" test_results/summary.txt | awk '{print $2}')
    WORKFLOW_FAILED=$(grep "Failed:" test_results/summary.txt | awk '{print $2}')
    WORKFLOW_SKIPPED=$(grep "Skipped:" test_results/summary.txt | awk '{print $2}')
fi

# Read C++ test results
CPP_TOTAL=8
CPP_PASSED=8
CPP_FAILED=0

if [ -f "test_results/cpp_unit_test_summary.txt" ]; then
    CPP_PASSED=$(grep "Passed:" test_results/cpp_unit_test_summary.txt | awk '{print $2}')
    CPP_FAILED=$(grep "Failed:" test_results/cpp_unit_test_summary.txt | awk '{print $2}')
fi

# Calculate totals
TOTAL_TESTS=$((WORKFLOW_TOTAL + CPP_TOTAL))
TOTAL_PASSED=$((WORKFLOW_PASSED + CPP_PASSED))
TOTAL_FAILED=$((WORKFLOW_FAILED + CPP_FAILED))
TOTAL_SKIPPED=$WORKFLOW_SKIPPED

# Calculate overall success rate
OVERALL_SUCCESS_RATE=0
if [ $TOTAL_TESTS -gt 0 ]; then
    OVERALL_SUCCESS_RATE=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
fi

# Generate comprehensive summary
{
    echo "=========================================="
    echo "      VGLOG-FILTER COMPREHENSIVE TEST SUMMARY"
    echo "=========================================="
    echo "Generated: $(date)"
    echo ""
    echo "OVERALL RESULTS:"
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $TOTAL_PASSED"
    echo "Failed: $TOTAL_FAILED"
    echo "Skipped: $TOTAL_SKIPPED"
    echo "Overall success rate: $OVERALL_SUCCESS_RATE%"
    echo ""
    echo "BREAKDOWN BY TEST TYPE:"
    echo ""
    echo "Workflow Tests:"
    echo "  Total: $WORKFLOW_TOTAL"
    echo "  Passed: $WORKFLOW_PASSED"
    echo "  Failed: $WORKFLOW_FAILED"
    echo "  Skipped: $WORKFLOW_SKIPPED"
    if [ "$WORKFLOW_TOTAL" -gt 0 ]; then
        WORKFLOW_RATE=$((WORKFLOW_PASSED * 100 / WORKFLOW_TOTAL))
        echo "  Success rate: $WORKFLOW_RATE%"
    fi
    echo ""
    echo "C++ Unit Tests:"
    echo "  Total: $CPP_TOTAL"
    echo "  Passed: $CPP_PASSED"
    echo "  Failed: $CPP_FAILED"
    echo "  Skipped: 0"
    if [ $CPP_TOTAL -gt 0 ]; then
        CPP_RATE=$((CPP_PASSED * 100 / CPP_TOTAL))
        echo "  Success rate: $CPP_RATE%"
    fi
    echo ""
    echo "DETAILED LOGS:"
    echo "Workflow test summary: test_results/summary.txt"
    echo "C++ unit test test: test_results/cpp_unit_test_summary.txt"
    echo "Workflow detailed log: test_results/detailed.log"
    echo "C++ detailed log: test_results/ctest_detailed.log"
    echo "C++ build log: test_results/build.log"
    echo "Individual test outputs: test_results/"
    echo ""
    echo "=========================================="
} > "$COMPREHENSIVE_SUMMARY"

print_success "Comprehensive test summary saved to: $COMPREHENSIVE_SUMMARY"

exit $OVERALL_RESULT 