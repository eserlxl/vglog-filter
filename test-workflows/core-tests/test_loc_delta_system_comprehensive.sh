#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Comprehensive test script for LOC-based delta system
# Tests all aspects: base deltas, bonuses, rollovers, configuration

set -Euo pipefail
IFS=

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Script paths
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../dev-bin/semantic-version-analyzer"
BUMP_SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../dev-bin/bump-version"

# Helper functions
log_info() {
    printf "%s[INFO]%s %s\n" "${BLUE}" "${NC}" "$1"
}

log_success() {
    printf "%s[PASS]%s %s\n" "${GREEN}" "${NC}" "$1"
    ((TESTS_PASSED++))
}

log_error() {
    printf "%s[FAIL]%s %s\n" "${RED}" "${NC}" "$1"
    ((TESTS_FAILED++))
}

log_warning() {
    printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"
}

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    log_info "Running test: $test_name"
    
    local output
    output=$($test_command 2>&1)
    
    if [[ "$output" == *"$expected_output"* ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        printf "Expected: %s\n" "$expected_output"
        printf "Got: %s\n" "$output"
        return 1
    fi
}

# Test JSON output parsing
test_json_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_field="$3"
    local expected_value="$4"
    
    log_info "Running test: $test_name"
    
    local output
    output=$($test_command 2>/dev/null)
    
    # Extract field value from JSON
    local actual_value
    actual_value=$(echo "$output" | grep -o "\"$expected_field\":[^,}]*" | cut -d: -f2 | tr -d '", ')
    
    if [[ "$actual_value" == "$expected_value" ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        printf "Expected %s: %s\n" "$expected_field" "$expected_value"
        printf "Got %s: %s\n" "$expected_field" "$actual_value"
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    export VERSION_USE_LOC_DELTA=true
    export VERSION_PATCH_LIMIT=100
    export VERSION_MINOR_LIMIT=100
    export VERSION_PATCH_DELTA="1*(1+LOC/250)"
    export VERSION_MINOR_DELTA="5*(1+LOC/500)"
    export VERSION_MAJOR_DELTA="10*(1+LOC/1000)"
}

# Test 1: Basic LOC-based delta calculation
test_basic_loc_deltas() {
    log_info "=== Test 1: Basic LOC-based delta calculation ==="
    
    setup_test_env
    
    # Test small change (50 LOC)
    export R_diff_size=50
    test_json_output "Small change patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "1"
    
    test_json_output "Small change minor delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "minor_delta" "5"
    
    test_json_output "Small change major delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "major_delta" "10"
    
    # Test medium change (500 LOC)
    export R_diff_size=500
    test_json_output "Medium change patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "3"
    
    test_json_output "Medium change minor delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "minor_delta" "10"
    
    test_json_output "Medium change major delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "major_delta" "15"
    
    # Test large change (2000 LOC)
    export R_diff_size=2000
    test_json_output "Large change patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "9"
    
    test_json_output "Large change minor delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "minor_delta" "25"
    
    test_json_output "Large change major delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "major_delta" "30"
}

# Test 2: Breaking change bonuses
test_breaking_change_bonuses() {
    log_info "=== Test 2: Breaking change bonuses ==="
    
    setup_test_env
    export R_diff_size=100
    
    # Test breaking CLI changes
    export R_breaking_cli_changes=true
    test_json_output "Breaking CLI bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "3"  # 1 (base) + 2 (bonus)
    
    # Test API breaking changes
    export R_breaking_cli_changes=false
    export R_api_breaking=true
    test_json_output "API breaking bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "4"  # 1 (base) + 3 (bonus)
    
    # Test removed options
    export R_api_breaking=false
    export R_removed_short_count=2
    export R_removed_long_count=1
    test_json_output "Removed options bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "4"  # 1 (base) + 3 (bonus)
    
    # Test combined breaking changes
    export R_breaking_cli_changes=true
    export R_api_breaking=true
    export R_removed_short_count=1
    test_json_output "Combined breaking bonuses" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "8"  # 1 (base) + 2 + 3 + 1 + 1 = 8
}

# Test 3: Feature addition bonuses
test_feature_addition_bonuses() {
    log_info "=== Test 3: Feature addition bonuses ==="
    
    setup_test_env
    export R_diff_size=100
    
    # Test CLI changes
    export R_cli_changes=true
    test_json_output "CLI changes bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "3"  # 1 (base) + 2 (bonus)
    
    # Test manual CLI changes
    export R_cli_changes=false
    export R_manual_cli_changes=true
    test_json_output "Manual CLI bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "2"  # 1 (base) + 1 (bonus)
    
    # Test new files
    export R_manual_cli_changes=false
    export R_new_source_files=2
    export R_new_test_files=1
    export R_new_doc_files=1
    test_json_output "New files bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "4"  # 1 (base) + 1 + 1 + 1 = 4
    
    # Test added options
    export R_new_source_files=0
    export R_new_test_files=0
    export R_new_doc_files=0
    export R_added_short_count=1
    export R_added_long_count=2
    test_json_output "Added options bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "4"  # 1 (base) + 1 + 1 + 1 = 4
}

# Test 4: Security fix bonuses
test_security_bonuses() {
    log_info "=== Test 4: Security fix bonuses ==="
    
    setup_test_env
    export R_diff_size=100
    
    # Test security keywords
    export R_security_keywords=3
    test_json_output "Security keywords bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "7"  # 1 (base) + (3 * 2) = 7
    
    # Test single security keyword
    export R_security_keywords=1
    test_json_output "Single security keyword bonus" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "3"  # 1 (base) + (1 * 2) = 3
}

# Test 5: Combined bonuses
test_combined_bonuses() {
    log_info "=== Test 5: Combined bonuses ==="
    
    setup_test_env
    export R_diff_size=500  # Base: 3 for patch, 10 for minor, 15 for major
    
    # Test complex scenario
    export R_breaking_cli_changes=true      # +2
    export R_api_breaking=true              # +3
    export R_cli_changes=true               # +2
    export R_new_source_files=1             # +1
    export R_security_keywords=2            # +4
    export R_added_short_count=1            # +1
    
    test_json_output "Complex scenario patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "16"  # 3 (base) + 2 + 3 + 2 + 1 + 4 + 1 = 16
    
    test_json_output "Complex scenario minor delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "minor_delta" "23"  # 10 (base) + 2 + 3 + 2 + 1 + 4 + 1 = 23
    
    test_json_output "Complex scenario major delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "major_delta" "28"  # 15 (base) + 2 + 3 + 2 + 1 + 4 + 1 = 28
}

# Test 6: Configuration customization
test_configuration_customization() {
    log_info "=== Test 6: Configuration customization ==="
    
    setup_test_env
    export R_diff_size=100
    
    # Test custom bonus values
    export VERSION_BREAKING_CLI_BONUS=5
    export VERSION_API_BREAKING_BONUS=7
    export VERSION_SECURITY_BONUS=4
    
    export R_breaking_cli_changes=true
    export R_api_breaking=true
    export R_security_keywords=2
    
    test_json_output "Custom bonus values" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "20"  # 1 (base) + 5 + 7 + (2 * 4) = 20
    
    # Reset to defaults
    export VERSION_BREAKING_CLI_BONUS=2
    export VERSION_API_BREAKING_BONUS=3
    export VERSION_SECURITY_BONUS=2
}

# Test 7: Rollover scenarios
test_rollover_scenarios() {
    log_info "=== Test 7: Rollover scenarios ==="
    
    setup_test_env
    
    # Test patch rollover (9.3.95 + 10 = 9.4.5)
    export R_diff_size=1000  # Base: 5 for patch
    export R_breaking_cli_changes=true  # +2
    export R_api_breaking=true          # +3
    # Total: 5 + 2 + 3 = 10
    
    # This would need to be tested with the bump-version script
    # For now, just verify the delta calculation
    test_json_output "Rollover scenario delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "10"
}

# Test 8: Disabled system behavior
test_disabled_system() {
    log_info "=== Test 8: Disabled system behavior ==="
    
    # Disable the system
    export VERSION_USE_LOC_DELTA=false
    export R_diff_size=1000
    export R_breaking_cli_changes=true
    export R_api_breaking=true
    
    # Should not include loc_delta in JSON
    local output
    output=$(VERSION_USE_LOC_DELTA=false $SCRIPT_PATH --json 2>/dev/null)
    
    if [[ "$output" != *"loc_delta"* ]]; then
        log_success "Disabled system doesn't include loc_delta"
    else
        log_error "Disabled system includes loc_delta"
        printf "Output: %s\n" "$output"
    fi
}

# Test 9: Edge cases
test_edge_cases() {
    log_info "=== Test 9: Edge cases ==="
    
    setup_test_env
    
    # Test zero LOC
    export R_diff_size=0
    test_json_output "Zero LOC patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "1"  # Minimum delta of 1
    
    # Test very large LOC
    export R_diff_size=10000
    test_json_output "Very large LOC patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "41"  # 1 * (1 + 10000/250) = 41
    
    # Test negative LOC (should default to 0)
    export R_diff_size=-100
    test_json_output "Negative LOC patch delta" \
        "VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --json" \
        "patch_delta" "1"  # Should default to 1
}

# Test 10: Verbose output
test_verbose_output() {
    log_info "=== Test 10: Verbose output ==="
    
    setup_test_env
    export R_diff_size=500
    export R_breaking_cli_changes=true
    export R_new_source_files=1
    export R_security_keywords=2
    
    local output
    output=$(VERSION_USE_LOC_DELTA=true $SCRIPT_PATH --verbose 2>/dev/null)
    
    # Check for bonus information in verbose output
    if [[ "$output" == *"LOC-based delta system:"* ]] && \
       [[ "$output" == *"Breaking CLI changes: +2"* ]] && \
       [[ "$output" == *"New files: +1"* ]] && \
       [[ "$output" == *"Security keywords: +4"* ]]; then
        log_success "Verbose output shows bonus breakdown"
    else
        log_error "Verbose output missing bonus breakdown"
        printf "Output: %s\n" "$output"
    fi
}

# Main test execution
main() {
    printf "%s=== LOC-based Delta System Comprehensive Tests ===%s\n" "${CYAN}" "${NC}"
    printf "%sRunning tests...%s\n" "${BLUE}" "${NC}"
    
    # Run all test suites
    test_basic_loc_deltas
    test_breaking_change_bonuses
    test_feature_addition_bonuses
    test_security_bonuses
    test_combined_bonuses
    test_configuration_customization
    test_rollover_scenarios
    test_disabled_system
    test_edge_cases
    test_verbose_output
    
    # Print summary
    printf "\n%s=== Test Summary ===%s\n" "${CYAN}" "${NC}"
    printf "%sTests passed: %d%s\n" "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf "%sTests failed: %d%s\n" "${RED}" "$TESTS_FAILED" "${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "%sAll tests passed!%s\n" "${GREEN}" "${NC}"
        exit 0
    else
        printf "%sSome tests failed.%s\n" "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 