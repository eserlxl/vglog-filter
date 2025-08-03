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
    cd "$temp_dir"
    
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
    
    cd "$test_dir"
    
    echo "=== Testing Basic Functionality ==="
    
    # Test 1: Help command
    run_test "Help command" \
        "$analyzer_path --help" \
        "0" \
        "Semantic Version Analyzer"
    
    # Test 2: Invalid version format
    run_test "Invalid version format" \
        "$analyzer_path --dry-run --current-version invalid --commit-range HEAD~1..HEAD" \
        "1" \
        "Invalid version format"
    
    # Test 3: Missing --current-version argument
    run_test "Missing --current-version argument" \
        "$analyzer_path --current-version" \
        "1" \
        "requires a value"
    
    # Test 4: Missing --commit-range argument
    run_test "Missing --commit-range argument" \
        "$analyzer_path --commit-range" \
        "1" \
        "requires a value"
    
    # Test 5: Missing --config argument
    run_test "Missing --config argument" \
        "$analyzer_path --config" \
        "1" \
        "requires a value"
}

# Test 2: Configuration validation tests
test_configuration_validation() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
    echo "=== Testing Configuration Validation ==="
    
    # Test 1: Invalid LOC_CAP
    run_test "Invalid LOC_CAP" \
        "LOC_CAP=foo $analyzer_path --help" \
        "1" \
        "must be a positive integer"
    
    # Test 2: Invalid RADIX
    run_test "Invalid RADIX" \
        "RADIX=bar $analyzer_path --help" \
        "1" \
        "must be a positive integer"
    
    # Test 3: RADIX too small
    run_test "RADIX too small" \
        "RADIX=0 $analyzer_path --help" \
        "1" \
        "must be greater than 1"
    
    # Test 4: Valid numeric configuration
    run_test "Valid numeric configuration" \
        "LOC_CAP=5000 RADIX=50 $analyzer_path --help" \
        "0" \
        ""
}

# Test 3: Core version calculation tests
test_core_version_calculation() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
    echo "=== Testing Core Version Calculation ==="
    
    # Test 1: Basic patch increment (simple commit)
    create_test_commit "simple fix"
    run_test "Basic patch increment" \
        "$analyzer_path --dry-run --current-version 1.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 1.0.0 -> 1.0.1 (PATCH)"
    
    # Test 2: Breaking change
    create_test_commit "BREAKING CHANGE: api breaking change"
    run_test "Breaking change" \
        "$analyzer_path --dry-run --current-version 1.0.1 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 1.0.1 -> 2.0.0 (MAJOR)"
    
    # Test 3: Security vulnerability
    create_test_commit "fix: CVE-2024-1234 security vulnerability"
    run_test "Security vulnerability" \
        "$analyzer_path --dry-run --current-version 2.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 2.0.0 -> 2.1.0 (MINOR)"
    
    # Test 4: Performance improvement
    create_test_commit "perf: 50% performance improvement"
    run_test "Performance improvement" \
        "$analyzer_path --dry-run --current-version 2.1.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 2.1.0 -> 2.2.0 (MINOR)"
    
    # Test 5: New feature
    create_test_commit "feat: add new feature"
    run_test "New feature" \
        "$analyzer_path --dry-run --current-version 2.2.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 2.2.0 -> 2.3.0 (MINOR)"
    
    # Test 6: Database schema change
    create_test_commit "feat: database schema change"
    run_test "Database schema change" \
        "$analyzer_path --dry-run --current-version 2.3.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 2.3.0 -> 3.0.0 (MAJOR)"
}

# Test 4: Advanced features
test_advanced_features() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
    echo "=== Testing Advanced Features ==="
    
    # Test 1: Zero-day vulnerability
    create_test_commit "fix: zero-day vulnerability CVE-2024-5678"
    run_test "Zero-day vulnerability" \
        "$analyzer_path --dry-run --current-version 3.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 3.0.0 -> 3.1.0 (MINOR)"
    
    # Test 2: Production outage
    create_test_commit "fix: production outage issue"
    run_test "Production outage" \
        "$analyzer_path --dry-run --current-version 3.1.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 3.1.0 -> 3.2.0 (MINOR)"
    
    # Test 3: Customer request
    create_test_commit "feat: customer request implementation"
    run_test "Customer request" \
        "$analyzer_path --dry-run --current-version 3.2.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 3.2.0 -> 3.3.0 (MINOR)"
    
    # Test 4: Cross-platform support
    create_test_commit "feat: cross-platform support"
    run_test "Cross-platform support" \
        "$analyzer_path --dry-run --current-version 3.3.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 3.3.0 -> 3.4.0 (MINOR)"
    
    # Test 5: Memory safety
    create_test_commit "fix: memory safety issue"
    run_test "Memory safety" \
        "$analyzer_path --dry-run --current-version 3.4.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 3.4.0 -> 3.5.0 (MINOR)"
    
    # Test 6: Race condition
    create_test_commit "fix: race condition"
    run_test "Race condition" \
        "$analyzer_path --dry-run --current-version 3.5.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 3.5.0 -> 3.6.0 (MINOR)"
}

