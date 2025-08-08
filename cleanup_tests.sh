#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Cleanup script for vglog-filter test artifacts
# Removes temporary files and test artifacts while preserving legitimate test results

echo "🧹 Cleaning up test artifacts..."

# Remove Valgrind concurrent test files from /tmp
echo "  Removing Valgrind concurrent test files from /tmp..."
rm -f /tmp/test_concurrent_*.tmp

# Remove any test files that might have been created in root directory
echo "  Removing test files from root directory..."
rm -f test_safe_ops.txt
rm -f test_*.txt
rm -f test_*.tmp

# Remove any test files that might have been created in /tmp
echo "  Removing test files from /tmp..."
rm -f /tmp/test_*.tmp

# Remove workflow test directories from /tmp
echo "  Removing workflow test directories from /tmp..."
rm -rf /tmp/vglog-filter-test-* 2>/dev/null || true

# Remove any temporary executables (but keep build directory intact)
echo "  Checking for temporary executables..."
find . -maxdepth 1 -name "test_*" -type f -exec rm -f {} \;
find . -maxdepth 1 -name "vglog-filter" -type f -exec rm -f {} \;

# Remove any .o files in root (but keep build directory)
echo "  Removing object files from root directory..."
find . -maxdepth 1 -name "*.o" -type f -exec rm -f {} \;

# Optional: Clean test_results directory (uncomment if you want to remove all test outputs)
# echo "  Removing test results directory..."
# rm -rf test_results

echo "✅ Cleanup completed!"
echo ""
echo "Note: test_results/ directory was preserved as it contains legitimate test outputs."
echo "      If you want to remove all test results, uncomment the relevant line in this script." 