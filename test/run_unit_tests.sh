#!/bin/bash

# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.

# VGLOG-FILTER C++ Unit Test Runner
# This script builds and runs all C++ unit tests using CMake and CTest

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to count C++ tests by parsing CMakeLists.txt
count_cpp_tests() {
    local cmake_file="$PROJECT_ROOT/CMakeLists.txt"
    if [ ! -f "$cmake_file" ]; then
        echo "Error: CMakeLists.txt not found at $cmake_file" >&2
        return 1
    fi
    
    # Count add_test_exe lines in CMakeLists.txt
    local count
    count=$(grep -c "^[[:space:]]*add_test_exe(" "$cmake_file" 2>/dev/null || echo "0")
    echo "$count"
}

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/test"
BUILD_DIR="$PROJECT_ROOT/build-test"

# Ensure we're in the project root
cd "$PROJECT_ROOT"

# Count C++ tests automatically
CPP_TOTAL=$(count_cpp_tests)
if [ "$CPP_TOTAL" -eq 0 ]; then
    echo "Warning: No C++ tests found in CMakeLists.txt" >&2
    CPP_TOTAL=0
fi

echo "[INFO] Running VGLOG-FILTER C++ UNIT TEST SUITE..."
echo "[INFO] Project root: $PROJECT_ROOT"
echo "[INFO] Test directory: $TEST_DIR"
echo "[INFO] Found $CPP_TOTAL C++ test(s) in CMakeLists.txt"

# Create test results directory
mkdir -p "$PROJECT_ROOT/test_results"

# Build configuration
echo "[INFO] Configuring CMake with testing enabled..."
if ! cmake -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON -DENABLE_SANITIZERS=ON -DWARNING_MODE=ON > "$PROJECT_ROOT/test_results/cmake_config.log" 2>&1; then
    echo "[ERROR] CMake configuration failed. Check $PROJECT_ROOT/test_results/cmake_config.log"
    exit 1
fi
echo "[SUCCESS] CMake configuration completed"

# Build tests
echo "[INFO] Building tests..."
if ! cmake --build "$BUILD_DIR" --config Debug --parallel > "$PROJECT_ROOT/test_results/build.log" 2>&1; then
    echo "[ERROR] Build failed. Check $PROJECT_ROOT/test_results/build.log"
    exit 1
fi
echo "[SUCCESS] Build completed"

# Run tests with CTest
echo "[INFO] Running tests with CTest..."
CTEST_LOG="$PROJECT_ROOT/test_results/ctest_detailed.log"
BUILD_LOG="$PROJECT_ROOT/test_results/build.log"

ctest_exit_code=0
ctest --test-dir "$BUILD_DIR" --output-on-failure -T Test > "$CTEST_LOG" 2>&1 || ctest_exit_code=$?

# Parse CTest output for individual test results
CPP_PASSED=$(grep -c "Passed" "$CTEST_LOG")
CPP_FAILED=$(grep -c "Failed" "$CTEST_LOG")

if [ "$ctest_exit_code" -ne 0 ] || [ "$CPP_FAILED" -gt 0 ]; then
    echo "[ERROR] CTest failed. Check $CTEST_LOG"
    TEST_RESULT=1
else
    echo ""
    echo "[SUCCESS] All tests passed!"
    TEST_RESULT=0
fi

# Generate C++ test summary
CPP_SUMMARY_FILE="$PROJECT_ROOT/test_results/cpp_unit_test_summary.txt"

echo ""
echo "=========================================="
echo "           C++ UNIT TEST SUMMARY"
echo "=========================================="
echo "Total tests: $CPP_TOTAL"
echo -e "Passed: ${GREEN}$CPP_PASSED${NC}"
echo -e "Failed: ${RED}$CPP_FAILED${NC}"
echo -e "Skipped: ${YELLOW}0${NC}"

# Calculate success rate for the summary output
CPP_SUCCESS_RATE=0
if [ "$CPP_TOTAL" -gt 0 ]; then
    CPP_SUCCESS_RATE=$((CPP_PASSED * 100 / CPP_TOTAL))
fi
echo "Success rate: $CPP_SUCCESS_RATE%"

echo ""
echo "Summary saved to: $CPP_SUMMARY_FILE"
echo "Detailed log: $CTEST_LOG"
echo "Individual test outputs: $PROJECT_ROOT/test_results/"

# Save C++ test summary to file
{
    echo "VGLOG-FILTER C++ UNIT TEST SUITE SUMMARY"
    echo "Generated: $(date)"
    echo ""
    echo "Total tests: $CPP_TOTAL"
    echo "Passed: $CPP_PASSED"
    echo "Failed: $CPP_FAILED"
    echo "Skipped: 0"
    echo "Success rate: $CPP_SUCCESS_RATE%"
    echo ""
    echo "Detailed results available in: $CTEST_LOG"
    echo "Build logs available in: $BUILD_LOG"
    echo "Individual test outputs available in: $PROJECT_ROOT/test_results/"
} > "$CPP_SUMMARY_FILE"

exit $TEST_RESULT