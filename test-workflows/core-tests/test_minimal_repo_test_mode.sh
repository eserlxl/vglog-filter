#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script demonstrating minimal repository support
# Tests semantic version analyzer with minimal repositories

set -Euo pipefail

# Source the test helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=test_helper.sh
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Script path
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../dev-bin/semantic-version-analyzer.sh"

# Change to project root for tests
# Change to project root (assume we're running from project root)
cd "$(pwd)" || exit 1

echo "Testing semantic version analyzer minimal repository support..."

# Test 1: Minimal repository (should work)
echo "Test 1: Minimal repository..."
test_dir=$(create_temp_test_env "minimal")
cd "$test_dir" || exit 1

output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
    echo "✅ PASS: Minimal repo exits with valid code: $exit_code"
else
    echo "❌ FAIL: Minimal repo has wrong exit code: $exit_code"
    exit 1
fi

if echo "$output" | grep -q "Semantic Version Analysis v2"; then
    echo "✅ PASS: Minimal repo shows analysis output"
else
    echo "❌ FAIL: Minimal repo missing analysis output"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

# Test 2: Minimal repository with suggest-only (should work)
echo "Test 2: Minimal repository with suggest-only..."
test_dir=$(create_temp_test_env "minimal-suggest")
cd "$test_dir" || exit 1

output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code == 0 ]]; then
    echo "✅ PASS: Minimal repo with suggest-only exits successfully"
else
    echo "❌ FAIL: Minimal repo with suggest-only has wrong exit code: $exit_code"
    echo "Output: $output"
    exit 1
fi

if echo "$output" | grep -E -q "^(major|minor|patch|none)$"; then
    echo "✅ PASS: Minimal repo with suggest-only produces valid suggestion"
else
    echo "❌ FAIL: Minimal repo with suggest-only produces invalid suggestion"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

# Test 3: Minimal repository with JSON output
echo "Test 3: Minimal repository with JSON output..."
test_dir=$(create_temp_test_env "minimal-json")
cd "$test_dir" || exit 1

output=$("$SCRIPT_PATH" --json --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
    echo "✅ PASS: Minimal repo with JSON exits with valid code: $exit_code"
else
    echo "❌ FAIL: Minimal repo with JSON has wrong exit code: $exit_code"
    echo "Output: $output"
    exit 1
fi

if echo "$output" | grep -q '"suggestion"'; then
    echo "✅ PASS: Minimal repo with JSON produces valid JSON"
else
    echo "❌ FAIL: Minimal repo with JSON produces invalid JSON"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

# Test 4: Empty repository (should work)
echo "Test 4: Empty repository..."
test_dir=$(create_temp_test_env "empty")
cd "$test_dir" || exit 1

# Create an empty repository (no commits)
rm -rf .git
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
    echo "✅ PASS: Empty repo exits with valid code: $exit_code"
else
    echo "❌ FAIL: Empty repo has wrong exit code: $exit_code"
    echo "Output: $output"
    exit 1
fi

# Check for empty repository indicators in the output
if echo "$output" | grep -q "EMPTY -> HEAD"; then
    echo "✅ PASS: Empty repo shows appropriate analysis (EMPTY -> HEAD)"
else
    echo "❌ FAIL: Empty repo missing appropriate analysis"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

# Test 5: Single commit repository (should work)
echo "Test 5: Single commit repository..."
test_dir=$(create_temp_test_env "single-commit")
cd "$test_dir" || exit 1

# Create a single commit repository
echo "1.0.0" > VERSION
git add VERSION
git commit -m "Initial commit" >/dev/null 2>&1

output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
    echo "✅ PASS: Single commit repo exits with valid code: $exit_code"
else
    echo "❌ FAIL: Single commit repo has wrong exit code: $exit_code"
    echo "Output: $output"
    exit 1
fi

# Check for single commit repository indicators in the output
if echo "$output" | grep -q "Analyzing changes:" && echo "$output" | grep -q "Current version: 1.0.0"; then
    echo "✅ PASS: Single commit repo shows appropriate analysis (commit -> HEAD, version 1.0.0)"
else
    echo "❌ FAIL: Single commit repo missing appropriate analysis"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

# Test 6: Empty repository with suggest-only (should work)
echo "Test 6: Empty repository with suggest-only..."
test_dir=$(create_temp_test_env "empty-suggest")
cd "$test_dir" || exit 1

# Create an empty repository (no commits)
rm -rf .git
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code == 0 ]]; then
    echo "✅ PASS: Empty repo with suggest-only exits successfully"
else
    echo "❌ FAIL: Empty repo with suggest-only has wrong exit code: $exit_code"
    echo "Output: $output"
    exit 1
fi

if echo "$output" | grep -E -q "^(major|minor|patch|none)$"; then
    echo "✅ PASS: Empty repo with suggest-only produces valid suggestion"
else
    echo "❌ FAIL: Empty repo with suggest-only produces invalid suggestion"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

# Test 7: Empty repository with JSON output
echo "Test 7: Empty repository with JSON output..."
test_dir=$(create_temp_test_env "empty-json")
cd "$test_dir" || exit 1

# Create an empty repository (no commits)
rm -rf .git
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

output=$("$SCRIPT_PATH" --json --repo-root "$test_dir" 2>&1)
exit_code=$?

if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
    echo "✅ PASS: Empty repo with JSON exits with valid code: $exit_code"
else
    echo "❌ FAIL: Empty repo with JSON has wrong exit code: $exit_code"
    echo "Output: $output"
    exit 1
fi

if echo "$output" | grep -q '"suggestion"'; then
    echo "✅ PASS: Empty repo with JSON produces valid JSON"
else
    echo "❌ FAIL: Empty repo with JSON produces invalid JSON"
    echo "Output: $output"
    exit 1
fi

cd - >/dev/null 2>&1 || exit
cleanup_temp_test_env "$test_dir"

echo "✅ All minimal repository support tests passed!"
