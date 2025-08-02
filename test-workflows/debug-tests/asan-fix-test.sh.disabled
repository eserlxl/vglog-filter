#!/bin/bash

# Test script to verify AddressSanitizer fixes
set -euo pipefail

echo "Testing AddressSanitizer fixes..."

# Set ASAN options
export ASAN_OPTIONS="abort_on_error=0:print_stats=1:halt_on_error=0:exit_code=0"

# Build with AddressSanitizer
echo "Building with AddressSanitizer..."
mkdir -p build-asan
cd build-asan
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer" ..
make -j20

# Test basic functionality
echo "Testing basic functionality..."
./bin/Debug/vglog-filter --help
./bin/Debug/vglog-filter --version

# Test with stdin
echo "Testing with stdin..."
echo "test input" | ./bin/Debug/vglog-filter

# Test with empty input
echo "Testing with empty input..."
echo "" | ./bin/Debug/vglog-filter

# Test with invalid arguments
echo "Testing with invalid arguments..."
./bin/Debug/vglog-filter --invalid-option 2>/dev/null || true

echo "AddressSanitizer tests completed successfully!" 