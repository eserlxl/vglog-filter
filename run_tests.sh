#!/bin/bash

# Simple wrapper to run all tests in test-workflows directory
# Usage: ./run_tests.sh

set -e

echo "Running VGLOG-FILTER test suite..."
echo ""

# Change to the directory where this script is located
cd "$(dirname "$0")"

# Run the comprehensive test runner
./test-workflows/run_all_tests.sh

echo ""
echo "Test execution completed!" 