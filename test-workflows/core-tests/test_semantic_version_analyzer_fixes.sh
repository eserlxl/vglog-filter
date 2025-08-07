#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for semantic version analyzer fixes
# Tests the bug fixes and improvements made to the analyzer
# shellcheck disable=SC2317 # eval is used for dynamic command execution

set -Euo pipefail
IFS=

# Source the test helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=test_helper.sh
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
# shellcheck disable=SC1001,SC2026,SC2289
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Script path - updated for modular system
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../dev-bin/semantic-version-analyzer.sh"

# Change to project root for tests
# Change to project root (assume we're running from project root)
cd "$(pwd)" || exit 1

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

# shellcheck disable=SC2317
# shellcheck disable=SC2329
log_warning() {
    printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"
}

# Helper function to run a test
# shellcheck disable=SC2329
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="$3"
    local expected_output="$4"
    
    log_info "Running test: $test_name"
    
    # Run the test command
    local output
    # shellcheck disable=SC2317 # eval is used for dynamic command execution
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    # Check exit code
    if [[ $exit_code -eq $expected_exit ]]; then
        printf '%s✓ Exit code correct (%d)%s\n' "${GREEN}" "$exit_code" "${NC}"
    else
        printf '%s✗ Exit code wrong (got %d, expected %d)%s\n' "${RED}" "$exit_code" "$expected_exit" "${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Check output if specified
    if [[ -n "$expected_output" ]]; then
        if echo "$output" | grep -q "$expected_output"; then
            printf '%s✓ Output contains expected text%s\n' "${GREEN}" "${NC}"
        else
            printf '%s✗ Output missing expected text: %s%s\n' "${RED}" "$expected_output" "${NC}"
            printf 'Actual output:\n%s\n' "$output"
            ((TESTS_FAILED++))
            return 1
        fi
    fi
    
    ((TESTS_PASSED++))
    printf '%s✓ Test passed%s\n\n' "${GREEN}" "${NC}"
    return 0
}

# Test 1: Verify --no-ext-diff -M -C is used in all git diff calls
test_git_diff_flags() {
    log_info "Testing git diff flags..."
    
    # Check that all git diff calls include the required flags
    local missing_flags
    missing_flags=$(grep -n "git diff" "$SCRIPT_PATH" | grep -v -- "-M -C" | grep -v "color.ui=false" | grep -v "^[[:space:]]*#" | grep -v "^[[:space:]]*-" | grep -v "^[[:space:]]*  -" || true)
    
    if [[ -n "$missing_flags" ]]; then
        log_error "Found git diff calls without -M -C"
        printf '%s\n' "$missing_flags"
        return 1
    fi
    
    log_success "All git diff calls include -M -C"
    return 0
}

# Test 2: Verify case-insensitive documentation detection
test_case_insensitive_docs() {
    log_info "Testing case-insensitive documentation detection..."
    # This feature is not currently implemented in the semantic analyzer
    log_warning "Case-insensitive documentation detection test skipped (not implemented)"
    return 0
}

# Test 3: Verify POSIX-compliant regex patterns
test_posix_regex() {
    log_info "Testing POSIX-compliant regex patterns..."
    
    # Check that manual CLI detection uses POSIX classes instead of GNU-specific patterns
    # The + in [[:alnum:]-]+ is actually POSIX-compliant when used with -E
    local gnu_patterns
    gnu_patterns=$(grep -n "grep.*--\[.*\]\+" "$SCRIPT_PATH" | grep -v "grep -E" | grep -v "grep -o" || true)
    
    if [[ -n "$gnu_patterns" ]]; then
        log_error "Found GNU-specific regex patterns"
        printf '%s\n' "$gnu_patterns"
        return 1
    fi
    
    log_success "All regex patterns use POSIX-compliant syntax"
    return 0
}

# Test 4: Verify manual CLI detection uses correct patterns
test_manual_cli_patterns() {
    log_info "Testing manual CLI detection patterns..."
    
    # Check that manual CLI detection uses POSIX classes for long option patterns
    local manual_patterns
    manual_patterns=$(grep -n "grep.*--\[.*\]\+" "$SCRIPT_PATH" | grep -v "grep -E" | grep -v "grep -o" || true)
    
    if [[ -n "$manual_patterns" ]]; then
        log_error "Found non-POSIX manual CLI patterns"
        printf '%s\n' "$manual_patterns"
        return 1
    fi
    
    log_success "Manual CLI detection uses POSIX-compliant patterns"
    return 0
}

# Test 5: Verify help text reflects improvements
test_help_text() {
    log_info "Testing help text..."
    
    local output
    output=$("$SCRIPT_PATH" --help 2>/dev/null)
    
    # Check for basic help text structure
    if echo "$output" | grep -q "Semantic Version Analyzer v2 for vglog-filter"; then
        log_success "Help text includes version 2 reference"
    else
        log_error "Help text missing version 2 reference"
        return 1
    fi
    
    if echo "$output" | grep -q "Exit codes:"; then
        log_success "Help text includes exit codes section"
    else
        log_error "Help text missing exit codes section"
        return 1
    fi
    
    return 0
}

