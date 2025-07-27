#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# vglog-filter build script
#
# Usage: ./build.sh [performance] [warnings] [debug] [clean] [tests]
#
# Modes:
#   performance : Enables performance optimizations (disables debug mode if both are set)
#   warnings    : Enables extra compiler warnings
#   debug       : Enables debug mode (disables performance mode if both are set)
#   clean       : Forces a clean build (removes all build artifacts)
#   tests       : Builds and runs the test suite
#
# Notes:
#   - 'performance' and 'debug' are mutually exclusive; enabling one disables the other.
#   - You can combine 'warnings' with either mode.
#   - 'clean' is useful for configuration changes or debugging build issues
#   - 'tests' will build the test suite and run basic tests
#   - Example: ./build.sh performance warnings
#   - Example: ./build.sh debug clean
#   - Example: ./build.sh tests

set -euo pipefail

PERFORMANCE_BUILD=OFF
WARNING_MODE=OFF
DEBUG_MODE=OFF
CLEAN_BUILD=OFF
BUILD_TESTS=OFF
RUN_TESTS=OFF

# Track if any valid arguments were provided
VALID_ARGS=false

for arg in "$@"; do
  case $arg in
    performance)
      PERFORMANCE_BUILD=ON
      VALID_ARGS=true
      ;;
    warnings)
      WARNING_MODE=ON
      VALID_ARGS=true
      ;;
    debug)
      DEBUG_MODE=ON
      VALID_ARGS=true
      ;;
    clean)
      CLEAN_BUILD=ON
      VALID_ARGS=true
      ;;
    tests)
      BUILD_TESTS=ON
      RUN_TESTS=ON
      VALID_ARGS=true
      ;;
    *)
      echo "Warning: Unknown argument '$arg' will be ignored"
      ;;
  esac
done

# If debug is ON, force performance OFF (mutually exclusive)
if [ "$DEBUG_MODE" = "ON" ]; then
  PERFORMANCE_BUILD=OFF
fi

if [ ! -d build ]; then
  mkdir build
fi
cd build

echo "Build configuration:"
echo "  PERFORMANCE_BUILD = $PERFORMANCE_BUILD"
echo "  WARNING_MODE     = $WARNING_MODE"
echo "  DEBUG_MODE       = $DEBUG_MODE"
echo "  CLEAN_BUILD      = $CLEAN_BUILD"
echo "  BUILD_TESTS      = $BUILD_TESTS"
echo "  RUN_TESTS        = $RUN_TESTS"

# Show warning if no valid arguments were provided
if [ "$VALID_ARGS" = "false" ] && [ $# -gt 0 ]; then
    echo "Warning: No valid build options specified. Using default configuration."
fi

cmake -DPERFORMANCE_BUILD=$PERFORMANCE_BUILD -DWARNING_MODE=$WARNING_MODE -DDEBUG_MODE=$DEBUG_MODE -DBUILD_TESTS=$BUILD_TESTS ..

if [ "$CLEAN_BUILD" = "ON" ]; then
  echo "Performing clean build..."
  make clean
fi

make -j"$(nproc)"

# Run tests if requested
if [ "$RUN_TESTS" = "ON" ]; then
    echo "Running tests..."
    
    # Clean up any leftover test files before running tests
    echo "Cleaning up any leftover test files..."
    find .. -name "*.tmp" -type f -delete 2>/dev/null || true
    
                 if [ -f "build/test_basic" ] && [ -f "build/test_integration" ] && [ -f "build/test_comprehensive" ]; then
                 ./build/test_basic
                 ./build/test_integration
                 ./build/test_comprehensive
                 echo "All tests completed successfully!"
             else
                 echo "Warning: Test executables not found. Tests may not have been built correctly."
                 echo "Attempting to build tests manually..."
                 g++ -std=c++17 -Wall -pedantic -Wextra -O2 ../test/test_basic.cpp -o test_basic
                 g++ -std=c++17 -Wall -pedantic -Wextra -O2 ../test/test_integration.cpp -o test_integration
                 g++ -std=c++17 -Wall -pedantic -Wextra -O2 ../test/test_comprehensive.cpp -o test_comprehensive
                 if [ -f "test_basic" ] && [ -f "test_integration" ] && [ -f "test_comprehensive" ]; then
                     ./test_basic
                     ./test_integration
                     ./test_comprehensive
                     echo "All tests completed successfully!"
                 else
                     echo "Error: Failed to build test executables."
                 fi
             fi
    
    # Clean up any test files that might have been left behind
    echo "Cleaning up test artifacts..."
    find .. -name "*.tmp" -type f -delete 2>/dev/null || true
fi 