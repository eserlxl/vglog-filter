#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Simple test for path classification functionality

echo "=== Testing Path Classification (Simple) ==="

# Simple classify function
classify_path() {
    local path="$1"
    if [[ "$path" =~ ^doc/ ]]; then
        return 20
    fi
    if [[ "$path" =~ ^src/ ]]; then
        return 30
    fi
    if [[ "$path" =~ ^test/ ]]; then
        return 10
    fi
    return 0
}

# Test basic functionality
echo "Testing basic classification..."

classify_path "doc/README.md"
result=$?
echo "doc/README.md -> $result (expected: 20)"

classify_path "src/main.cpp"
result=$?
echo "src/main.cpp -> $result (expected: 30)"

classify_path "test/unit.cpp"
result=$?
echo "test/unit.cpp -> $result (expected: 10)"

classify_path "unknown.txt"
result=$?
echo "unknown.txt -> $result (expected: 0)"

echo "=== Test completed ==="
exit 0 