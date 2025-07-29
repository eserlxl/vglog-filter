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

set -e

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
cd "$(dirname "$0")"

# Track overall test results
OVERALL_RESULT=0

# Run the test-workflows tests
print_status "Phase 1: Running test-workflows tests..."
echo ""

if [ -f "./test-workflows/run_workflow_tests.sh" ]; then
    ./test-workflows/run_workflow_tests.sh
    WORKFLOW_RESULT=$?
    if [ $WORKFLOW_RESULT -ne 0 ]; then
        print_error "test-workflows tests failed"
        OVERALL_RESULT=1
    else
        print_success "test-workflows tests passed"
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
    ./test/run_unit_tests.sh
    CPP_RESULT=$?
    if [ $CPP_RESULT -ne 0 ]; then
        print_error "C++ tests failed"
        OVERALL_RESULT=1
    else
        print_success "C++ tests passed"
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

exit $OVERALL_RESULT 