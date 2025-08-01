#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.

set -euo pipefail

BINARY_PATH="$1"

if [ -z "$BINARY_PATH" ]; then
    echo "Usage: $0 <path_to_binary>"
    exit 1
fi

# Test help output
"$BINARY_PATH" --help || { echo "--help failed"; exit 1; }
"$BINARY_PATH" -h || { echo "-h failed"; exit 1; }

# Test version/usage (non-fatal)
timeout 5s "$BINARY_PATH" || true
"$BINARY_PATH" --version >/dev/null 2>&1 || true

# Functional smoke test with sample input
cat > test_input.txt << 'EOF'
==12345== Memcheck, a memory error detector
==12345== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==12345== Using Valgrind-3.13.0 and LibVEX; rerun with -h for copyright info
==12345== Command: ./test_program
==12345==
==12345== Successfully downloaded debug
==12345== Invalid read of size 4
==12345==    at 0x4005A1: main (test.c:10)
==12345==  Address 0x5204040 is 0 bytes after a block of size 40 alloc'd
==12345==    at 0x4C2AB80: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)
==12345==    at 0x40058E: main (test.c:8)
==12345==
==12345== HEAP SUMMARY:
==12345==     in use at exit: 40 bytes in 1 blocks
==12345==   total heap usage: 1 allocs, 0 frees, 40 bytes allocated
==12345==
==12345== LEAK SUMMARY:
==12345==    definitely lost: 40 bytes in 1 blocks
==12345==    indirectly lost: 0 bytes in 0 blocks
==12345==      possibly lost: 0 bytes in 1 blocks
==12345==    still reachable: 0 bytes in 0 blocks
==12345==         suppressed: 0 bytes in 0 blocks
==12345== Rerun with --leak-check=full to see details of leaked memory
==12345==
==12345== For counts of detected and suppressed errors, rerun with: -v
==12345== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
EOF

# Basic filtering functionality (file input)
"$BINARY_PATH" test_input.txt > filtered_output.txt
# Verify output was generated (non-empty)
[ -s filtered_output.txt ] || { echo "No output generated"; exit 1; }

# Also test stdin pipeline path
"$BINARY_PATH" < test_input.txt > /dev/null

# Try a few flags (do not assert content here, just execution)
"$BINARY_PATH" -d 2 test_input.txt > filtered_depth2.txt
"$BINARY_PATH" -k test_input.txt > filtered_keep.txt
"$BINARY_PATH" -v test_input.txt > filtered_verbose.txt

# Cleanup
rm -f test_input.txt filtered_output.txt filtered_depth2.txt filtered_keep.txt filtered_verbose.txt

echo "Smoke test passed!"
