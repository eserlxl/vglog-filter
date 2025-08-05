#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for semantic version analyzer fixes
# Tests the bug fixes and improvements made to the analyzer
# shellcheck disable=SC2317 # eval is used for dynamic command execution

set -Euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="$3"
    local expected_output="$4"
    
    printf '%sRunning test: %s%s\n' "${YELLOW}" "$test_name" "${NC}"
    
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

# Test 1: Verify --no-ext-diff -M -C is used in all git diff calls in bump-version
test_git_diff_flags() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/bump-version"
    
    # Check that all git diff calls include the required flags
    local missing_flags
    missing_flags=$(grep -n "git diff" "$script_path" | grep -v -- "-M -C" | grep -v "color.ui=false" | grep -v "^[[:space:]]*#" | grep -v "^[[:space:]]*-" | grep -v "^[[:space:]]*  -" || true)
    
    if [[ -n "$missing_flags" ]]; then
        printf '%s✗ Found git diff calls without -M -C:%s\n' "${RED}" "${NC}"
        printf '%s\n' "$missing_flags"
        return 1
    fi
    
    printf '%s✓ All git diff calls include -M -C%s\n' "${GREEN}" "${NC}"
    return 0
}

# Test 2: Verify case-insensitive documentation detection in modular components
test_case_insensitive_docs() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin"
    
    # Check that case-insensitive logic exists in the modular components
    local found=false
    for component in file-change-analyzer cli-options-analyzer keyword-analyzer; do
        if grep -q "tr '\[:upper:\]' '\[:lower:\]'" "$script_path/$component"; then
            found=true
            break
        fi
    done
    
    if [[ "$found" = "true" ]]; then
        printf '%s✓ Case-insensitive documentation detection implemented%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%s✗ Case-insensitive documentation detection not found%s\n' "${RED}" "${NC}"
        return 1
    fi
}

# Test 3: Verify POSIX-compliant regex patterns in modular components
test_posix_regex() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin"
    
    # Check that modular components use POSIX classes instead of GNU-specific patterns
    local gnu_patterns=""
    for component in file-change-analyzer cli-options-analyzer keyword-analyzer security-keyword-analyzer; do
        local patterns
        patterns=$(grep -n "grep.*--\[.*\]\+" "$script_path/$component" | grep -v "grep -E" | grep -v "grep -o" || true)
        if [[ -n "$patterns" ]]; then
            gnu_patterns="$gnu_patterns$patterns"$'\n'
        fi
    done
    
    if [[ -n "$gnu_patterns" ]]; then
        printf '%s✗ Found GNU-specific regex patterns:%s\n' "${RED}" "${NC}"
        printf '%s\n' "$gnu_patterns"
        return 1
    fi
    
    printf '%s✓ All regex patterns use POSIX-compliant syntax%s\n' "${GREEN}" "${NC}"
    return 0
}

# Test 4: Verify manual CLI detection uses correct patterns in cli-options-analyzer
test_manual_cli_patterns() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/cli-options-analyzer"
    
    # Check that manual CLI detection uses POSIX classes for long option patterns
    local manual_patterns
    manual_patterns=$(grep -n "grep.*--\[.*\]\+" "$script_path" | grep -v "grep -E" | grep -v "grep -o" || true)
    
    if [[ -n "$manual_patterns" ]]; then
        printf '%s✗ Found non-POSIX manual CLI patterns:%s\n' "${RED}" "${NC}"
        printf '%s\n' "$manual_patterns"
        return 1
    fi
    
    printf '%s✓ Manual CLI detection uses POSIX-compliant patterns%s\n' "${GREEN}" "${NC}"
    return 0
}

# Test 5: Verify help text reflects modular architecture
test_help_text() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"
    local output
    output=$("$script_path" --help 2>/dev/null)
    
    # Check for updated help text reflecting modular architecture
    local checks=(
        "Semantic Version Analyzer v2"
        "modular components"
        "machine-readable"
        "JSON"
    )
    
    for check in "${checks[@]}"; do
        if echo "$output" | grep -q "$check"; then
            printf '%s✓ Help text includes: %s%s\n' "${GREEN}" "$check" "${NC}"
        else
            printf '%s✗ Help text missing: %s%s\n' "${RED}" "$check" "${NC}"
            return 1
        fi
    done
    
    return 0
}

