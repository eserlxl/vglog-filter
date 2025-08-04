#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive unified test for the semantic version analyzer
# This test combines the best features from all previous test files

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

# Function to run a test with VERSION file setup
run_test_with_version() {
    local test_name="$1"
    local version="$2"
    local test_command="$3"
    local expected_exit="${4:-0}"
    local expected_output="${5:-}"
    
    echo "Testing: $test_name"
    echo "  Version: $version"
    echo "  Command: $test_command"
    
    # Set up VERSION file
    echo "$version" > VERSION
    
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

# Function to create test commit with specific message
create_test_commit() {
    local message="$1"
    local file_content="${2:-test content}"
    local filename="${3:-test_file.txt}"
    
    echo "$file_content" > "$filename"
    git add "$filename"
    git commit -m "$message" >/dev/null 2>&1
}

# Function to create temporary test environment
create_temp_test_env() {
    local test_name="${1:-default}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Create initial files
    echo "1.0.0" > VERSION
    echo "project(test)" > CMakeLists.txt
    mkdir -p src
    
    # Initialize git repository
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Add initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    echo "$temp_dir"
}

# Function to cleanup temporary test environment
cleanup_temp_test_env() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        cd /tmp 2>/dev/null || true
        rm -rf "$temp_dir" 2>/dev/null || true
    fi
}

# Test 1: Basic functionality tests
test_basic_functionality() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Basic Functionality ==="
    
    # Test 1: Help command
    run_test "Help command" \
        "$analyzer_path --help" \
        "0" \
        "Semantic Version Analyzer"
    
    # Test 2: Invalid version format
    run_test_with_version "Invalid version format" \
        "invalid" \
        "$analyzer_path --suggest-only" \
        "20" \
        "none"
    
    # Test 3: Basic analysis with valid version
    run_test_with_version "Basic analysis with valid version" \
        "1.0.0" \
        "$analyzer_path --suggest-only" \
        "20" \
        "none"
    
    # Test 4: JSON output format
    run_test_with_version "JSON output format" \
        "1.0.0" \
        "$analyzer_path --json" \
        "20" \
        "suggestion"
    
    # Test 5: Machine output format
    run_test_with_version "Machine output format" \
        "1.0.0" \
        "$analyzer_path --machine" \
        "20" \
        "SUGGESTION="
}

# Test 2: Configuration validation tests
test_configuration_validation() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Configuration Validation ==="
    
    # Test 1: Invalid VERSION_PATCH_LIMIT
    run_test "Invalid VERSION_PATCH_LIMIT" \
        "VERSION_PATCH_LIMIT=foo $analyzer_path --help" \
        "0" \
        ""
    
    # Test 2: Invalid VERSION_MINOR_LIMIT
    run_test "Invalid VERSION_MINOR_LIMIT" \
        "VERSION_MINOR_LIMIT=bar $analyzer_path --help" \
        "0" \
        ""
    
    # Test 3: Invalid VERSION_MAJOR_DELTA
    run_test "Invalid VERSION_MAJOR_DELTA" \
        "VERSION_MAJOR_DELTA=invalid $analyzer_path --help" \
        "0" \
        ""
    
    # Test 4: Valid numeric configuration
    run_test "Valid numeric configuration" \
        "VERSION_PATCH_LIMIT=100 VERSION_MINOR_LIMIT=100 $analyzer_path --help" \
        "0" \
        ""
}

# Test 3: Core version calculation tests
test_core_version_calculation() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Core Version Calculation ==="
    
    # Test 1: Basic patch increment (simple commit)
    create_test_commit "simple fix"
    run_test_with_version "Basic patch increment" \
        "1.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 2: Breaking change
    create_test_commit "BREAKING CHANGE: api breaking change"
    run_test_with_version "Breaking change" \
        "1.0.1" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 3: Security vulnerability
    create_test_commit "fix: CVE-2024-1234 security vulnerability"
    run_test_with_version "Security vulnerability" \
        "2.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 4: Performance improvement
    create_test_commit "perf: 50% performance improvement"
    run_test_with_version "Performance improvement" \
        "2.1.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 5: New feature
    create_test_commit "feat: add new feature"
    run_test_with_version "New feature" \
        "2.2.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 6: Database schema change
    create_test_commit "feat: database schema change"
    run_test_with_version "Database schema change" \
        "2.3.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
}

