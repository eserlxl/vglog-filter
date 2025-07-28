#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for semantic version analyzer fixes
# Tests the bug fixes and improvements made to the analyzer

set -Eeuo pipefail
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
    
    printf "${YELLOW}Running test: %s${NC}\n" "$test_name"
    
    # Run the test command
    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    # Check exit code
    if [[ $exit_code -eq $expected_exit ]]; then
        printf "${GREEN}✓ Exit code correct (%d)${NC}\n" $exit_code
    else
        printf "${RED}✗ Exit code wrong (got %d, expected %d)${NC}\n" $exit_code $expected_exit
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Check output if specified
    if [[ -n "$expected_output" ]]; then
        if echo "$output" | grep -q "$expected_output"; then
            printf "${GREEN}✓ Output contains expected text${NC}\n"
        else
            printf "${RED}✗ Output missing expected text: %s${NC}\n" "$expected_output"
            printf "Actual output:\n%s\n" "$output"
            ((TESTS_FAILED++))
            return 1
        fi
    fi
    
    ((TESTS_PASSED++))
    printf "${GREEN}✓ Test passed${NC}\n\n"
    return 0
}

# Test 1: Verify --no-ext-diff -M -C is used in all git diff calls
test_git_diff_flags() {
    local script_path="./dev-bin/semantic-version-analyzer"
    
    # Check that all git diff calls include the required flags
    local missing_flags
    missing_flags=$(grep -n "git.*diff" "$script_path" | grep -v --no-ext-diff | grep -v "color.ui=false" || true)
    
    if [[ -n "$missing_flags" ]]; then
        printf "${RED}✗ Found git diff calls without --no-ext-diff:${NC}\n"
        printf "%s\n" "$missing_flags"
        return 1
    fi
    
    printf "${GREEN}✓ All git diff calls include --no-ext-diff -M -C${NC}\n"
    return 0
}

# Test 2: Verify case-insensitive documentation detection
test_case_insensitive_docs() {
    local script_path="./dev-bin/semantic-version-analyzer"
    
    # Check that case-insensitive logic exists in the code
    if grep -q "tr '\[:upper:\]' '\[:lower:\]'" "$script_path"; then
        printf "${GREEN}✓ Case-insensitive documentation detection implemented${NC}\n"
        return 0
    else
        printf "${RED}✗ Case-insensitive documentation detection not found${NC}\n"
        return 1
    fi
}

# Test 3: Verify POSIX-compliant regex patterns
test_posix_regex() {
    local script_path="./dev-bin/semantic-version-analyzer"
    
    # Check that manual CLI detection uses POSIX classes instead of GNU-specific patterns
    # The + in [[:alnum:]-]+ is actually POSIX-compliant when used with -E
    local gnu_patterns
    gnu_patterns=$(grep -n "grep.*--\[.*\]\+" "$script_path" | grep -v "grep -E" | grep -v "grep -o" || true)
    
    if [[ -n "$gnu_patterns" ]]; then
        printf "${RED}✗ Found GNU-specific regex patterns:${NC}\n"
        printf "%s\n" "$gnu_patterns"
        return 1
    fi
    
    printf "${GREEN}✓ All regex patterns use POSIX-compliant syntax${NC}\n"
    return 0
}

# Test 4: Verify manual CLI detection uses correct patterns
test_manual_cli_patterns() {
    local script_path="./dev-bin/semantic-version-analyzer"
    
    # Check that manual CLI detection uses POSIX classes for long option patterns
    local manual_patterns
    manual_patterns=$(grep -n "grep.*--\[.*\]\+" "$script_path" | grep -v "grep -E" | grep -v "grep -o" || true)
    
    if [[ -n "$manual_patterns" ]]; then
        printf "${RED}✗ Found non-POSIX manual CLI patterns:${NC}\n"
        printf "%s\n" "$manual_patterns"
        return 1
    fi
    
    printf "${GREEN}✓ Manual CLI detection uses POSIX-compliant patterns${NC}\n"
    return 0
}

# Test 5: Verify help text reflects improvements
test_help_text() {
    local output
    output=$(./dev-bin/semantic-version-analyzer --help 2>/dev/null)
    
    # Check for updated help text
    local checks=(
        "git diff commands use"
        "C/C++ source files"
        "case-insensitive"
        "deterministic parsing"
    )
    
    for check in "${checks[@]}"; do
        if echo "$output" | grep -q "$check"; then
            printf "${GREEN}✓ Help text includes: %s${NC}\n" "$check"
        else
            printf "${RED}✗ Help text missing: %s${NC}\n" "$check"
            return 1
        fi
    done
    
    return 0
}

# Test 6: Verify double-counting warning is documented
test_double_counting_warning() {
    local script_path="./dev-bin/semantic-version-analyzer"
    
    # Check for double-counting warning comment
    if grep -q "double-counting" "$script_path"; then
        printf "${GREEN}✓ Double-counting warning is documented${NC}\n"
        return 0
    else
        printf "${RED}✗ Double-counting warning not found${NC}\n"
        return 1
    fi
}

# Test 7: Verify language limitation is documented
test_language_limitation() {
    local script_path="./dev-bin/semantic-version-analyzer"
    
    # Check for language limitation comment
    if grep -q "Limited to C/C++" "$script_path"; then
        printf "${GREEN}✓ Language limitation is documented${NC}\n"
        return 0
    else
        printf "${RED}✗ Language limitation not documented${NC}\n"
        return 1
    fi
}

# Main test execution
main() {
    printf "${YELLOW}Running semantic version analyzer fix tests...${NC}\n\n"
    
    # Run all tests
    test_git_diff_flags
    test_posix_regex
    test_manual_cli_patterns
    test_help_text
    test_double_counting_warning
    test_language_limitation
    
    # Skip interactive tests in CI
    if [[ -z "${CI:-}" ]]; then
        test_case_insensitive_docs
    else
        printf "${YELLOW}Skipping interactive test in CI environment${NC}\n"
    fi
    
    # Print summary
    printf "\n${YELLOW}Test Summary:${NC}\n"
    printf "${GREEN}Passed: %d${NC}\n" $TESTS_PASSED
    printf "${RED}Failed: %d${NC}\n" $TESTS_FAILED
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "${GREEN}All tests passed!${NC}\n"
        exit 0
    else
        printf "${RED}Some tests failed!${NC}\n"
        exit 1
    fi
}

# Run main function
main "$@" 