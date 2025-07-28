#!/bin/bash

# Test manual CLI detection
base_ref="502a359"
target_ref="d7db5a8"

echo "Testing manual CLI detection..."

# Test the exact commands from the script
added_long_opts=$(git -c color.ui=false diff -M -C "$base_ref".."$target_ref" -- 'src/**/*.c' 'src/**/*.cc' 'src/**/*.cpp' 'src/**/*.cxx' | grep -E '^\+.*--[[:alnum:]-]+' | sed -n 's/.*\(--[[:alnum:]-]\+\).*/\1/p' | sort -u || printf '')

removed_long_opts=$(git -c color.ui=false diff -M -C "$base_ref".."$target_ref" -- 'src/**/*.c' 'src/**/*.cc' 'src/**/*.cpp' 'src/**/*.cxx' | grep -E '^-.*--[[:alnum:]-]+' | sed -n 's/.*\(--[[:alnum:]-]\+\).*/\1/p' | sort -u || printf '')

echo "Added long options: '$added_long_opts'"
echo "Removed long options: '$removed_long_opts'"

manual_added_long_count=$(printf '%s\n' "$added_long_opts" | wc -l || printf '0')
manual_removed_long_count=$(printf '%s\n' "$removed_long_opts" | wc -l || printf '0')

echo "Manual added long count: $manual_added_long_count"
echo "Manual removed long count: $manual_removed_long_count"

manual_cli_changes=false
(( manual_added_long_count > 0 || manual_removed_long_count > 0 )) && manual_cli_changes=true

echo "Manual CLI changes: $manual_cli_changes" 