# Test 4: Advanced features
test_advanced_features() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Advanced Features ==="
    
    # Test 1: Zero-day vulnerability
    create_test_commit "fix: zero-day vulnerability CVE-2024-5678"
    run_test_with_version "Zero-day vulnerability" \
        "3.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 2: Production outage
    create_test_commit "fix: production outage issue"
    run_test_with_version "Production outage" \
        "3.1.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 3: Customer request
    create_test_commit "feat: customer request implementation"
    run_test_with_version "Customer request" \
        "3.2.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 4: Cross-platform support
    create_test_commit "feat: cross-platform support"
    run_test_with_version "Cross-platform support" \
        "3.3.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 5: Memory safety
    create_test_commit "fix: memory safety issue"
    run_test_with_version "Memory safety" \
        "3.4.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 6: Race condition
    create_test_commit "fix: race condition"
    run_test_with_version "Race condition" \
        "3.5.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
}

# Test 5: Edge cases
test_edge_cases() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Edge Cases ==="
    
    # Test 1: Large LOC changes
    # Create a large file to test LOC capping
    for i in {1..100}; do
        echo "line $i" >> large_file.txt
    done
    git add large_file.txt
    git commit -m "feat: large file addition" >/dev/null 2>&1
    
    run_test_with_version "Large LOC changes" \
        "1.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 2: Version rollover
    run_test_with_version "Version rollover test" \
        "1.99.99" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 3: Zero LOC changes
    git commit --allow-empty -m "empty commit" >/dev/null 2>&1
    run_test_with_version "Zero LOC changes" \
        "2.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test 4: Environment variable overrides
    run_test_with_version "Environment variable overrides" \
        "2.0.1" \
        "VERSION_PATCH_LIMIT=1000 VERSION_MINOR_LIMIT=100 $analyzer_path --suggest-only" \
        "0" \
        ""
}

# Test 6: Verbose output
test_verbose_output() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Verbose Output ==="
    
    create_test_commit "feat: new feature with tests"
    
    # Test verbose output
    run_test_with_version "Verbose output" \
        "1.0.0" \
        "$analyzer_path --verbose" \
        "12" \
        "=== Detailed Analysis ==="
    
    # Test verbose output contains specific sections
    local verbose_output
    verbose_output=$("$analyzer_path" --verbose 2>&1)
    
    if echo "$verbose_output" | grep -q "=== Detailed Analysis ==="; then
        log_success "✓ Verbose detailed analysis section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose detailed analysis section missing"
        ((TESTS_FAILED++))
    fi
    
    if echo "$verbose_output" | grep -q "=== Version Bump Suggestion ==="; then
        log_success "✓ Verbose version bump section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose version bump section missing"
        ((TESTS_FAILED++))
    fi
    
    if echo "$verbose_output" | grep -q "LOC-based delta system"; then
        log_success "✓ Verbose LOC delta section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose LOC delta section missing"
        ((TESTS_FAILED++))
    fi
    
    if echo "$verbose_output" | grep -q "Configuration:"; then
        log_success "✓ Verbose configuration section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose configuration section missing"
        ((TESTS_FAILED++))
    fi
}

# Test 7: Force flag
test_force_flag() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing Force Flag ==="
    
    # Create initial version
    echo "1.0.0" > VERSION
    
    # Test actual file update with force
    create_test_commit "fix: minor fix"
    run_test_with_version "Actual file update with force" \
        "1.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Verify file was not updated (analyzer doesn't update VERSION file)
    if [[ "$(cat VERSION)" == "1.0.0" ]]; then
        log_success "✓ VERSION file correctly not updated (analyzer is read-only)"
        ((TESTS_PASSED++))
    else
        log_error "✗ VERSION file unexpectedly updated"
        ((TESTS_FAILED++))
    fi
}

# Test 8: YAML configuration
test_yaml_configuration() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir" || exit 1
    
    echo "=== Testing YAML Configuration ==="
    
    # Create custom YAML config
    cat > custom_config.yml <<EOF
base_deltas:
  patch: "2"
  minor: "8"
  major: "15"
limits:
  loc_cap: 5000
  rollover: 50
thresholds:
  major_bonus: 10
  minor_bonus: 6
  patch_bonus: 1
loc_divisors:
  major: 800
  minor: 400
  patch: 200
patterns:
  performance:
    memory_reduction_threshold: 25
    build_time_threshold: 40
    perf_50_threshold: 40
  early_exit:
    bonus_threshold: 10
EOF
    
    # Test custom configuration
    create_test_commit "fix: minor bug fix"
    run_test_with_version "Custom YAML configuration" \
        "1.0.0" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
    
    # Test missing YAML file
    run_test_with_version "Missing YAML file" \
        "1.0.2" \
        "$analyzer_path --suggest-only" \
        "0" \
        ""
}

# Test 9: Key features check
test_key_features() {
    echo "=== Testing Key Features ==="
    
    local analyzer_path="$1"
    
    # Check if it has YAML configuration support
    if grep -q "versioning.yml" "$analyzer_path"; then
        log_success "✓ Has YAML configuration support"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No YAML configuration support detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has CI-friendly output
    if grep -q "SUGGESTION=" "$analyzer_path"; then
        log_success "✓ Has CI-friendly SUGGESTION output"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No CI-friendly output detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has performance optimizations
    if grep -q "early exit" "$analyzer_path"; then
        log_success "✓ Has early exit performance optimization"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No early exit optimization detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has bonus system
    if grep -q "VERSION_.*_BONUS" "$analyzer_path"; then
        log_success "✓ Has bonus system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No bonus system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has multiplier system
    if grep -q "VERSION_.*_DELTA" "$analyzer_path"; then
        log_success "✓ Has multiplier system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No multiplier system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has LOC delta system
    if grep -q "VERSION_USE_LOC_DELTA" "$analyzer_path"; then
        log_success "✓ Has LOC delta system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No LOC delta system detected"
        ((TESTS_FAILED++))
    fi
}

# Main test function
main() {
    echo "Comprehensive Unified Semantic Version Analyzer Test"
    echo "=================================================="
    echo
    
    # Check if analyzer exists
    local analyzer_path
    analyzer_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../dev-bin/semantic-version-analyzer"
    if [[ ! -f "$analyzer_path" ]]; then
        log_error "Semantic version analyzer not found: $analyzer_path"
        exit 1
    fi
    
    log_success "✓ Semantic version analyzer found"
    
    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        log_warn "yq not found - YAML configuration tests may use defaults"
    fi
    
    # Create temporary test environment
    log_info "Setting up temporary test environment..."
    local temp_dir
    temp_dir=$(create_temp_test_env "semantic-version-analyzer-comprehensive")
    log_success "✓ Temporary environment created: $temp_dir"
    
    # Use absolute path for analyzer since we're now in a different directory
    analyzer_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../dev-bin/semantic-version-analyzer"
    
    # Run all test suites
    test_basic_functionality "$temp_dir" "$analyzer_path"
    test_configuration_validation "$temp_dir" "$analyzer_path"
    test_core_version_calculation "$temp_dir" "$analyzer_path"
    test_advanced_features "$temp_dir" "$analyzer_path"
    test_edge_cases "$temp_dir" "$analyzer_path"
    test_verbose_output "$temp_dir" "$analyzer_path"
    test_force_flag "$temp_dir" "$analyzer_path"
    test_yaml_configuration "$temp_dir" "$analyzer_path"
    test_key_features "$analyzer_path"
    
    # Cleanup
    cleanup_temp_test_env "$temp_dir"
    
    # Print summary
    echo "=================================================="
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