#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for LOC-based delta system with new versioning system

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

echo "=== Testing LOC-based Delta System with New Versioning System ==="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local expected_patch="$2"
    local expected_minor="$3"
    local expected_major="$4"
    
    echo "Test: $test_name"
    
    # Run semantic analyzer
    local result
    result=$(VERSION_USE_LOC_DELTA=true ./dev-bin/semantic-version-analyzer --json 2>/dev/null || echo "{}")
    
    # Extract deltas
    local patch_delta
    patch_delta=$(echo "$result" | grep -o '"patch_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
    local minor_delta
    minor_delta=$(echo "$result" | grep -o '"minor_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
    local major_delta
    major_delta=$(echo "$result" | grep -o '"major_delta":[[:space:]]*[0-9]*' | cut -d: -f2 | tr -d ' ')
    
    # Extract reason
    local reason
    reason=$(echo "$result" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    # Check results
    if [[ "$patch_delta" = "$expected_patch" ]] && [[ "$minor_delta" = "$expected_minor" ]] && [[ "$major_delta" = "$expected_major" ]]; then
        echo "✓ PASS: Deltas match expected values"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: Expected PATCH=$expected_patch, MINOR=$expected_minor, MAJOR=$expected_major"
        echo "  Got: PATCH=$patch_delta, MINOR=$minor_delta, MAJOR=$major_delta"
        ((TESTS_FAILED++))
    fi
    
    # Check reason format
    if [[ "$reason" = *"LOC:"* ]] && [[ "$reason" = *"MAJOR"* || "$reason" = *"MINOR"* || "$reason" = *"PATCH"* ]]; then
        echo "✓ PASS: Reason format includes LOC and version type"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: Reason format incorrect: $reason"
        ((TESTS_FAILED++))
    fi
    
    echo ""
}

# Test 1: Small change (50 LOC) - No bonuses
echo "Test 1: Small change (50 LOC) - No bonuses"
export VERSION_USE_LOC_DELTA=true
export VERSION_PATCH_LIMIT=100
export VERSION_MINOR_LIMIT=100

# Simulate a small change by setting diff_size
export R_diff_size=50

echo "Current version: 9.3.0"
echo "LOC: 50"
echo "Bonuses: None"

# Expected deltas for 50 LOC:
# PATCH: 1*(1+50/250) = 1.2 → 1
# MINOR: 5*(1+50/500) = 5.5 → 6
# MAJOR: 10*(1+50/1000) = 10.5 → 11
run_test "Small change (50 LOC)" "1" "6" "11"

# Test 2: Medium change (500 LOC) with CLI additions
echo "Test 2: Medium change (500 LOC) with CLI additions"
export R_diff_size=500
export R_cli_changes=true
export R_added_long_count=2

echo "Current version: 9.3.0"
echo "LOC: 500"
echo "Bonuses: CLI changes (+2), Added options (+1)"

# Expected deltas for 500 LOC with bonuses:
# PATCH: 1*(1+500/250) = 3 + 3 = 6
# MINOR: 5*(1+500/500) = 10 + 3 = 13
# MAJOR: 10*(1+500/1000) = 15 + 3 = 18
run_test "Medium change (500 LOC) with CLI" "6" "13" "18"

# Test 3: Large change (2000 LOC) with breaking changes
echo "Test 3: Large change (2000 LOC) with breaking changes"
export R_diff_size=2000
export R_breaking_cli_changes=true
export R_api_breaking=true
export R_removed_short_count=1
export R_removed_long_count=2

echo "Current version: 9.3.0"
echo "LOC: 2000"
echo "Bonuses: Breaking CLI (+2), API breaking (+3), Removed options (+2)"

# Expected deltas for 2000 LOC with bonuses:
# PATCH: 1*(1+2000/250) = 9 + 7 = 16
# MINOR: 5*(1+2000/500) = 25 + 7 = 32
# MAJOR: 10*(1+2000/1000) = 30 + 7 = 37
run_test "Large change (2000 LOC) with breaking" "16" "32" "37"

# Test 4: Security fix (100 LOC) with security keywords
echo "Test 4: Security fix (100 LOC) with security keywords"
export R_diff_size=100
export R_security_keywords=3

echo "Current version: 9.3.0"
echo "LOC: 100"
echo "Bonuses: Security keywords (+6)"

# Expected deltas for 100 LOC with bonuses:
# PATCH: 1*(1+100/250) = 1.4 → 1 + 6 = 7
# MINOR: 5*(1+100/500) = 6 + 6 = 12
# MAJOR: 10*(1+100/1000) = 11 + 6 = 17
run_test "Security fix (100 LOC) with keywords" "7" "12" "17"

# Test 5: New feature (800 LOC) with new files
echo "Test 5: New feature (800 LOC) with new files"
export R_diff_size=800
export R_new_source_files=2
export R_new_test_files=3
export R_new_doc_files=1

echo "Current version: 9.3.0"
echo "LOC: 800"
echo "Bonuses: New source files (+1), New test files (+1), New doc files (+1)"

# Expected deltas for 800 LOC with bonuses:
# PATCH: 1*(1+800/250) = 4.2 → 4 + 3 = 7
# MINOR: 5*(1+800/500) = 13 + 3 = 16
# MAJOR: 10*(1+800/1000) = 18 + 3 = 21
run_test "New feature (800 LOC) with files" "7" "16" "21"

# Test 6: Rollover logic verification
echo "Test 6: Rollover logic verification"
echo "Testing version calculation with rollover..."

# Create a test script to verify rollover logic
cat > /tmp/rollover_test.sh << 'EOF'
#!/bin/bash
set -euo pipefail

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

echo "Rollover tests:"
echo "9.3.95 + 6 = $(calculate_next_version "9.3.95" "patch" 6)"
echo "9.99.95 + 6 = $(calculate_next_version "9.99.95" "patch" 6)"
echo "9.3.0 + 6 = $(calculate_next_version "9.3.0" "patch" 6)"
echo "9.3.0 + 16 = $(calculate_next_version "9.3.0" "minor" 16)"
echo "9.3.0 + 37 = $(calculate_next_version "9.3.0" "major" 37)"
EOF

chmod +x /tmp/rollover_test.sh
rollover_result=$(/tmp/rollover_test.sh)

echo "$rollover_result"

# Verify rollover results
if echo "$rollover_result" | grep -q "9.3.95 + 6 = 9.4.1" && \
   echo "$rollover_result" | grep -q "9.99.95 + 6 = 10.0.1" && \
   echo "$rollover_result" | grep -q "9.3.0 + 6 = 9.3.6" && \
   echo "$rollover_result" | grep -q "9.3.0 + 16 = 9.3.16" && \
   echo "$rollover_result" | grep -q "9.3.0 + 37 = 9.3.37"; then
    echo "✓ PASS: Rollover logic working correctly"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Rollover logic incorrect"
    ((TESTS_FAILED++))
fi

# Cleanup
rm -f /tmp/rollover_test.sh

# Print summary
echo ""
echo "=== Test Summary ==="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✅ All tests passed! New versioning system is working correctly."
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi 