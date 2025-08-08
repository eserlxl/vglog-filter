#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Simple test script for version calculation logic

set -Eeuo pipefail
IFS=$'\n\t'

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "Testing Version Calculation Logic (Direct)"
echo "========================================="

# Create temporary test environment
test_dir=$(create_temp_test_env "version_logic_test")
cd "$test_dir"

# Test the calculate_next_version function directly by creating a test script
cat > /tmp/test_version_calc.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Constants for the new versioning system
MAIN_VERSION_MOD=100

# Calculate LOC-based delta
calculate_loc_delta() {
    local bump_type="$1"
    local loc="$2"
    
    # Base delta calculation based on bump type and LOC
    local base_delta=0
    case "$bump_type" in
        patch)
            # VERSION_PATCH_DELTA=1*(1+LOC/250)
            base_delta=$(awk "BEGIN {printf \"%.0f\", 1 * (1 + $loc / 250)}" 2>/dev/null || echo "1")
            ;;
        minor)
            # VERSION_MINOR_DELTA=5*(1+LOC/500)
            base_delta=$(awk "BEGIN {printf \"%.0f\", 5 * (1 + $loc / 500)}" 2>/dev/null || echo "5")
            ;;
        major)
            # VERSION_MAJOR_DELTA=10*(1+LOC/1000)
            base_delta=$(awk "BEGIN {printf \"%.0f\", 10 * (1 + $loc / 1000)}" 2>/dev/null || echo "10")
            ;;
        *)
            base_delta=1
            ;;
    esac
    
    # Ensure minimum base_delta of 1
    if [[ "$base_delta" -lt 1 ]]; then
        base_delta=1
    fi
    
    printf '%d' "$base_delta"
}

# Calculate bonus multiplier based on LOC and version type
calculate_bonus_multiplier() {
    local bump_type="$1"
    local loc="$2"
    
    # Apply bonus additions multiplying with LOC gain: (1+LOC/L)
    # where L=250, 500 or 1000 according to version change type
    local loc_divisor=0
    case "$bump_type" in
        patch) loc_divisor=250 ;;
        minor) loc_divisor=500 ;;
        major) loc_divisor=1000 ;;
        *) loc_divisor=250 ;;
    esac
    
    local multiplier
    multiplier=$(awk "BEGIN {printf \"%.2f\", 1 + $loc / $loc_divisor}" 2>/dev/null || echo "1.0")
    printf '%s' "$multiplier"
}

