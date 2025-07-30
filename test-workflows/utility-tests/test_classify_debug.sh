#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Debug test for path classification

echo "=== Debug Test ==="

# Test 1: Basic echo
echo "Test 1: Basic echo works"

# Test 2: Simple function
test_func() {
    echo "Test 2: Function works"
    return 0
}
test_func

# Test 3: Simple regex
path="doc/test.txt"
if [[ "$path" =~ ^doc/ ]]; then
    echo "Test 3: Regex works - $path matches ^doc/"
else
    echo "Test 3: Regex failed - $path does not match ^doc/"
fi

# Test 4: Return value
test_func
result=$?
echo "Test 4: Return value works - $result"

echo "=== Debug Test Completed ==="
exit 0 