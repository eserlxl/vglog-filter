#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive unit test for the semantic version analyzer

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="${3:-0}"
    local expected_output="${4:-}"
    
    echo "Testing: $test_name"
    echo "  Command: $test_command"
    
    # Run the test command
    local output
    local exit_code
    output=$(eval "$test_command" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    # Check exit code
    if [[ "$exit_code" == "$expected_exit" ]]; then
        log_success "✓ Exit code correct: $exit_code"
        ((TESTS_PASSED++))
    else
        log_error "✗ Exit code wrong: expected $expected_exit, got $exit_code"
        echo "  Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Check expected output
    if [[ -n "$expected_output" ]]; then
        if echo "$output" | grep -q "$expected_output"; then
            log_success "✓ Output contains expected: $expected_output"
        else
            log_error "✗ Output missing expected: $expected_output"
            echo "  Actual output: $output"
            ((TESTS_FAILED++))
            return 1
        fi
    fi
    
    echo
}

# Test 1: Basic functionality tests
test_basic_functionality() {
    echo "=== Testing Basic Functionality ==="
    
    # Test 1: Help command
    run_test "Help command" \
        "../dev-bin/semantic-version-analyzer --help" \
        "0" \
        "Semantic Version Analyzer"
    
    # Test 2: Invalid version format
    run_test "Invalid version format" \
        "../dev-bin/semantic-version-analyzer --dry-run --current-version invalid --commit-range HEAD~1..HEAD" \
        "1" \
        "Invalid version format"
    
    # Test 3: Missing --current-version argument
    run_test "Missing --current-version argument" \
        "../dev-bin/semantic-version-analyzer --current-version" \
        "1" \
        "requires a value"
    
    # Test 4: Missing --commit-range argument
    run_test "Missing --commit-range argument" \
        "../dev-bin/semantic-version-analyzer --commit-range" \
        "1" \
        "requires a value"
    
    # Test 5: Missing --config argument
    run_test "Missing --config argument" \
        "../dev-bin/semantic-version-analyzer --config" \
        "1" \
        "requires a value"
}

# Test 2: Configuration validation tests
test_configuration_validation() {
    echo "=== Testing Configuration Validation ==="
    
    # Test 1: Invalid LOC_CAP
    run_test "Invalid LOC_CAP" \
        "LOC_CAP=foo ../dev-bin/semantic-version-analyzer --help" \
        "1" \
        "must be a positive integer"
    
    # Test 2: Invalid RADIX
    run_test "Invalid RADIX" \
        "RADIX=bar ../dev-bin/semantic-version-analyzer --help" \
        "1" \
        "must be a positive integer"
    
    # Test 3: RADIX too small
    run_test "RADIX too small" \
        "RADIX=0 ../dev-bin/semantic-version-analyzer --help" \
        "1" \
        "must be greater than 1"
    
    # Test 4: Valid numeric configuration
    run_test "Valid numeric configuration" \
        "LOC_CAP=5000 RADIX=50 ../dev-bin/semantic-version-analyzer --help" \
        "0" \
        ""
}

# Test 3: Key features check
test_key_features() {
    echo "=== Testing Key Features ==="
    
    # Check if it has YAML configuration support
    if grep -q "yq eval" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has YAML configuration support"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No YAML configuration support detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has CI-friendly output
    if grep -q "VERSION_BUMP:" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has CI-friendly VERSION_BUMP output"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No CI-friendly output detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has extensible configuration
    if grep -q "\\-\\-config" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has --config option for extensible configuration"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No --config option detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has performance optimizations
    if grep -q "early exit" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has early exit performance optimization"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No early exit optimization detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has bonus system
    if grep -q "declare -A BONUS" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has bonus system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No bonus system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has multiplier system
    if grep -q "declare -A MULT" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has multiplier system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No multiplier system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has penalty system
    if grep -q "declare -A PEN" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has penalty system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No penalty system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has LOC capping
    if grep -q "LOC_CAP" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has LOC capping"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No LOC capping detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has version rollover
    if grep -q "RADIX" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has version rollover (RADIX)"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No version rollover detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has decision tree
    if grep -q "change_type" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has decision tree for change classification"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No decision tree detected"
        ((TESTS_FAILED++))
    fi
}

# Test 4: Pattern matching tests
test_pattern_matching() {
    echo "=== Testing Pattern Matching ==="
    
    # Check for breaking change patterns
    if grep -q "breaking change" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has breaking change pattern matching"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No breaking change pattern matching detected"
        ((TESTS_FAILED++))
    fi
    
    # Check for security vulnerability patterns
    if grep -q "cve-" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has CVE pattern matching"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No CVE pattern matching detected"
        ((TESTS_FAILED++))
    fi
    
    # Check for performance patterns
    if grep -q "perf|performance" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has performance pattern matching"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No performance pattern matching detected"
        ((TESTS_FAILED++))
    fi
    
    # Check for feature patterns
    if grep -q "feat:" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has feature pattern matching"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No feature pattern matching detected"
        ((TESTS_FAILED++))
    fi
    
    # Check for database schema patterns
    if grep -q "database schema" ../dev-bin/semantic-version-analyzer; then
        log_success "✓ Has database schema pattern matching"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No database schema pattern matching detected"
        ((TESTS_FAILED++))
    fi
}

# Test 5: Configuration file tests
test_configuration_file() {
    echo "=== Testing Configuration File ==="
    
    # Check if configuration file exists
    if [[ -f "../dev-config/versioning.yml" ]]; then
        log_success "✓ Configuration file exists"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ Configuration file not found"
        ((TESTS_FAILED++))
    fi
    
    # Check if configuration file has required sections
    if grep -q "base_deltas:" ../dev-config/versioning.yml; then
        log_success "✓ Configuration has base_deltas section"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ Configuration missing base_deltas section"
        ((TESTS_FAILED++))
    fi
    
    if grep -q "thresholds:" ../dev-config/versioning.yml; then
        log_success "✓ Configuration has thresholds section"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ Configuration missing thresholds section"
        ((TESTS_FAILED++))
    fi
    
    if grep -q "loc_divisors:" ../dev-config/versioning.yml; then
        log_success "✓ Configuration has loc_divisors section"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ Configuration missing loc_divisors section"
        ((TESTS_FAILED++))
    fi
    
    if grep -q "patterns:" ../dev-config/versioning.yml; then
        log_success "✓ Configuration has patterns section"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ Configuration missing patterns section"
        ((TESTS_FAILED++))
    fi
}

# Test 6: Basic functionality (if git repo available)
test_basic_git_functionality() {
    echo "=== Testing Basic Git Functionality ==="
    
    if git rev-parse --git-dir &>/dev/null; then
        log_info "Git repository detected, testing basic functionality"
        
        # Test that the analyzer can be called with basic arguments
        if ../dev-bin/semantic-version-analyzer --dry-run --current-version 1.0.0 --commit-range HEAD~1..HEAD &>/dev/null; then
            log_success "✓ Basic functionality works (exit code 0)"
            ((TESTS_PASSED++))
        else
            log_warn "⚠ Basic functionality test failed (may be expected in test environment)"
            ((TESTS_FAILED++))
        fi
    else
        log_info "No git repository, skipping basic functionality test"
    fi
}

# Main test function
main() {
    echo "Comprehensive Semantic Version Analyzer Test Suite"
    echo "================================================="
    echo
    
    # Check if analyzer exists
    if [[ ! -f "../dev-bin/semantic-version-analyzer" ]]; then
        log_error "✗ Semantic version analyzer not found: ../dev-bin/semantic-version-analyzer"
        exit 1
    fi
    
    log_success "✓ Found semantic version analyzer"
    echo
    
    # Run all test suites
    test_basic_functionality
    test_configuration_validation
    test_key_features
    test_pattern_matching
    test_configuration_file
    test_basic_git_functionality
    
    # Print summary
    echo "================================================="
    echo "Test Summary:"
    echo "  Tests Passed: $TESTS_PASSED"
    echo "  Tests Failed: $TESTS_FAILED"
    echo "  Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@" 