# Mock the calculate_next_version function with the new logic
calculate_next_version() {
    local current_version="$1"
    local bump_type="$2"
    local loc="$3"
    local bonus="$4"

    if [[ -z "$current_version" ]] || [[ "$current_version" = "0.0.0" ]]; then
        case "$bump_type" in
            major) printf '1.0.0' ;;
            minor) printf '0.1.0' ;;
            patch) printf '0.0.1' ;;
            *) printf '0.0.0' ;;
        esac
        return
    fi

    # Validate VERSION format
    if [[ ! $current_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        current_version=0.0.0
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    # Calculate base delta from LOC
    local base_delta
    base_delta=$(calculate_loc_delta "$bump_type" "$loc")
    
    # Calculate bonus multiplier
    local bonus_multiplier
    bonus_multiplier=$(calculate_bonus_multiplier "$bump_type" "$loc")
    
    # Calculate total bonus with multiplier
    local total_bonus
    total_bonus=$(awk "BEGIN {printf \"%.0f\", $bonus * $bonus_multiplier}" 2>/dev/null || echo "$bonus")
    
    # Calculate total delta_z (base delta + total bonus)
    local delta_z=$((base_delta + total_bonus))
    
    # Ensure minimum delta_z of 1
    if [[ "$delta_z" -lt 1 ]]; then
        delta_z=1
    fi
    
    # Apply mathematical rollover system:
    # z_new = (z + delta_z) % MAIN_VERSION_MOD
    # delta_y = ((z + delta_z) - (z + delta_z) % MAIN_VERSION_MOD) / MAIN_VERSION_MOD
    # y_new = (y + delta_y) % MAIN_VERSION_MOD
    # delta_x = ((y + delta_y) - (y + delta_y) % MAIN_VERSION_MOD) / MAIN_VERSION_MOD
    # x_new = x + delta_x
    
    local new_z=$((patch + delta_z))
    local delta_y=$(((new_z - (new_z % MAIN_VERSION_MOD)) / MAIN_VERSION_MOD))
    local final_z=$((new_z % MAIN_VERSION_MOD))
    
    local new_y=$((minor + delta_y))
    local delta_x=$(((new_y - (new_y % MAIN_VERSION_MOD)) / MAIN_VERSION_MOD))
    local final_y=$((new_y % MAIN_VERSION_MOD))
    
    local final_x=$((major + delta_x))
    
    printf '%d.%d.%d' "$final_x" "$final_y" "$final_z"
}

# Test cases
echo "Test 1: 9.3.0 + patch bump (LOC=150, bonus=0) = $(calculate_next_version "9.3.0" "patch" 150 0)"
echo "Test 2: 9.3.95 + patch bump (LOC=300, bonus=0) = $(calculate_next_version "9.3.95" "patch" 300 0)"
echo "Test 3: 9.99.95 + patch bump (LOC=500, bonus=0) = $(calculate_next_version "9.99.95" "patch" 500 0)"
echo "Test 4: 9.3.0 + minor bump (LOC=1000, bonus=0) = $(calculate_next_version "9.3.0" "minor" 1000 0)"
echo "Test 5: 9.3.0 + major bump (LOC=2000, bonus=0) = $(calculate_next_version "9.3.0" "major" 2000 0)"
echo "Test 6: 9.3.0 + patch bump (LOC=100, bonus=5) = $(calculate_next_version "9.3.0" "patch" 100 5)"
echo "Test 7: 9.3.0 + minor bump (LOC=500, bonus=10) = $(calculate_next_version "9.3.0" "minor" 500 10)"
echo "Test 8: 9.3.98 + patch bump (LOC=500, bonus=0) = $(calculate_next_version "9.3.98" "patch" 500 0)"
echo "Test 9: 9.99.98 + patch bump (LOC=500, bonus=0) = $(calculate_next_version "9.99.98" "patch" 500 0)"
EOF

chmod +x /tmp/test_version_calc.sh

echo "Running version calculation tests..."
/tmp/test_version_calc.sh

echo ""
echo "Expected results:"
echo "Test 1: 9.3.0 + patch bump (LOC=150, bonus=0) = 9.3.2 (base_delta=1.6≈2)"
echo "Test 2: 9.3.95 + patch bump (LOC=300, bonus=0) = 9.3.97 (base_delta=2.2≈2, no rollover)"
echo "Test 3: 9.99.95 + patch bump (LOC=500, bonus=0) = 9.99.98 (base_delta=3, no rollover)"
echo "Test 4: 9.3.0 + minor bump (LOC=1000, bonus=0) = 9.3.15 (base_delta=15)"
echo "Test 5: 9.3.0 + major bump (LOC=2000, bonus=0) = 9.3.30 (base_delta=30)"
echo "Test 6: 9.3.0 + patch bump (LOC=100, bonus=5) = 9.3.8 (base_delta=1.4≈1 + bonus=5.4≈5)"
echo "Test 7: 9.3.0 + minor bump (LOC=500, bonus=10) = 9.3.30 (base_delta=10 + bonus=10)"
echo "Test 8: 9.3.98 + patch bump (LOC=500, bonus=0) = 9.4.1 (base_delta=3, rollover)"
echo "Test 9: 9.99.98 + patch bump (LOC=500, bonus=0) = 10.0.1 (base_delta=3, rollover)"

# Cleanup
rm -f /tmp/test_version_calc.sh

# Clean up the test directory
cleanup_temp_test_env "$test_dir"

echo ""
echo "Test completed!" 