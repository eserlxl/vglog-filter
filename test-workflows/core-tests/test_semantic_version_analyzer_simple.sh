#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
set -euo pipefail

# Get project root - assume we're running from test-workflows/core-tests
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRIPT_PATH="$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh"

echo "Testing semantic version analyzer v2 modular architecture..."

# Test help output
echo "Testing help output..."
if "$SCRIPT_PATH" --help | grep -q "Semantic Version Analyzer v2 for vglog-filter"; then
    echo "✅ PASS: Help output shows v2 architecture"
else
    echo "❌ FAIL: Help output"
    exit 1
fi

# Test machine output format
echo "Testing machine output format..."
output=$("$SCRIPT_PATH" --machine --repo-root "$PROJECT_ROOT" 2>&1 || true)
if echo "$output" | grep -q "SUGGESTION="; then
    echo "✅ PASS: Machine output format"
else
    echo "❌ FAIL: Machine output format"
    echo "Output: $output"
    exit 1
fi

# Test JSON output format
echo "Testing JSON output format..."
json_output=$("$SCRIPT_PATH" --json --repo-root "$PROJECT_ROOT" 2>&1 || true)
if echo "$json_output" | grep -q '"suggestion"'; then
    echo "✅ PASS: JSON output contains suggestion field"
else
    echo "❌ FAIL: JSON output missing suggestion field"
    echo "Output: $json_output"
    exit 1
fi

if echo "$json_output" | grep -q '"current_version"'; then
    echo "✅ PASS: JSON output contains current_version field"
else
    echo "❌ FAIL: JSON output missing current_version field"
    echo "Output: $json_output"
    exit 1
fi

if echo "$json_output" | grep -q '"loc_delta"'; then
    echo "✅ PASS: JSON output contains loc_delta field"
else
    echo "❌ FAIL: JSON output missing loc_delta field"
    echo "Output: $json_output"
    exit 1
fi

# Test new JSON fields from v2 system
if echo "$json_output" | grep -q '"total_bonus"'; then
    echo "✅ PASS: JSON output contains total_bonus field"
else
    echo "❌ FAIL: JSON output missing total_bonus field"
    echo "Output: $json_output"
    exit 1
fi

if echo "$json_output" | grep -q '"base_ref"'; then
    echo "✅ PASS: JSON output contains base_ref field"
else
    echo "❌ FAIL: JSON output missing base_ref field"
    echo "Output: $json_output"
    exit 1
fi

if echo "$json_output" | grep -q '"target_ref"'; then
    echo "✅ PASS: JSON output contains target_ref field"
else
    echo "❌ FAIL: JSON output missing target_ref field"
    echo "Output: $json_output"
    exit 1
fi

# Test suggest-only output
echo "Testing suggest-only output..."
suggest_output=$("$SCRIPT_PATH" --suggest-only --repo-root "$PROJECT_ROOT" 2>&1 || true)
if echo "$suggest_output" | grep -E -q "^(major|minor|patch|none)$"; then
    echo "✅ PASS: Suggest-only output format"
else
    echo "❌ FAIL: Suggest-only output format"
    echo "Output: $suggest_output"
    exit 1
fi

# Test exit codes with strict status
echo "Testing exit codes with strict status..."
exit_code=0
"$SCRIPT_PATH" --suggest-only --strict-status --repo-root "$PROJECT_ROOT" > /dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 10 || $exit_code -eq 11 || $exit_code -eq 12 || $exit_code -eq 20 ]]; then
    echo "✅ PASS: Exit code is valid semantic version code: $exit_code"
else
    echo "❌ FAIL: Unexpected exit code: $exit_code"
    exit 1
fi

# Test exit codes without strict status (should be 0 for suggest-only)
echo "Testing exit codes without strict status..."
exit_code=0
"$SCRIPT_PATH" --suggest-only --repo-root "$PROJECT_ROOT" > /dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    echo "✅ PASS: Exit code is 0 for suggest-only without strict status"
else
    echo "❌ FAIL: Unexpected exit code: $exit_code"
    exit 1
fi

# Test verbose output
echo "Testing verbose output..."
verbose_output=$("$SCRIPT_PATH" --verbose --repo-root "$PROJECT_ROOT" 2>&1 || true)
if echo "$verbose_output" | grep -q "SUGGESTION="; then
    echo "✅ PASS: Verbose output contains suggestion"
else
    echo "❌ FAIL: Verbose output missing suggestion"
    echo "Output: $verbose_output"
    exit 1
fi

# Test that verbose output shows analysis steps
if echo "$verbose_output" | grep -q "Analyzing changes:"; then
    echo "✅ PASS: Verbose output shows analysis steps"
else
    echo "❌ FAIL: Verbose output missing analysis steps"
    echo "Output: $verbose_output"
    exit 1
fi

# Test JSON structure validation
echo "Testing JSON structure validation..."
if echo "$json_output" | grep -q '"loc_delta".*{'; then
    echo "✅ PASS: JSON loc_delta is an object"
else
    echo "❌ FAIL: JSON loc_delta is not an object"
    echo "Output: $json_output"
    exit 1
fi

# Test that suggestion values are valid
suggestion_value=$(echo "$json_output" | grep '"suggestion"' | sed 's/.*"suggestion": *"\([^"]*\)".*/\1/')
if [[ "$suggestion_value" =~ ^(major|minor|patch|none)$ ]]; then
    echo "✅ PASS: Suggestion value is valid: $suggestion_value"
else
    echo "❌ FAIL: Invalid suggestion value: $suggestion_value"
    exit 1
fi

# Test that current_version follows semantic versioning
current_version=$(echo "$json_output" | grep '"current_version"' | sed 's/.*"current_version": *"\([^"]*\)".*/\1/')
if [[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✅ PASS: Current version follows semantic versioning: $current_version"
else
    echo "❌ FAIL: Invalid current version format: $current_version"
    exit 1
fi

# Test that total_bonus is a number
total_bonus=$(echo "$json_output" | grep '"total_bonus"' | sed 's/.*"total_bonus": *\([0-9]*\).*/\1/')
if [[ "$total_bonus" =~ ^[0-9]+$ ]]; then
    echo "✅ PASS: Total bonus is a valid number: $total_bonus"
else
    echo "❌ FAIL: Invalid total bonus value: $total_bonus"
    exit 1
fi

echo "✅ All semantic version analyzer v2 tests passed!"
