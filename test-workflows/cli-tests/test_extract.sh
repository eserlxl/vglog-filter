#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test the extract_cli_options function
base_ref="502a359"
target_ref="d7db5a8"

echo "Testing extract_cli_options function..."

# Call the function and capture output
cli_analysis=$(./dev-bin/semantic-version-analyzer --base "$base_ref" --target "$target_ref" --machine 2>/dev/null || true)

echo "CLI analysis output:"
echo "$cli_analysis"

echo "Extracting manual CLI variables:"
manual_cli_changes=$(echo "$cli_analysis" | grep "^manual_cli_changes=" | cut -d'=' -f2 || echo "not found")
manual_added_long_count=$(echo "$cli_analysis" | grep "^manual_added_long_count=" | cut -d'=' -f2 || echo "not found")
manual_removed_long_count=$(echo "$cli_analysis" | grep "^manual_removed_long_count=" | cut -d'=' -f2 || echo "not found")

echo "manual_cli_changes: $manual_cli_changes"
echo "manual_added_long_count: $manual_added_long_count"
echo "manual_removed_long_count: $manual_removed_long_count" 