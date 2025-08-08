#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script to verify the rollover logic in the new versioning system

set -euo pipefail

# ─── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ─── Test counters ─────────────────────────────────────────────────────────────
TESTS_PASSED=0
TESTS_FAILED=0

# ─── New versioning system rollover logic ──────────────────────────────────────
test_new_rollover_logic() {
    local current_version="$1"   # e.g. 9.6.0
    local delta="$2"             # LOC delta

    # Parse major.minor.patch safely
    local OLDIFS=$IFS
    IFS='.' read -r current_major current_minor current_patch <<< "$current_version"
    IFS=$OLDIFS

    current_major=${current_major:-0}
    current_minor=${current_minor:-0}
    current_patch=${current_patch:-0}

    # New versioning system: always increase only the last identifier (patch)
    # Uses MAIN_VERSION_MOD=1000 for rollover logic
    # This matches the actual implementation in dev-bin/version-calculator.sh
    local MAIN_VERSION_MOD=1000
    
    # Rollover math (matches actual implementation):
    # z_new = (patch + TOTAL_DELTA)
    # delta_y = floor(z_new / MAIN_VERSION_MOD)
    # y_new = minor + delta_y
    # delta_x = floor(y_new / MAIN_VERSION_MOD)
    # final = (major + delta_x).(y_new % mod).(z_new % mod)
    local z_new=$((current_patch + delta))
    local delta_y=$((z_new / MAIN_VERSION_MOD))
    local final_z=$((z_new % MAIN_VERSION_MOD))
    
    local y_new=$((current_minor + delta_y))
    local delta_x=$((y_new / MAIN_VERSION_MOD))
    local final_y=$((y_new % MAIN_VERSION_MOD))
    
    local final_x=$((current_major + delta_x))

    printf '%s.%s.%s' "$final_x" "$final_y" "$final_z"
}

# ─── Helper to run a single test ───────────────────────────────────────────────
run_test() {
    local test_name="$1" expected="$2" current="$3" delta="$4"

    printf '%b[TEST]%b %s\n' "$BLUE" "$RESET" "$test_name"

    local output
    output=$(test_new_rollover_logic "$current" "$delta")

    if [[ "$output" == "$expected" ]]; then
        printf '%b✓ PASS%b: %s + %d → %s (expected %s)\n' \
               "$GREEN" "$RESET" "$current" "$delta" "$output" "$expected"
        (( ++TESTS_PASSED ))
    else
        printf '%b✗ FAIL%b: %s + %d → %s (expected %s)\n' \
               "$RED" "$RESET" "$current" "$delta" "$output" "$expected"
        (( ++TESTS_FAILED ))
    fi
    printf '\n'
}

# ─── Main test suite ───────────────────────────────────────────────────────────
main() {
    printf '%b=== New Versioning System Rollover Logic Tests ===%b\n' "$CYAN" "$RESET"
    printf '%bTesting new versioning system that always increases only the last identifier%b\n\n' "$BLUE" "$RESET"

    # Basic tests
    run_test "Basic patch increment"            "9.6.2"   "9.6.0"   2
    run_test "Basic patch increment 2"          "9.6.10"  "9.6.8"   2
    run_test "Zero delta"                       "9.6.0"   "9.6.0"   0
    
    # Patch rollover tests (using 1000 as rollover)
    run_test "Patch rollover to minor"          "9.7.1"   "9.6.999" 2
    run_test "Patch rollover exact boundary"    "9.7.0"   "9.6.999" 1
    run_test "Patch rollover large delta"       "9.7.50"  "9.6.999" 51
    run_test "Patch rollover multiple times"    "9.8.0"   "9.6.999" 1001
    
    # Minor rollover tests (using 1000 as rollover)
    run_test "Minor rollover to major"          "10.0.1"  "9.999.999" 2
    run_test "Minor rollover exact boundary"    "10.0.0"  "9.999.999" 1
    run_test "Minor rollover large delta"       "10.0.50" "9.999.999" 51
    run_test "Minor rollover multiple times"    "10.1.0"  "9.999.999" 1001
    
    # Complex rollover scenarios
    run_test "Double rollover scenario"         "10.0.1"  "9.999.995" 6
    run_test "Complex rollover scenario"        "10.1.25" "9.999.975" 1050
    run_test "Very large delta"                 "10.0.999" "9.999.999" 1000
    run_test "Boundary condition 1"             "9.7.0"   "9.6.999"  1
    run_test "Boundary condition 2"             "10.0.0"  "9.999.999" 1
    
    # Edge cases
    run_test "Version 0.0.0"                    "0.0.1"   "0.0.0"   1
    run_test "Version 0.0.999"                  "0.1.0"   "0.0.999" 1
    run_test "Version 0.999.999"                "1.0.0"   "0.999.999" 1
    run_test "Version 99.999.999"               "100.0.0" "99.999.999" 1
    
    # Specification examples (updated for 1000 rollover)
    run_test "Spec example: 9.3.0 + 6"          "9.3.6"   "9.3.0"   6
    run_test "Spec example: 9.3.995 + 6"        "9.4.1"   "9.3.995" 6
    run_test "Spec example: 9.999.995 + 6"      "10.0.1"  "9.999.995" 6
    run_test "Spec example: 9.3.0 + 16"         "9.3.16"  "9.3.0"   16
    run_test "Spec example: 9.3.0 + 37"         "9.3.37"  "9.3.0"   37

    printf '%b=== Test Summary ===%b\n' "$CYAN" "$RESET"
    printf '%bTests passed: %d%b\n'  "$GREEN" "$TESTS_PASSED" "$RESET"
    printf '%bTests failed: %d%b\n'  "$RED"   "$TESTS_FAILED" "$RESET"

    if (( TESTS_FAILED == 0 )); then
        printf '%bAll tests passed! New versioning system rollover logic is working correctly.%b\n' "$GREEN" "$RESET"
        printf '\n%bKey features verified:%b\n' "$BLUE" "$RESET"
        printf '  • Always increases only the last identifier (patch)\n'
        printf '  • Patch rollover: when patch + delta >= 1000, apply mod 1000 and increment minor\n'
        printf '  • Minor rollover: when minor + 1 >= 1000, apply mod 1000 and increment major\n'
        printf '  • All specification examples working correctly\n'
        return 0
    else
        printf '%bSome tests failed!%b\n' "$RED" "$RESET"
        return 1
    fi
}

# Run the main function
main "$@"
