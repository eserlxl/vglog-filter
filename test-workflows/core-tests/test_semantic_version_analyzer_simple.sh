#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2034 # SCRIPT_PATH is used for reference
SCRIPT_PATH="./dev-bin/semantic-version-analyzer"

echo "Testing basic functionality..."

# Test help output
echo "Testing help output..."
if ./dev-bin/semantic-version-analyzer --help | grep -q "Semantic Version Analyzer v3 for vglog-filter"; then
    echo "✅ PASS: Help output"
else
    echo "❌ FAIL: Help output"
    exit 1
fi

# Test machine output format
echo "Testing machine output format..."
output=$(./dev-bin/semantic-version-analyzer --machine 2>/dev/null || true)
if echo "$output" | grep -q "SUGGESTION="; then
    echo "✅ PASS: Machine output format"
else
    echo "❌ FAIL: Machine output format"
    echo "Output: $output"
    exit 1
fi

echo "✅ All basic tests passed!"
