#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for LOC-based delta system with bonus additions

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

echo "=== Testing LOC-based Delta System with Bonus Additions ==="

# Test 1: Small change (50 LOC) - No bonuses
echo "Test 1: Small change (50 LOC) - No bonuses"
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Simulate a small change by setting diff_size
export R_diff_size=50

echo "Current version: 9.3.0"
echo "LOC: 50"
echo "Bonuses: None"

# Test patch bump
echo "Patch delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[0-9]*' | cut -d: -f2 || echo "1")"
echo "Minor delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"minor_delta":[0-9]*' | cut -d: -f2 || echo "5")"
echo "Major delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"major_delta":[0-9]*' | cut -d: -f2 || echo "10")"

echo ""

# Test 2: Medium change (500 LOC) with CLI additions
echo "Test 2: Medium change (500 LOC) with CLI additions"
export R_diff_size=500
export R_cli_changes=true
export R_added_long_count=2

echo "Current version: 9.3.0"
echo "LOC: 500"
echo "Bonuses: CLI changes (+2), Added options (+1)"

echo "Patch delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[0-9]*' | cut -d: -f2 || echo "1")"
echo "Minor delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"minor_delta":[0-9]*' | cut -d: -f2 || echo "5")"
echo "Major delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"major_delta":[0-9]*' | cut -d: -f2 || echo "10")"

echo ""

# Test 3: Large change (2000 LOC) with breaking changes
echo "Test 3: Large change (2000 LOC) with breaking changes"
export R_diff_size=2000
export R_breaking_cli_changes=true
export R_api_breaking=true
export R_removed_short_count=1
export R_removed_long_count=2

echo "Current version: 9.3.0"
echo "LOC: 2000"
echo "Bonuses: Breaking CLI (+2), API breaking (+3), Removed options (+2)"

echo "Patch delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[0-9]*' | cut -d: -f2 || echo "1")"
echo "Minor delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"minor_delta":[0-9]*' | cut -d: -f2 || echo "5")"
echo "Major delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"major_delta":[0-9]*' | cut -d: -f2 || echo "10")"

echo ""

# Test 4: Security fix (100 LOC) with security keywords
echo "Test 4: Security fix (100 LOC) with security keywords"
export R_diff_size=100
export R_security_keywords=3

echo "Current version: 9.3.0"
echo "LOC: 100"
echo "Bonuses: Security keywords (+6)"

echo "Patch delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[0-9]*' | cut -d: -f2 || echo "1")"
echo "Minor delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"minor_delta":[0-9]*' | cut -d: -f2 || echo "5")"
echo "Major delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"major_delta":[0-9]*' | cut -d: -f2 || echo "10")"

echo ""

# Test 5: New feature (800 LOC) with new files
echo "Test 5: New feature (800 LOC) with new files"
export R_diff_size=800
export R_new_source_files=2
export R_new_test_files=3
export R_new_doc_files=1

echo "Current version: 9.3.0"
echo "LOC: 800"
echo "Bonuses: New source files (+1), New test files (+1), New doc files (+1)"

echo "Patch delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[0-9]*' | cut -d: -f2 || echo "1")"
echo "Minor delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"minor_delta":[0-9]*' | cut -d: -f2 || echo "5")"
echo "Major delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"major_delta":[0-9]*' | cut -d: -f2 || echo "10")"

echo ""

# Test 6: Rollover scenario with bonuses
echo "Test 6: Rollover scenario (9.3.95 + patch with 1000 LOC + breaking changes)"
export R_diff_size=1000
export R_breaking_cli_changes=true
export R_api_breaking=true

echo "Current version: 9.3.95"
echo "LOC: 1000"
echo "Bonuses: Breaking CLI (+2), API breaking (+3)"
echo "Patch delta: $(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null | grep -o '"patch_delta":[0-9]*' | cut -d: -f2 || echo "1")"
echo "Expected result: 9.4.0 (rollover due to large delta)"

echo ""

echo "=== LOC-based Delta System with Bonus Additions Test Complete ==="
echo ""
echo "To enable the system:"
echo "  export VERSION_USE_LOC_DELTA=true"
echo "  ./dev-bin/bump-version patch --commit"
echo ""
echo "To customize bonus values:"
echo "  export VERSION_BREAKING_CLI_BONUS=3"
echo "  export VERSION_API_BREAKING_BONUS=5"
echo "  export VERSION_SECURITY_BONUS=3"
echo ""
echo "To view detailed bonus breakdown:"
echo "  ./dev-bin/semantic-version-analyzer --verbose" 