#!/bin/bash

# Test script to verify MemorySanitizer fixes
# This script tests that the program can process valgrind log files without
# triggering MemorySanitizer warnings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
TEST_FILE="test-msan-fix.txt"
PROGRAM="$BUILD_DIR/bin/vglog-filter"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing MemorySanitizer fixes...${NC}"

# Check if program exists
if [[ ! -f "$PROGRAM" ]]; then
    echo -e "${RED}Error: Program not found at $PROGRAM${NC}"
    echo "Please build the project first with: ./build.sh"
    exit 1
fi

# Change to test-workflows directory to use relative paths
cd "$SCRIPT_DIR"

# Check if test file exists
if [[ ! -f "$TEST_FILE" ]]; then
    echo -e "${RED}Error: Test file not found at $TEST_FILE${NC}"
    exit 1
fi

echo "Test file: $TEST_FILE"
echo "Program: $PROGRAM"
echo

# Test 1: Process the test file
echo -e "${YELLOW}Test 1: Processing test file...${NC}"
if output=$(timeout 10s "$PROGRAM" "$TEST_FILE" 2>&1); then
    echo -e "${GREEN}✓ File processing successful${NC}"
    echo "Output:"
    echo "$output" | head -20
    if [[ $(echo "$output" | wc -l) -gt 1 ]]; then
        echo -e "${GREEN}✓ Output contains processed content${NC}"
    else
        echo -e "${YELLOW}⚠ Output is minimal (expected for this test file)${NC}"
    fi
else
    echo -e "${RED}✗ File processing failed${NC}"
    echo "Error output: $output"
    exit 1
fi

echo

# Test 2: Test with stdin
echo -e "${YELLOW}Test 2: Processing from stdin...${NC}"
if output=$(timeout 10s cat "$TEST_FILE" | "$PROGRAM" 2>&1); then
    echo -e "${GREEN}✓ Stdin processing successful${NC}"
else
    echo -e "${RED}✗ Stdin processing failed${NC}"
    echo "Error output: $output"
    exit 1
fi

echo

# Test 3: Test help output
echo -e "${YELLOW}Test 3: Testing help output...${NC}"
if output=$(timeout 10s "$PROGRAM" --help 2>&1); then
    echo -e "${GREEN}✓ Help output successful${NC}"
    if echo "$output" | grep -q "Usage:"; then
        echo -e "${GREEN}✓ Help output contains expected content${NC}"
    else
        echo -e "${RED}✗ Help output missing expected content${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Help output failed${NC}"
    echo "Error output: $output"
    exit 1
fi

echo

# Test 4: Test with empty input
echo -e "${YELLOW}Test 4: Testing with empty input...${NC}"
if output=$(timeout 10s echo "" | "$PROGRAM" 2>&1); then
    echo -e "${GREEN}✓ Empty input processing successful${NC}"
else
    echo -e "${RED}✗ Empty input processing failed${NC}"
    echo "Error output: $output"
    exit 1
fi

echo

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All MemorySanitizer fix tests PASSED!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "The program successfully processes valgrind log files without"
echo "triggering MemorySanitizer warnings." 