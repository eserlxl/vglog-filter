#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for pure mathematical versioning system
# Tests bonus point calculations and version bump decisions

set -Euo pipefail
IFS=

# Source the test helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

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

# Script path
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../dev-bin/semantic-version-analyzer.sh"

# Helper functions
# shellcheck disable=SC2317
log_info() {
    printf "%s[INFO]%s %s\n" "${BLUE}" "${NC}" "$1"
}

# shellcheck disable=SC2317
log_success() {
    printf "%s[PASS]%s %s\n" "${GREEN}" "${NC}" "$1"
    ((TESTS_PASSED++))
}

# shellcheck disable=SC2317
log_error() {
    printf "%s[FAIL]%s %s\n" "${RED}" "${NC}" "$1"
    ((TESTS_FAILED++))
}

# shellcheck disable=SC2317
log_warning() {
    printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"
}

# Test function
# shellcheck disable=SC2317
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

# Test pure mathematical versioning system
test_pure_mathematical_versioning() {
    log_info "Testing pure mathematical versioning system..."
    
    local test_dir
    test_dir=$(create_temp_test_env "pure-math-bonus")
    cd "$test_dir" || exit 1
    
    # Create initial files
    mkdir -p src test doc
    echo "initial source code" > src/main.cpp
    echo "initial test code" > test/main_test.cpp
    echo "initial doc content" > doc/README.md
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Test 1: Small change with no bonuses (should be PATCH)
    echo "updated test code" > test/main_test.cpp
    git add test/main_test.cpp >/dev/null 2>&1
    git commit -m "Small update" >/dev/null 2>&1
    
    local output
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "patch" ]]; then
        log_success "Small change with no bonuses triggers PATCH (bonus >= 0)"
    else
        log_error "Small change should trigger PATCH, got: $output"
    fi
    
    # Test 2: Add new source files (should be PATCH due to bonus < 4)
    for i in {1..3}; do
        echo "new source code $i" > "src/new_file$i.cpp"
    done
    git add src/ >/dev/null 2>&1
    git commit -m "Add new source files" >/dev/null 2>&1
    
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "patch" ]]; then
        log_success "New source files trigger PATCH (bonus < 4)"
    else
        log_error "New source files should trigger PATCH, got: $output"
    fi
    
    # Test 3: Add breaking changes (should be PATCH due to bonus < 8)
    echo "// Breaking API change" > src/breaking_api.cpp
    echo "// Removed CLI option" > src/breaking_cli.cpp
    git add src/ >/dev/null 2>&1
    git commit -m "Add breaking changes" >/dev/null 2>&1
    
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "patch" ]]; then
        log_success "Breaking changes trigger PATCH (bonus < 8)"
    else
        log_error "Breaking changes should trigger PATCH, got: $output"
    fi
    
    # Test 4: Verify pure mathematical versioning in verbose output
    local verbose_output
    verbose_output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$verbose_output" == *"PURE MATHEMATICAL VERSIONING SYSTEM"* ]]; then
        log_success "Pure mathematical versioning system detected in verbose output"
    else
        log_error "Pure mathematical versioning system not detected in verbose output"
    fi
    
    if [[ "$verbose_output" == *"Major: Total bonus >="* ]]; then
        log_success "Major bonus threshold displayed"
    else
        log_error "Major bonus threshold not displayed"
    fi
    
    if [[ "$verbose_output" == *"Minor: Total bonus >="* ]]; then
        log_success "Minor bonus threshold displayed"
    else
        log_error "Minor bonus threshold not displayed"
    fi
    
    if [[ "$verbose_output" == *"Patch: Total bonus >="* ]]; then
        log_success "Patch bonus threshold displayed"
    else
        log_error "Patch bonus threshold not displayed"
    fi
    
    if [[ "$verbose_output" == *"No minimum thresholds or extra rules"* ]]; then
        log_success "No extra rules message displayed"
    else
        log_error "No extra rules message not displayed"
    fi
    
    # Test 5: Test JSON output with bonus information
    local json_output
    json_output=$("$SCRIPT_PATH" --json --repo-root "$test_dir" 2>&1)
    
    if [[ "$json_output" == *'"suggestion"'* ]]; then
        log_success "JSON output contains suggestion field"
    else
        log_error "JSON output missing suggestion field"
    fi
    
    if [[ "$json_output" == *'"reason"'* ]]; then
        log_success "JSON output contains reason field"
    else
        log_error "JSON output missing reason field"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test bonus point calculations
test_bonus_point_calculations() {
    log_info "Testing bonus point calculations..."
    
    local test_dir
    test_dir=$(create_temp_test_env "bonus-calculations")
    cd "$test_dir" || exit 1
    
    # Create initial files
    mkdir -p src test doc
    echo "initial source code" > src/main.cpp
    echo "initial test code" > test/main_test.cpp
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Test 1: Security keywords (should add bonus points)
    echo "// Fix security vulnerability CVE-2024-1234" > src/security_fix.cpp
    git add src/security_fix.cpp >/dev/null 2>&1
    git commit -m "Fix security vulnerability" >/dev/null 2>&1
    
    local output
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "patch" ]]; then
        log_success "Security keywords add bonus points (triggered $output)"
    else
        log_error "Security keywords should add bonus points, got: $output"
    fi
    
    # Test 2: CLI changes (should add bonus points)
    echo "// Add new CLI option --new-feature" > src/cli_changes.cpp
    git add src/cli_changes.cpp >/dev/null 2>&1
    git commit -m "Add new CLI option" >/dev/null 2>&1
    
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "patch" ]]; then
        log_success "CLI changes add bonus points (triggered $output)"
    else
        log_error "CLI changes should add bonus points, got: $output"
    fi
    
    # Test 3: Large LOC changes (should add bonus points)
    for i in {1..100}; do
        echo "// Large change line $i" >> src/large_change.cpp
    done
    git add src/large_change.cpp >/dev/null 2>&1
    git commit -m "Large LOC change" >/dev/null 2>&1
    
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "patch" ]]; then
        log_success "Large LOC changes add bonus points (triggered $output)"
    else
        log_error "Large LOC changes should add bonus points, got: $output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test mathematical consistency
test_mathematical_consistency() {
    log_info "Testing mathematical consistency..."
    
    local test_dir
    test_dir=$(create_temp_test_env "math-consistency")
    cd "$test_dir" || exit 1
    
    # Create initial files
    echo "initial content" > test.txt
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Make a change
    echo "updated content" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Update content" >/dev/null 2>&1
    
    # Test that multiple runs produce identical results
    local output1 output2 output3
    output1=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    output2=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    output3=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output1" = "$output2" ]] && [[ "$output2" = "$output3" ]]; then
        log_success "Mathematical consistency - identical results across multiple runs"
    else
        log_error "Mathematical inconsistency - results differ: $output1, $output2, $output3"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Main test execution
main() {
    printf '%s=== Pure Mathematical Versioning System Tests ===%s\n' "${YELLOW}" "${NC}"
    
    test_pure_mathematical_versioning
    test_bonus_point_calculations
    test_mathematical_consistency
    
    printf '\n%s=== Test Summary ===%s\n' "${YELLOW}" "${NC}"
    printf '%sTests passed: %d%s\n' "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf '%sTests failed: %d%s\n' "${RED}" "$TESTS_FAILED" "${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf '%sAll tests passed!%s\n' "${GREEN}" "${NC}"
        exit 0
    else
        printf '%sSome tests failed!%s\n' "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main 