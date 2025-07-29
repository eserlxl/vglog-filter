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
# Usage: ./test/run_all_tests.sh

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

print_status "Running VGLOG-FILTER C++ test suite..."
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
if ! cmake .. \
    -DBUILD_TESTING=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWARNING_MODE=ON \
    -DDEBUG_MODE=ON \
    -DPERFORMANCE_BUILD=OFF \
    -DENABLE_SANITIZERS=ON; then
    print_error "CMake configuration failed"
    exit 1
fi

print_success "CMake configuration completed"

# Build tests
print_status "Building tests..."
if ! make -j20; then
    print_error "Build failed"
    exit 1
fi

print_success "Build completed"

# Run tests
print_status "Running tests with CTest..."
echo ""

# Run tests with verbose output
ctest --output-on-failure --verbose

TEST_RESULT=$?

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    print_success "All tests passed!"
else
    print_error "Some tests failed!"
fi

# Also run individual test executables for more detailed output
print_status "Running individual test executables for detailed output..."
echo ""

# Find and run all test executables
for test_exe in test_*; do
    if [ -f "$test_exe" ] && [ -x "$test_exe" ]; then
        print_status "Running $test_exe..."
        if ./"$test_exe"; then
            print_success "$test_exe passed"
        else
            print_error "$test_exe failed"
        fi
        echo ""
    fi
done

# Return to original directory
cd "$PROJECT_ROOT"

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    print_success "C++ test suite completed successfully!"
    exit 0
else
    print_error "C++ test suite failed!"
    exit 1
fi 