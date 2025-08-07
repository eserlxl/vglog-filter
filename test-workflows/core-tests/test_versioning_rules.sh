#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script to verify versioning system follows the specified rules

set -Euo pipefail
IFS=$'\n\t'
export LC_ALL=C

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Get project root
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test function
test_version_calculation() {
    local test_name="$1"
    local current_version="$2"
    local bump_type="$3"
    local loc="$4"
    local bonus="$5"
    local expected_base_delta="$6"
    local expected_multiplier="$7"
    local expected_total_bonus="$8"
    local expected_total_delta="$9"
    local expected_next_version="${10}"
    
    printf 'Testing: %s\n' "$test_name"
    
    # Run version calculator
    local output
    if ! output=$("$PROJECT_ROOT/dev-bin/version-calculator.sh" --current-version "$current_version" --bump-type "$bump_type" --loc "$loc" --bonus "$bonus" --machine 2>/dev/null); then
        printf '%bFAILED: Command failed%b\n' "$RED" "$NC"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    # Parse output
    local actual_next_version actual_base_delta actual_multiplier actual_total_bonus actual_total_delta
    
    actual_next_version=$(printf '%s' "$output" | grep '^NEXT_VERSION=' | cut -d'=' -f2)
    actual_base_delta=$(printf '%s' "$output" | grep '^BASE_DELTA=' | cut -d'=' -f2)
    actual_multiplier=$(printf '%s' "$output" | grep '^BONUS_MULTIPLIER=' | cut -d'=' -f2)
    actual_total_bonus=$(printf '%s' "$output" | grep '^TOTAL_BONUS=' | cut -d'=' -f2)
    actual_total_delta=$(printf '%s' "$output" | grep '^TOTAL_DELTA=' | cut -d'=' -f2)
    
    # Check results
    local passed=true
    
    if [[ "$actual_next_version" != "$expected_next_version" ]]; then
        printf '%bFAILED: Next version mismatch. Expected: %s, Got: %s%b\n' "$RED" "$expected_next_version" "$actual_next_version" "$NC"
        passed=false
    fi
    
    if [[ "$actual_base_delta" != "$expected_base_delta" ]]; then
        printf '%bFAILED: Base delta mismatch. Expected: %s, Got: %s%b\n' "$RED" "$expected_base_delta" "$actual_base_delta" "$NC"
        passed=false
    fi
    
    if [[ "$actual_multiplier" != "$expected_multiplier" ]]; then
        printf '%bFAILED: Bonus multiplier mismatch. Expected: %s, Got: %s%b\n' "$RED" "$expected_multiplier" "$actual_multiplier" "$NC"
        passed=false
    fi
    
    if [[ "$actual_total_bonus" != "$expected_total_bonus" ]]; then
        printf '%bFAILED: Total bonus mismatch. Expected: %s, Got: %s%b\n' "$RED" "$expected_total_bonus" "$actual_total_bonus" "$NC"
        passed=false
    fi
    
    if [[ "$actual_total_delta" != "$expected_total_delta" ]]; then
        printf '%bFAILED: Total delta mismatch. Expected: %s, Got: %s%b\n' "$RED" "$expected_total_delta" "$actual_total_delta" "$NC"
        passed=false
    fi
    
    if [[ "$passed" = "true" ]]; then
        printf '%bPASSED%b\n' "$GREEN" "$NC"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    printf '\n'
}

# Test rollover logic
test_rollover() {
    local test_name="$1"
    local current_version="$2"
    local bump_type="$3"
    local loc="$4"
    local bonus="$5"
    local expected_next_version="$6"
    
    printf 'Testing Rollover: %s\n' "$test_name"
    
    local output
    if ! output=$("$PROJECT_ROOT/dev-bin/version-calculator.sh" --current-version "$current_version" --bump-type "$bump_type" --loc "$loc" --bonus "$bonus" --machine 2>/dev/null); then
        printf '%bFAILED: Command failed%b\n' "$RED" "$NC"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    local actual_next_version
    actual_next_version=$(printf '%s' "$output" | grep '^NEXT_VERSION=' | cut -d'=' -f2)
    
    if [[ "$actual_next_version" = "$expected_next_version" ]]; then
        printf '%bPASSED%b\n' "$GREEN" "$NC"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%bFAILED: Rollover mismatch. Expected: %s, Got: %s%b\n' "$RED" "$expected_next_version" "$actual_next_version" "$NC"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    printf '\n'
}

