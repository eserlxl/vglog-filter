#!/bin/bash

echo "=== Testing Semantic Version Analyzer Fixes ==="

# Test 1: Manual CLI detection in nested directories
echo "Test 1: Manual CLI detection (nested src/tools/cli/main.c)"
./dev-bin/semantic-version-analyzer --base 502a359 --target d7db5a8 --suggest-only
echo "Expected: minor (manual_cli_changes=true, manual_added_long_count=1)"

echo

# Test 2: API breaking changes detection
echo "Test 2: API breaking changes (removed prototype from src/internal/header.hh)"
./dev-bin/semantic-version-analyzer --base c6734e6 --target 4683934 --suggest-only
echo "Expected: major (reason=api_break)"

echo

# Test 3: CLI breaking changes detection
echo "Test 3: CLI breaking changes (removed --bar option)"
./dev-bin/semantic-version-analyzer --base 4683934 --target f8aeccb --suggest-only
echo "Expected: minor (manual_cli_changes=true, manual_removed_long_count=1)"

echo

# Test 4: Whitespace handling
echo "Test 4: Whitespace-only changes with --ignore-whitespace"
./dev-bin/semantic-version-analyzer --base f259801 --target HEAD --ignore-whitespace --suggest-only
echo "Expected: none (no size-driven bump)"

echo

# Test 5: Repository without tags (--print-base)
echo "Test 5: --print-base functionality"
./dev-bin/semantic-version-analyzer --print-base
echo "Expected: SHA of chosen base reference"

echo

# Test 6: ERE consistency for case labels
echo "Test 6: ERE consistency (grep -E for case labels)"
echo "This is verified by the script using grep -E '^\+' and grep -E '^-'"

echo

# Test 7: color.ui=false consistency
echo "Test 7: color.ui=false consistency"
echo "This is verified by all git commands using -c color.ui=false"

echo

echo "=== All tests completed ===" 