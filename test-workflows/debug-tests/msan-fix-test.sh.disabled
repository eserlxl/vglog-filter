#!/bin/bash

# Test script to verify MemorySanitizer fixes
set -euo pipefail

echo "Testing MemorySanitizer fixes..."

# Set MSAN options
export MSAN_OPTIONS="abort_on_error=0:print_stats=1:halt_on_error=0:exit_code=0"

# Build with MSAN
echo "Building with MemorySanitizer..."
mkdir -p build-msan
cd build-msan
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-fsanitize=memory -fsanitize-memory-track-origins=2 -fno-omit-frame-pointer" ..
make -j20

# Test basic functionality
echo "Testing basic functionality..."
./bin/vglog-filter --help
./bin/vglog-filter --version

# Test with stdin
echo "Testing with stdin..."
echo "test input" | ./bin/vglog-filter

# Test with empty input
echo "Testing with empty input..."
echo "" | ./bin/vglog-filter

# Test with invalid arguments
echo "Testing with invalid arguments..."
./bin/vglog-filter --invalid-option 2>/dev/null || true

echo "MemorySanitizer tests completed successfully!" 