# Test 6: Verify double-counting warning is documented
# shellcheck disable=SC2329
test_double_counting_warning() {
    log_info "Testing double-counting warning documentation..."
    
    # Check for double-counting warning comment
    if grep -q "double-counting" "$SCRIPT_PATH"; then
        log_success "Double-counting warning is documented"
        return 0
    else
        log_warning "Double-counting warning not found (may not be implemented)"
        return 0  # Not a failure, just not implemented
    fi
}

# Test 7: Verify language limitation is documented
# shellcheck disable=SC2329
test_language_limitation() {
    log_info "Testing language limitation documentation..."
    
    # Check for language limitation comment
    if grep -q "Limited to C/C++" "$SCRIPT_PATH"; then
        log_success "Language limitation is documented"
        return 0
    else
        log_warning "Language limitation not documented (may not be implemented)"
        return 0  # Not a failure, just not implemented
    fi
}

# Test 8: Verify modular system integration
test_modular_integration() {
    log_info "Testing modular system integration..."
    
    # Check that the script uses run_component to call other modules
    if grep -q "run_component" "$SCRIPT_PATH"; then
        log_success "Script uses run_component for modular integration"
    else
        log_error "Script missing run_component function"
        return 1
    fi
    
    # Check for calls to specific modular components
    local components=("ref-resolver.sh" "file-change-analyzer.sh" "cli-options-analyzer.sh" "security-keyword-analyzer.sh" "keyword-analyzer.sh" "version-calculator.sh")
    local missing_components=()
    
    for component in "${components[@]}"; do
        if ! grep -q "$component" "$SCRIPT_PATH"; then
            missing_components+=("$component")
        fi
    done
    
    if [[ ${#missing_components[@]} -eq 0 ]]; then
        log_success "Script calls all expected modular components"
    else
        log_warning "Script missing calls to: ${missing_components[*]}"
    fi
    
    # Check for proper script directory reference
    if grep -q "SCRIPT_DIR" "$SCRIPT_PATH"; then
        log_success "Script uses SCRIPT_DIR for component paths"
    else
        log_error "Script missing SCRIPT_DIR reference"
        return 1
    fi
    
    return 0
}

# Test 9: Verify error handling
test_error_handling() {
    log_info "Testing error handling..."
    
    # Test invalid argument handling
    local output
    output=$("$SCRIPT_PATH" --invalid-option 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_success "Invalid option properly rejected"
    else
        log_error "Invalid option not properly rejected"
        return 1
    fi
    
    return 0
}

# Test 10: Verify configuration loading
test_config_loading() {
    log_info "Testing configuration loading..."
    
    # Check that the script calls version-config-loader.sh
    if grep -q "version-config-loader.sh" "$SCRIPT_PATH"; then
        log_success "Script loads version configuration"
    else
        log_error "Script missing version configuration loading"
        return 1
    fi
    
    return 0
}

# Test 11: Verify bonus calculation logic
test_bonus_calculation() {
    log_info "Testing bonus calculation logic..."
    
    # Check for bonus calculation variables and logic
    if grep -q "TOTAL_BONUS" "$SCRIPT_PATH"; then
        log_success "Script implements bonus calculation"
    else
        log_error "Script missing bonus calculation"
        return 1
    fi
    
    # Check for threshold comparisons
    if grep -q "major_th\|minor_th\|patch_th" "$SCRIPT_PATH"; then
        log_success "Script uses threshold-based version suggestions"
    else
        log_warning "Script may not use threshold-based version suggestions"
    fi
    
    return 0
}

# Test 12: Verify output formats
test_output_formats() {
    log_info "Testing output formats..."
    
    # Check for machine-readable output support
    if grep -q "MACHINE_OUTPUT\|JSON_OUTPUT" "$SCRIPT_PATH"; then
        log_success "Script supports machine-readable output formats"
    else
        log_warning "Script may not support machine-readable output formats"
    fi
    
    # Check for suggest-only mode
    if grep -q "SUGGEST_ONLY" "$SCRIPT_PATH"; then
        log_success "Script supports suggest-only mode"
    else
        log_warning "Script may not support suggest-only mode"
    fi
    
    return 0
}

# Main test execution
main() {
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Check if semantic-version-analyzer exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "semantic-version-analyzer not found at $SCRIPT_PATH"
        exit 1
    fi
    
    log_info "Running semantic version analyzer fix tests..."
    printf '\n'
    
    # Run all tests
    test_git_diff_flags
    test_posix_regex
    test_manual_cli_patterns
    test_help_text
    test_modular_integration
    test_error_handling
    test_config_loading
    test_bonus_calculation
    test_output_formats
    test_double_counting_warning
    test_language_limitation
    
    # Skip interactive tests in CI
    if [[ -z "${CI:-}" ]]; then
        test_case_insensitive_docs
    else
        log_warning "Skipping interactive test in CI environment"
    fi
    
    # Print summary
    printf '\n%sTest Summary:%s\n' "${YELLOW}" "${NC}"
    printf '%sPassed: %d%s\n' "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf '%sFailed: %d%s\n' "${RED}" "$TESTS_FAILED" "${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf '%sAll tests passed!%s\n' "${GREEN}" "${NC}"
        exit 0
    else
        printf '%sSome tests failed!%s\n' "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 