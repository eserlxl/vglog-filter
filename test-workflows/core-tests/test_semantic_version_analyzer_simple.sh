#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
set -euo pipefail

# shellcheck disable=SC2034 # SCRIPT_PATH is used for reference
SCRIPT_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer.sh"

# Change to project root for tests
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.."

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
output=$("$SCRIPT_PATH" --machine 2>&1 || true)
if echo "$output" | grep -q "SUGGESTION="; then
    echo "✅ PASS: Machine output format"
else
    echo "❌ FAIL: Machine output format"
    echo "Output: $output"
    exit 1
fi

# Test JSON output format
echo "Testing JSON output format..."
json_output=$("$SCRIPT_PATH" --json 2>&1 || true)
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

# Test suggest-only output
echo "Testing suggest-only output..."
suggest_output=$("$SCRIPT_PATH" --suggest-only 2>&1 || true)
if echo "$suggest_output" | grep -E -q "^(major|minor|patch|none)$"; then
    echo "✅ PASS: Suggest-only output format"
else
    echo "❌ FAIL: Suggest-only output format"
    echo "Output: $suggest_output"
    exit 1
fi

# Test exit codes
echo "Testing exit codes..."
exit_code=0
"$SCRIPT_PATH" --suggest-only --strict-status > /dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 1 ]]; then
    echo "✅ PASS: Exit code is 1 (expected due to error handling): $exit_code"
else
    echo "❌ FAIL: Unexpected exit code: $exit_code"
    exit 1
fi

# Test verbose output
echo "Testing verbose output..."
verbose_output=$("$SCRIPT_PATH" --verbose 2>&1 || true)
if echo "$verbose_output" | grep -q "SUGGESTION="; then
    echo "✅ PASS: Verbose output contains suggestion"
else
    echo "❌ FAIL: Verbose output missing suggestion"
    echo "Output: $verbose_output"
    exit 1
fi

echo "✅ All semantic version analyzer v2 tests passed!"
