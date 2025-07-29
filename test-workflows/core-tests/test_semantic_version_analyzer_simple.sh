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
SCRIPT_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"

echo "Testing basic functionality..."

# Test help output
echo "Testing help output..."
if "$SCRIPT_PATH" --help | grep -q "Semantic Version Analyzer v3 for vglog-filter"; then
    echo "✅ PASS: Help output"
else
    echo "❌ FAIL: Help output"
    exit 1
fi

# Test machine output format
echo "Testing machine output format..."
output=$("$SCRIPT_PATH" --machine 2>/dev/null || true)
if echo "$output" | grep -q "SUGGESTION="; then
    echo "✅ PASS: Machine output format"
else
    echo "❌ FAIL: Machine output format"
    echo "Output: $output"
    exit 1
fi

echo "✅ All basic tests passed!"
