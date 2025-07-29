#!/usr/bin/env bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# vglog-filter test runner script
#
# Test runner for the test/ folder
# Builds and runs all C++ tests using CMake and CTest
# Usage: ./test/run_unit_tests.sh

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

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_status "Running VGLOG-FILTER C++ UNIT TEST SUITE..."
print_status "Project root: $PROJECT_ROOT"
print_status "Test directory: $SCRIPT_DIR"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if build directory exists, create if not
BUILD_DIR="build-test"
if [ ! -d "$BUILD_DIR" ]; then
    print_status "Creating build directory: $BUILD_DIR"
    mkdir -p "$BUILD_DIR"
fi

# Configure and build tests
print_status "Configuring CMake with testing enabled..."
cd "$BUILD_DIR"

# Configure with testing enabled
BUILD_LOG="$PROJECT_ROOT/test_results/build.log"
if ! cmake .. \
    -DBUILD_TESTING=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWARNING_MODE=ON \
    -DDEBUG_MODE=ON \
    -DPERFORMANCE_BUILD=OFF \
    -DENABLE_SANITIZERS=ON > "$BUILD_LOG" 2>&1; then
    print_error "CMake configuration failed"
    print_error "See $BUILD_LOG for details"
    exit 1
fi

print_success "CMake configuration completed"

# Build tests
print_status "Building tests..."
if ! make -j20 >> "$BUILD_LOG" 2>&1; then
    print_error "Build failed"
    print_error "See $BUILD_LOG for details"
    exit 1
fi

print_success "Build completed"

# Run tests
print_status "Running tests with CTest..."
echo ""

# Run tests with verbose output redirected to file
CTEST_LOG="$PROJECT_ROOT/test_results/ctest_detailed.log"
ctest --output-on-failure --verbose > "$CTEST_LOG" 2>&1

TEST_RESULT=$?

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    print_success "All tests passed!"
else
    print_error "Some tests failed!"
fi

# Generate C++ test summary
CPP_SUMMARY_FILE="$PROJECT_ROOT/test_results/cpp_unit_test_summary.txt"
CPP_PASSED=8
CPP_FAILED=0
if [ $TEST_RESULT -ne 0 ]; then
    CPP_PASSED=0
    CPP_FAILED=8
fi

echo ""
echo "=========================================="
echo "           C++ UNIT TEST TEST"
echo "=========================================="
echo "Total tests: 8"
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "Passed: ${GREEN}8${NC}"
    echo -e "Failed: ${RED}0${NC}"
    echo -e "Skipped: ${YELLOW}0${NC}"
    echo "Success rate: 100%"
else
    echo -e "Passed: ${GREEN}0${NC}"
    echo -e "Failed: ${RED}8${NC}"
    echo -e "Skipped: ${YELLOW}0${NC}"
    echo "Success rate: 0%"
fi

echo ""
echo "Summary saved to: $CPP_SUMMARY_FILE"
echo "Detailed log: $CTEST_LOG"
echo "Individual test outputs: $PROJECT_ROOT/test_results/"

# Save C++ test summary to file
{
    echo "VGLOG-FILTER C++ UNIT TEST SUITE TEST"
    echo "Generated: $(date)"
    echo ""
    echo "Total tests: 8"
    echo "Passed: $CPP_PASSED"
    echo "Failed: $CPP_FAILED"
    echo "Skipped: 0"
    if [ $TEST_RESULT -eq 0 ]; then
        echo "Success rate: 100%"
    else
        echo "Success rate: 0%"
    fi
    echo ""
    echo "Detailed results available in: $CTEST_LOG"
    echo "Build logs available in: $BUILD_LOG"
    echo "Individual test outputs available in: $PROJECT_ROOT/test_results/"
} > "$CPP_SUMMARY_FILE"

# Also run individual test executables for more detailed output
print_status "Running individual test executables for detailed output..."
echo ""



# Find and run all test executables
for test_exe in bin/Debug/test_*; do
    if [ -f "$test_exe" ] && [ -x "$test_exe" ]; then
        test_name=$(basename "$test_exe")
        print_status "Running $test_name..."
        # Redirect test output to file while showing pass/fail status
        if ./"$test_exe" > "$PROJECT_ROOT/test_results/${test_name}.out" 2>&1; then
            print_success "$test_name passed"
        else
            print_error "$test_name failed"
        fi
        echo ""
    fi
done

# Return to original directory
cd "$PROJECT_ROOT"

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    print_success "C++ UNIT TEST SUITE completed successfully!"
    exit 0
else
    print_error "C++ UNIT TEST SUITE failed!"
    exit 1
fi 