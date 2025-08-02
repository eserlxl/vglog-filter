#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script to verify the rollover logic in the LOC-based delta system

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

# ─── Rollover logic (absolute-patch method) ────────────────────────────────────
test_rollover_logic() {
    local current_version="$1"   # e.g. 9.6.0
    local delta="$2"             # LOC delta
    local patch_limit="${3:-100}"
    local minor_limit="${4:-100}"

    # Parse major.minor.patch safely
    local OLDIFS=$IFS
    IFS='.' read -r current_major current_minor current_patch <<< "$current_version"
    IFS=$OLDIFS

    current_major=${current_major:-0}
    current_minor=${current_minor:-0}
    current_patch=${current_patch:-0}

    # Convert to an absolute patch count, add delta, then convert back
    local total=$(( ((current_major * minor_limit + current_minor) * patch_limit) + current_patch + delta ))
    if (( total < 0 )); then
        printf '%s\n' "Error: delta drives version negative" >&2
        return 1
    fi

    local new_major=$(( total / (minor_limit * patch_limit) ))
    local remainder=$(( total % (minor_limit * patch_limit) ))
    local new_minor=$(( remainder / patch_limit ))
    local new_patch=$(( remainder % patch_limit ))

    printf '%s.%s.%s' "$new_major" "$new_minor" "$new_patch"
}

# ─── Helper to run a single test ───────────────────────────────────────────────
run_test() {
    local test_name="$1" expected="$2" current="$3" delta="$4"
    local patch_limit="${5:-100}" minor_limit="${6:-100}"

    printf '%b[TEST]%b %s\n' "$BLUE" "$RESET" "$test_name"

    local output
    output=$(test_rollover_logic "$current" "$delta" "$patch_limit" "$minor_limit")

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
    printf '%b=== Rollover Logic Tests ===%b\n' "$CYAN" "$RESET"
    printf '%bTesting LOC-based delta system rollover logic%b\n\n' "$BLUE" "$RESET"

    run_test "Basic patch increment"            "9.6.2"   "9.6.0"   2
    run_test "Patch rollover to minor"          "9.7.1"   "9.6.99"  2
    run_test "Minor rollover to major"          "10.0.1"  "9.99.99" 2
    run_test "Exact patch limit boundary"       "9.7.0"   "9.6.99"  1
    run_test "Multiple rollovers"               "10.0.4"  "9.99.99" 5
    run_test "Large delta multiple rollovers"   "10.1.49" "9.99.99" 150
    run_test "Minor version rollover"           "10.0.10" "9.99.50" 60
    run_test "Zero delta"                       "9.6.0"   "9.6.0"   0
    run_test "Very large delta"                 "10.9.99" "9.99.99" 1000
    run_test "Custom limits test"               "10.0.1"  "9.49.49" 2  50 50
    run_test "Complex rollover scenario"        "10.1.25" "9.99.75" 150
    run_test "Boundary condition 1"             "9.7.0"   "9.6.99"  1
    run_test "Boundary condition 2"             "10.0.0"  "9.99.99" 1

    printf '%b=== Test Summary ===%b\n' "$CYAN" "$RESET"
    printf '%bTests passed: %d%b\n'  "$GREEN" "$TESTS_PASSED" "$RESET"
    printf '%bTests failed: %d%b\n'  "$RED"   "$TESTS_FAILED" "$RESET"

    if (( TESTS_FAILED == 0 )); then
        printf '%bAll tests passed!%b\n' "$GREEN" "$RESET"
    else
        printf '%bSome tests failed!%b\n' "$RED" "$RESET"
        return 1
    fi
}

main "$@"