# Test 5: Edge cases
test_edge_cases() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
    echo "=== Testing Edge Cases ==="
    
    # Test 1: Large LOC changes
    # Create a large file to test LOC capping
    for i in {1..1000}; do
        echo "line $i" >> large_file.txt
    done
    git add large_file.txt
    git commit -m "feat: large file addition" >/dev/null 2>&1
    
    run_test "Large LOC changes" \
        "$analyzer_path --dry-run --current-version 1.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 1.0.0 -> 1.1.0 (MINOR)"
    
    # Test 2: Version rollover
    run_test "Version rollover test" \
        "$analyzer_path --dry-run --current-version 1.99.99 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 1.99.99 -> 2.0.0 (MAJOR)"
    
    # Test 3: Zero LOC changes
    git commit --allow-empty -m "empty commit" >/dev/null 2>&1
    run_test "Zero LOC changes" \
        "$analyzer_path --dry-run --current-version 2.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 2.0.0 -> 2.0.1 (PATCH)"
    
    # Test 4: Environment variable overrides
    run_test "Environment variable overrides" \
        "LOC_CAP=1000 RADIX=10 $analyzer_path --dry-run --current-version 2.0.1 --commit-range HEAD~1..HEAD" \
        "0" \
        "VERSION_BUMP: 2.0.1 -> 2.1.0 (MINOR)"
}

# Test 6: Verbose output
test_verbose_output() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
    echo "=== Testing Verbose Output ==="
    
    create_test_commit "feat: new feature with tests"
    
    # Test verbose output
    run_test "Verbose output" \
        "$analyzer_path --verbose --dry-run --current-version 1.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "=== Detailed Analysis ==="
    
    # Test verbose output contains specific sections
    local verbose_output
    verbose_output=$("$analyzer_path" --verbose --dry-run --current-version 1.0.0 --commit-range HEAD~1..HEAD 2>&1)
    
    if echo "$verbose_output" | grep -q "=== Configuration Used ==="; then
        log_success "✓ Verbose config section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose config section missing"
        ((TESTS_FAILED++))
    fi
    
    if echo "$verbose_output" | grep -q "=== Bonus Breakdown ==="; then
        log_success "✓ Verbose bonus section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose bonus section missing"
        ((TESTS_FAILED++))
    fi
    
    if echo "$verbose_output" | grep -q "=== Multiplier Breakdown ==="; then
        log_success "✓ Verbose multiplier section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose multiplier section missing"
        ((TESTS_FAILED++))
    fi
    
    if echo "$verbose_output" | grep -q "=== Penalty Breakdown ==="; then
        log_success "✓ Verbose penalty section present"
        ((TESTS_PASSED++))
    else
        log_error "✗ Verbose penalty section missing"
        ((TESTS_FAILED++))
    fi
}

# Test 7: Force flag
test_force_flag() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
    echo "=== Testing Force Flag ==="
    
    # Create initial version
    echo "1.0.0" > VERSION
    
    # Test actual file update with force
    create_test_commit "fix: minor fix"
    run_test "Actual file update with force" \
        "$analyzer_path --force --current-version 1.0.0 --commit-range HEAD~1..HEAD" \
        "0" \
        "Updated VERSION from 1.0.0 to 1.0.1"
    
    # Verify file was updated
    if [[ "$(cat VERSION)" == "1.0.1" ]]; then
        log_success "✓ VERSION file updated correctly"
        ((TESTS_PASSED++))
    else
        log_error "✗ VERSION file not updated correctly"
        ((TESTS_FAILED++))
    fi
}

# Test 8: YAML configuration
test_yaml_configuration() {
    local test_dir="$1"
    local analyzer_path="$2"
    
    cd "$test_dir"
    
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
    run_test "Custom YAML configuration" \
        "$analyzer_path --dry-run --current-version 1.0.0 --commit-range HEAD~1..HEAD --config custom_config.yml" \
        "0" \
        "VERSION_BUMP: 1.0.0 -> 1.0.2 (PATCH)"
    
    # Test missing YAML file
    run_test "Missing YAML file" \
        "$analyzer_path --dry-run --current-version 1.0.2 --commit-range HEAD~1..HEAD --config nonexistent.yml" \
        "0" \
        "VERSION_BUMP: 1.0.2 -> 1.0.3 (PATCH)"
}

# Test 9: Key features check
test_key_features() {
    echo "=== Testing Key Features ==="
    
    local analyzer_path="$1"
    
    # Check if it has YAML configuration support
    if grep -q "yq eval" "$analyzer_path"; then
        log_success "✓ Has YAML configuration support"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No YAML configuration support detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has CI-friendly output
    if grep -q "VERSION_BUMP:" "$analyzer_path"; then
        log_success "✓ Has CI-friendly VERSION_BUMP output"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No CI-friendly output detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has extensible configuration
    if grep -q "\\-\\-config" "$analyzer_path"; then
        log_success "✓ Has --config option for extensible configuration"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No --config option detected"
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
    if grep -q "declare -A BONUS" "$analyzer_path"; then
        log_success "✓ Has bonus system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No bonus system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has multiplier system
    if grep -q "declare -A MULT" "$analyzer_path"; then
        log_success "✓ Has multiplier system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No multiplier system detected"
        ((TESTS_FAILED++))
    fi
    
    # Check if it has penalty system
    if grep -q "declare -A PEN" "$analyzer_path"; then
        log_success "✓ Has penalty system"
        ((TESTS_PASSED++))
    else
        log_warn "⚠ No penalty system detected"
        ((TESTS_FAILED++))
    fi
}

# Main test function
main() {
    echo "Comprehensive Unified Semantic Version Analyzer Test"
    echo "=================================================="
    echo
    
    # Check if analyzer exists
    local analyzer_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../dev-bin/semantic-version-analyzer"
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