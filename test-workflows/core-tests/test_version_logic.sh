#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Simple test script for version calculation logic

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Testing Version Calculation Logic (Direct)"
echo "========================================="

# Go to project root
cd ../../

# Test the calculate_next_version function directly by creating a test script
cat > /tmp/test_version_calc.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Mock the calculate_next_version function with the new logic
calculate_next_version() {
    local current_version="$1"
    local bump_type="$2"
    local delta="$3"

    if [[ -z "$current_version" ]] || [[ "$current_version" = "0.0.0" ]]; then
        case "$bump_type" in
            major) printf '1.0.0' ;;
            minor) printf '0.1.0' ;;
            patch) printf '0.0.1' ;;
            *) printf '0.0.0' ;;
        esac
        return
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    # New versioning system: always increase only the last identifier (patch)
    # Apply delta to patch and handle rollover with mod 100
    local new_patch=$((patch + delta))
    local new_minor=$minor
    local new_major=$major
    
    # Handle patch rollover: if patch + delta >= 100, apply mod 100 and increment minor
    if [[ "$new_patch" -ge 100 ]]; then
        new_patch=$((new_patch % 100))
        new_minor=$((minor + 1))
        
        # Handle minor rollover: if minor + 1 >= 100, apply mod 100 and increment major
        if [[ "$new_minor" -ge 100 ]]; then
            new_minor=$((new_minor % 100))
            new_major=$((major + 1))
        fi
    fi
    
    printf '%d.%d.%d' "$new_major" "$new_minor" "$new_patch"
}

# Test cases
echo "Test 1: 9.3.0 + patch delta 6 = $(calculate_next_version "9.3.0" "patch" 6)"
echo "Test 2: 9.3.95 + patch delta 6 = $(calculate_next_version "9.3.95" "patch" 6)"
echo "Test 3: 9.99.95 + patch delta 6 = $(calculate_next_version "9.99.95" "patch" 6)"
echo "Test 4: 9.3.0 + minor delta 16 = $(calculate_next_version "9.3.0" "minor" 16)"
echo "Test 5: 9.3.0 + major delta 37 = $(calculate_next_version "9.3.0" "major" 37)"
EOF

chmod +x /tmp/test_version_calc.sh

echo "Running version calculation tests..."
/tmp/test_version_calc.sh

echo ""
echo "Expected results:"
echo "Test 1: 9.3.0 + patch delta 6 = 9.3.6"
echo "Test 2: 9.3.95 + patch delta 6 = 9.4.1"
echo "Test 3: 9.99.95 + patch delta 6 = 10.0.1"
echo "Test 4: 9.3.0 + minor delta 16 = 9.3.16"
echo "Test 5: 9.3.0 + major delta 37 = 9.3.37"

# Cleanup
rm -f /tmp/test_version_calc.sh

echo ""
echo "Test completed!" 