# Main test execution
main() {
    printf '=== Testing Versioning System Rules ===\n\n'
    
    # Test 1: Basic patch calculation
    # VERSION_PATCH_DELTA=1*(1+LOC/250)
    # LOC=100, bonus=5
    # base_delta = 1*(1+100/250) = 1*(1+0.4) = 1.4 ≈ 1
    # multiplier = 1+100/250 = 1.4
    # total_bonus = 5*1.4 = 7
    # total_delta = 1+7 = 8
    # next_version = 1.2.3 + 8 = 1.2.11
    test_version_calculation \
        "Basic patch calculation" \
        "1.2.3" "patch" "100" "5" \
        "1" "1.40" "7" "8" "1.2.11"
    
    # Test 2: Basic minor calculation
    # VERSION_MINOR_DELTA=5*(1+LOC/500)
    # LOC=500, bonus=10
    # base_delta = 5*(1+500/500) = 5*(1+1) = 10
    # multiplier = 1+500/500 = 2.0
    # total_bonus = 10*2.0 = 20
    # total_delta = 10+20 = 30
    # next_version = 1.2.3 + 30 = 1.2.33
    test_version_calculation \
        "Basic minor calculation" \
        "1.2.3" "minor" "500" "10" \
        "10" "2.00" "20" "30" "1.2.33"
    
    # Test 3: Basic major calculation
    # VERSION_MAJOR_DELTA=10*(1+LOC/1000)
    # LOC=1000, bonus=15
    # base_delta = 10*(1+1000/1000) = 10*(1+1) = 20
    # multiplier = 1+1000/1000 = 2.0
    # total_bonus = 15*2.0 = 30
    # total_delta = 20+30 = 50
    # next_version = 1.2.3 + 50 = 1.2.53
    test_version_calculation \
        "Basic major calculation" \
        "1.2.3" "major" "1000" "15" \
        "20" "2.00" "30" "50" "1.2.53"
    
    # Test 4: Large LOC values
    # LOC=2000, bonus=50, major
    # base_delta = 10*(1+2000/1000) = 10*(1+2) = 30
    # multiplier = 1+2000/1000 = 3.0
    # total_bonus = 50*3.0 = 150
    # total_delta = 30+150 = 180
    # next_version = 1.2.3 + 180 = 1.2.183
    test_version_calculation \
        "Large LOC values" \
        "1.2.3" "major" "2000" "50" \
        "30" "3.00" "150" "180" "1.2.183"
    
    # Test 5: Zero LOC
    # LOC=0, bonus=10, patch
    # base_delta = 1*(1+0/250) = 1*(1+0) = 1
    # multiplier = 1+0/250 = 1.0
    # total_bonus = 10*1.0 = 10
    # total_delta = 1+10 = 11
    # next_version = 1.2.3 + 11 = 1.2.14
    test_version_calculation \
        "Zero LOC" \
        "1.2.3" "patch" "0" "10" \
        "1" "1.00" "10" "11" "1.2.14"
    
    # Test 6: Zero bonus
    # LOC=100, bonus=0, minor
    # base_delta = 5*(1+100/500) = 5*(1+0.2) = 6
    # multiplier = 1+100/500 = 1.2
    # total_bonus = 0*1.2 = 0
    # total_delta = 6+0 = 6
    # next_version = 1.2.3 + 6 = 1.2.9
    test_version_calculation \
        "Zero bonus" \
        "1.2.3" "minor" "100" "0" \
        "6" "1.20" "0" "6" "1.2.9"
    
    # Test 7: Rollover from patch to minor (MAIN_VERSION_MOD=1000)
    # current=1.2.995, patch, LOC=100, bonus=10
    # base_delta = 1*(1+100/250) = 1.4 ≈ 1
    # multiplier = 1+100/250 = 1.4
    # total_bonus = 10*1.4 = 14
    # total_delta = 1+14 = 15
    # new_patch = 995 + 15 = 1010
    # delta_y = (1010 - 1010%1000) / 1000 = 1010 / 1000 = 1
    # final_z = 1010 % 1000 = 10
    # new_y = 2 + 1 = 3
    # final_y = 3 % 1000 = 3
    # final_x = 1 + 0 = 1
    # next_version = 1.3.10
    test_rollover \
        "Rollover from patch to minor" \
        "1.2.995" "patch" "100" "10" "1.3.10"
    
    # Test 8: Multiple rollovers (MAIN_VERSION_MOD=1000)
    # current=1.999.999, major, LOC=1000, bonus=100
    # base_delta = 10*(1+1000/1000) = 20
    # multiplier = 1+1000/1000 = 2.0
    # total_bonus = 100*2.0 = 200
    # total_delta = 20+200 = 220
    # new_patch = 999 + 220 = 1219
    # delta_y = (1219 - 1219%1000) / 1000 = 1000 / 1000 = 1
    # final_z = 1219 % 1000 = 219
    # new_y = 999 + 1 = 1000
    # delta_x = (1000 - 1000%1000) / 1000 = 1000 / 1000 = 1
    # final_y = 1000 % 1000 = 0
    # final_x = 1 + 1 = 2
    # next_version = 2.0.219
    test_rollover \
        "Multiple rollovers" \
        "1.999.999" "major" "1000" "100" "2.0.219"
    
    # Test 9: Edge case - minimum delta
    # LOC=1, bonus=0, patch
    # base_delta = 1*(1+1/250) = 1.004 ≈ 1
    # multiplier = 1+1/250 = 1.004
    # total_bonus = 0*1.004 = 0
    # total_delta = 1+0 = 1
    # next_version = 1.2.3 + 1 = 1.2.4
    test_version_calculation \
        "Minimum delta edge case" \
        "1.2.3" "patch" "1" "0" \
        "1" "1.00" "0" "1" "1.2.4"
    
    # Test 10: Very large numbers (MAIN_VERSION_MOD=1000)
    # LOC=10000, bonus=1000, major
    # base_delta = 10*(1+10000/1000) = 10*(1+10) = 110
    # multiplier = 1+10000/1000 = 11.0
    # total_bonus = 1000*11.0 = 11000
    # total_delta = 110+11000 = 11110
    # new_patch = 3 + 11110 = 11113
    # delta_y = (11113 - 11113%1000) / 1000 = 11110 / 1000 = 11
    # final_z = 11113 % 1000 = 113
    # new_y = 2 + 11 = 13
    # final_y = 13 % 1000 = 13
    # final_x = 1 + 0 = 1
    # next_version = 1.13.113
    test_rollover \
        "Very large numbers" \
        "1.2.3" "major" "10000" "1000" "1.13.113"
    
    # Test 11: Rollover at exactly 1000 (MAIN_VERSION_MOD=1000)
    # current=1.2.999, patch, LOC=1, bonus=0
    # base_delta = 1*(1+1/250) = 1.004 ≈ 1
    # multiplier = 1+1/250 = 1.004
    # total_bonus = 0*1.004 = 0
    # total_delta = 1+0 = 1
    # new_patch = 999 + 1 = 1000
    # delta_y = (1000 - 1000%1000) / 1000 = 1000 / 1000 = 1
    # final_z = 1000 % 1000 = 0
    # new_y = 2 + 1 = 3
    # final_y = 3 % 1000 = 3
    # final_x = 1 + 0 = 1
    # next_version = 1.3.0
    test_rollover \
        "Rollover at exactly 1000" \
        "1.2.999" "patch" "1" "0" "1.3.0"
    
    # Test 12: Large rollover with multiple components
    # current=1.999.999, patch, LOC=1, bonus=0
    # base_delta = 1*(1+1/250) = 1.004 ≈ 1
    # multiplier = 1+1/250 = 1.004
    # total_bonus = 0*1.004 = 0
    # total_delta = 1+0 = 1
    # new_patch = 999 + 1 = 1000
    # delta_y = (1000 - 1000%1000) / 1000 = 1000 / 1000 = 1
    # final_z = 1000 % 1000 = 0
    # new_y = 999 + 1 = 1000
    # delta_x = (1000 - 1000%1000) / 1000 = 1000 / 1000 = 1
    # final_y = 1000 % 1000 = 0
    # final_x = 1 + 1 = 2
    # next_version = 2.0.0
    test_rollover \
        "Large rollover with multiple components" \
        "1.999.999" "patch" "1" "0" "2.0.0"
    
    # Print summary
    printf '=== Test Summary ===\n'
    printf 'Tests passed: %b%d%b\n' "$GREEN" "$TESTS_PASSED" "$NC"
    printf 'Tests failed: %b%d%b\n' "$RED" "$TESTS_FAILED" "$NC"
    printf 'Total tests: %d\n' $((TESTS_PASSED + TESTS_FAILED))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf '\n%bALL TESTS PASSED! Versioning system follows all specified rules.%b\n' "$GREEN" "$NC"
        exit 0
    else
        printf '\n%bSOME TESTS FAILED! Please review the versioning system implementation.%b\n' "$RED" "$NC"
        exit 1
    fi
}

# Run main function
main "$@" 