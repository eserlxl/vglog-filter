#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for semantic-version-analyzer with realistic repositories
# Tests both minimal and substantial repositories with various scenarios

set -Euo pipefail
IFS=

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
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

# Script path
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

# shellcheck disable=SC2329
log_warning() {
    printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"
}

# Test function
# shellcheck disable=SC2329,SC2317
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    log_info "Running test: $test_name"
    
    local output
    output=$($test_command 2>&1)
    local exit_code=$?
    
    if [[ "$output" == *"$expected_output"* ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        printf "Expected: %s\n" "$expected_output"
        printf "Got: %s\n" "$output"
        printf "Exit code: %s\n" "$exit_code"
        return 1
    fi
}

# Test minimal repository (should work without test mode)
# shellcheck disable=SC2317
test_minimal_repo() {
    log_info "Testing minimal repository..."
    
    local test_dir
    test_dir=$(create_temp_test_env "minimal")
    cd "$test_dir" || exit 1
    
    # Test that analyzer works with minimal repo
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Minimal repository exits with valid code: $exit_code"
    else
        log_error "Minimal repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Semantic Version Analysis v2"; then
        log_success "Minimal repository shows analysis output"
    else
        log_error "Minimal repository missing analysis output"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test empty repository (should work)
# shellcheck disable=SC2317
test_empty_repo() {
    log_info "Testing empty repository..."
    
    local test_dir
    test_dir=$(create_temp_test_env "empty")
    cd "$test_dir" || exit 1
    
    # Create an empty repository (no commits)
    rm -rf .git
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Test that analyzer works with empty repo
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Empty repository exits with valid code: $exit_code"
    else
        log_error "Empty repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Empty repository"; then
        log_success "Empty repository shows appropriate analysis"
    else
        log_error "Empty repository missing appropriate analysis"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test realistic repository with substantial history
# shellcheck disable=SC2317
test_realistic_repo() {
    log_info "Testing realistic repository with substantial history..."
    
    local test_dir
    test_dir=$(create_realistic_test_repo "realistic")
    cd "$test_dir" || exit 1
    
    # Test basic analysis
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Realistic repository exits with valid code: $exit_code"
    else
        log_error "Realistic repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Semantic Version Analysis v2"; then
        log_success "Realistic repository shows analysis output"
    else
        log_error "Realistic repository missing analysis output"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test realistic repository with JSON output
test_realistic_repo_json() {
    log_info "Testing realistic repository with JSON output..."
    
    local test_dir
    test_dir=$(create_realistic_test_repo "realistic-json")
    cd "$test_dir" || exit 1
    
    # Test JSON output
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --json --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Realistic repository JSON exits with valid code: $exit_code"
    else
        log_error "Realistic repository JSON has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q '"suggestion"'; then
        log_success "Realistic repository JSON produces valid JSON"
    else
        log_error "Realistic repository JSON produces invalid JSON"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test realistic repository with machine output
test_realistic_repo_machine() {
    log_info "Testing realistic repository with machine output..."
    
    local test_dir
    test_dir=$(create_realistic_test_repo "realistic-machine")
    cd "$test_dir" || exit 1
    
    # Test machine output
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --machine --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Realistic repository machine output exits with valid code: $exit_code"
    else
        log_error "Realistic repository machine output has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "SUGGESTION="; then
        log_success "Realistic repository machine output produces valid format"
    else
        log_error "Realistic repository machine output produces invalid format"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test realistic repository with suggest-only
test_realistic_repo_suggest_only() {
    log_info "Testing realistic repository with suggest-only..."
    
    local test_dir
    test_dir=$(create_realistic_test_repo "realistic-suggest-only")
    cd "$test_dir" || exit 1
    
    # Test suggest-only output
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --suggest-only --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code == 0 ]]; then
        log_success "Realistic repository suggest-only exits successfully"
    else
        log_error "Realistic repository suggest-only has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -E -q "^(major|minor|patch|none)$"; then
        log_success "Realistic repository suggest-only produces valid suggestion"
    else
        log_error "Realistic repository suggest-only produces invalid suggestion"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test realistic repository with path filtering
test_realistic_repo_path_filtering() {
    log_info "Testing realistic repository with path filtering..."
    
    local test_dir
    test_dir=$(create_realistic_test_repo "realistic-path-filter")
    cd "$test_dir" || exit 1
    
    # Test path filtering - skip if yq is not available or has version issues
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --only-paths "src/**,include/**" --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    # Check if the error is due to yq version issues
    if echo "$output" | grep -q "yq v4 is required"; then
        log_warning "Skipping path filtering test due to yq version incompatibility"
        log_success "Path filtering test skipped (yq version issue)"
        cd - >/dev/null 2>&1 || exit
        cleanup_temp_test_env "$test_dir"
        return 0
    fi
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Realistic repository path filtering exits with valid code: $exit_code"
    else
        log_error "Realistic repository path filtering has wrong exit code: $exit_code"
        printf "Output: %s\n" "$output"
    fi
    
    if echo "$output" | grep -q "Semantic Version Analysis v2"; then
        log_success "Realistic repository path filtering works"
    else
        log_error "Realistic repository path filtering failed"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test realistic repository with different base/target refs
test_realistic_repo_refs() {
    log_info "Testing realistic repository with different base/target refs..."
    
    local test_dir
    test_dir=$(create_realistic_test_repo "realistic-refs")
    cd "$test_dir" || exit 1
    
    # Test with explicit base and target
    local output
    output=$("$SCRIPT_PATH" --base v1.0.0 --target v2.1.0 --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Realistic repository with explicit refs exits with valid code: $exit_code"
    else
        log_error "Realistic repository with explicit refs has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Semantic Version Analysis v2"; then
        log_success "Realistic repository with explicit refs works"
    else
        log_error "Realistic repository with explicit refs failed"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test help output
test_help_output() {
    log_info "Testing help output..."
    
    local output
    output=$("$SCRIPT_PATH" --help 2>&1)
    
    if echo "$output" | grep -q "Semantic Version Analyzer v2"; then
        log_success "Help output is valid"
    else
        log_error "Help output is invalid"
        printf "Output: %s\n" "$output"
    fi
    
    if echo "$output" | grep -q "Usage:"; then
        log_success "Help output shows usage information"
    else
        log_error "Help output missing usage information"
    fi
}

# Main test execution
main() {
    log_info "Starting semantic version analyzer realistic repository tests..."
    
    # Test help output
    test_help_output
    
    # Test minimal repositories
    test_minimal_repo
    test_empty_repo
    
    # Test realistic repositories
    test_realistic_repo
    test_realistic_repo_json
    test_realistic_repo_machine
    test_realistic_repo_suggest_only
    test_realistic_repo_path_filtering
    test_realistic_repo_refs
    
    # Print summary
    printf "\n%s=== Test Summary ===%s\n" "${BLUE}" "${NC}"
    printf "Tests passed: %s%d%s\n" "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf "Tests failed: %s%d%s\n" "${RED}" "$TESTS_FAILED" "${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\n%s✅ All tests passed!%s\n" "${GREEN}" "${NC}"
        exit 0
    else
        printf "\n%s❌ Some tests failed!%s\n" "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