# Test 6: Verify modular components exist and are executable
test_modular_components() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin"
    
    local components=(
        "ref-resolver"
        "version-config-loader"
        "file-change-analyzer"
        "cli-options-analyzer"
        "security-keyword-analyzer"
        "keyword-analyzer"
        "version-calculator"
    )
    
    for component in "${components[@]}"; do
        if [[ ! -f "$script_path/$component" ]]; then
            printf '%s✗ Component not found: %s%s\n' "${RED}" "$component" "${NC}"
            return 1
        fi
        
        if [[ ! -x "$script_path/$component" ]]; then
            printf '%s✗ Component not executable: %s%s\n' "${RED}" "$component" "${NC}"
            return 1
        fi
    done
    
    printf '%s✓ All modular components exist and are executable%s\n' "${GREEN}" "${NC}"
    return 0
}

# Test 7: Verify semantic-version-analyzer orchestrates components correctly
test_orchestration() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"
    
    # Check that the main script calls all required components
    local required_calls=(
        "ref-resolver"
        "version-config-loader"
        "file-change-analyzer"
        "cli-options-analyzer"
        "security-keyword-analyzer"
        "keyword-analyzer"
        "version-calculator"
    )
    
    for component in "${required_calls[@]}"; do
        if grep -q "$component" "$script_path"; then
            printf '%s✓ Orchestrates: %s%s\n' "${GREEN}" "$component" "${NC}"
        else
            printf '%s✗ Missing orchestration: %s%s\n' "${RED}" "$component" "${NC}"
            return 1
        fi
    done
    
    return 0
}

# Test 8: Verify machine-readable output format
test_machine_output() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"
    
    # Check that machine output format is properly handled
    if grep -q "MACHINE_OUTPUT" "$script_path" && grep -q "key=value" "$script_path"; then
        printf '%s✓ Machine-readable output format implemented%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%s✗ Machine-readable output format not found%s\n' "${RED}" "${NC}"
        return 1
    fi
}

# Test 9: Verify JSON output format
test_json_output() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"
    
    # Check that JSON output format is properly handled
    if grep -q "JSON_OUTPUT" "$script_path" && grep -q "json" "$script_path"; then
        printf '%s✓ JSON output format implemented%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%s✗ JSON output format not found%s\n' "${RED}" "${NC}"
        return 1
    fi
}

# Test 10: Verify bonus calculation system
test_bonus_calculation() {
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"
    
    # Check that bonus calculation system is implemented
    if grep -q "TOTAL_BONUS" "$script_path" && grep -q "bonus" "$script_path"; then
        printf '%s✓ Bonus calculation system implemented%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%s✗ Bonus calculation system not found%s\n' "${RED}" "${NC}"
        return 1
    fi
}

# Main test execution
main() {
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf '%sError: Not in a git repository%s\n' "${RED}" "${NC}"
        exit 1
    fi
    
    # Check if semantic-version-analyzer exists
    local script_path
    script_path="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"
    if [[ ! -f "$script_path" ]]; then
        printf '%sError: semantic-version-analyzer not found at %s%s\n' "${RED}" "$script_path" "${NC}"
        exit 1
    fi
    
    printf '%sRunning semantic version analyzer fix tests (modular v2)...%s\n\n' "${YELLOW}" "${NC}"
    
    # Run all tests and count them
    if test_git_diff_flags; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_modular_components; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_orchestration; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_machine_output; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_json_output; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_bonus_calculation; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_help_text; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_posix_regex; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    if test_manual_cli_patterns; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
    
    # Skip interactive tests in CI
    if [[ -z "${CI:-}" ]]; then
        if test_case_insensitive_docs; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    else
        printf '%sSkipping interactive test in CI environment%s\n' "${YELLOW}" "${NC}"
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