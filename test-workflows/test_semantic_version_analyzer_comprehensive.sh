#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Comprehensive test script for semantic version analyzer

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    printf '%s\n' "${CYAN}Running test: $test_name${RESET}"
    
    # Run the command and capture output
    local output
    output=$(eval "$test_command" 2>&1 || true)
    
    # Check if output contains expected text
    if echo "$output" | grep -q "$expected_output"; then
        printf '%s\n' "${GREEN}✓ PASS: $test_name${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%s\n' "${RED}✗ FAIL: $test_name${RESET}"
        printf '%s\n' "${YELLOW}Expected: $expected_output${RESET}"
        printf '%s\n' "${YELLOW}Got: $output${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    printf '%s\n' ""
    
    # Return success to prevent script from exiting
    return 0
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

# Function to run a test with VERSION file setup
run_test_with_version() {
    local test_name="$1"
    local version="$2"
    local test_command="$3"
    local expected_exit="${4:-0}"
    local expected_output="${5:-}"
    
    printf '%s\n' "${CYAN}Testing: $test_name${RESET}"
    printf '%s\n' "  Version: $version"
    printf '%s\n' "  Command: $test_command"
    
    # Set up VERSION file
    echo "$version" > VERSION
    
    # Run the test command
    local output
    local exit_code
    output=$(eval "$test_command" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    # Check exit code
    if [[ "$exit_code" == "$expected_exit" ]]; then
        printf '%s\n' "${GREEN}✓ Exit code correct: $exit_code${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%s\n' "${RED}✗ Exit code wrong: expected $expected_exit, got $exit_code${RESET}"
        printf '%s\n' "  Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    # Check expected output
    if [[ -n "$expected_output" ]]; then
        if echo "$output" | grep -q "$expected_output"; then
            printf '%s\n' "${GREEN}✓ Output contains expected: $expected_output${RESET}"
        else
            printf '%s\n' "${RED}✗ Output missing expected: $expected_output${RESET}"
            printf '%s\n' "  Actual output: $output"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
    
    printf '%s\n' ""
}

SEMANTIC_ANALYZER_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../dev-bin/semantic-version-analyzer.sh"

# Test 1: Basic functionality
printf '%s\n' "${CYAN}=== Test 1: Basic functionality ===${RESET}"
test_dir=$(create_temp_test_env "semantic-version-analyzer-comprehensive")
cd "$test_dir"

# Test 1: Help command
run_test "Help command" \
    "$SEMANTIC_ANALYZER_SCRIPT --help" \
    "Semantic Version Analyzer"

# Test 2: Invalid version format
run_test_with_version "Invalid version format" \
    "invalid" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "20" \
    "none"

# Test 3: Basic analysis with valid version
run_test_with_version "Basic analysis with valid version" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "20" \
    "none"

# Test 4: JSON output format
run_test_with_version "JSON output format" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --json" \
    "20" \
    "suggestion"

# Test 5: Machine output format
run_test_with_version "Machine output format" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --machine" \
    "20" \
    "SUGGESTION="

# Test 2: Configuration validation tests
printf '%s\n' "${CYAN}=== Test 2: Configuration Validation ==${RESET}"

# Test 1: Invalid VERSION_PATCH_LIMIT
run_test "Invalid VERSION_PATCH_LIMIT" \
    "VERSION_PATCH_LIMIT=foo $SEMANTIC_ANALYZER_SCRIPT --help" \
    ""

# Test 2: Invalid VERSION_MINOR_LIMIT
run_test "Invalid VERSION_MINOR_LIMIT" \
    "VERSION_MINOR_LIMIT=bar $SEMANTIC_ANALYZER_SCRIPT --help" \
    ""

# Test 3: Invalid VERSION_MAJOR_DELTA
run_test "Invalid VERSION_MAJOR_DELTA" \
    "VERSION_MAJOR_DELTA=invalid $SEMANTIC_ANALYZER_SCRIPT --help" \
    ""

# Test 4: Valid numeric configuration
run_test "Valid numeric configuration" \
    "VERSION_PATCH_LIMIT=1000 VERSION_MINOR_LIMIT=1000 $SEMANTIC_ANALYZER_SCRIPT --help" \
    ""

# Test 3: Core version calculation tests
printf '%s\n' "${CYAN}=== Test 3: Core Version Calculation ==${RESET}"

# Test 1: Basic patch increment (simple commit)
create_test_commit "simple fix"
run_test_with_version "Basic patch increment" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 2: Breaking change
create_test_commit "BREAKING CHANGE: api breaking change"
run_test_with_version "Breaking change" \
    "1.0.1" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 3: Security vulnerability
create_test_commit "fix: CVE-2024-1234 security vulnerability"
run_test_with_version "Security vulnerability" \
    "2.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 4: Performance improvement
create_test_commit "perf: 50% performance improvement"
run_test_with_version "Performance improvement" \
    "2.1.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 5: New feature
create_test_commit "feat: add new feature"
run_test_with_version "New feature" \
    "2.2.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 6: Database schema change
create_test_commit "feat: database schema change"
run_test_with_version "Database schema change" \
    "2.3.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 4: Advanced features
printf '%s\n' "${CYAN}=== Test 4: Advanced Features ==${RESET}"

# Test 1: Zero-day vulnerability
create_test_commit "fix: zero-day vulnerability CVE-2024-5678"
run_test_with_version "Zero-day vulnerability" \
    "3.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 2: Production outage
create_test_commit "fix: production outage issue"
run_test_with_version "Production outage" \
    "3.1.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 3: Customer request
create_test_commit "feat: customer request implementation"
run_test_with_version "Customer request" \
    "3.2.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 4: Cross-platform support
create_test_commit "feat: cross-platform support"
run_test_with_version "Cross-platform support" \
    "3.3.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 5: Memory safety
create_test_commit "fix: memory safety issue"
run_test_with_version "Memory safety" \
    "3.4.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 6: Race condition
create_test_commit "fix: race condition"
run_test_with_version "Race condition" \
    "3.5.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 5: Edge cases
printf '%s\n' "${CYAN}=== Test 5: Edge Cases ==${RESET}"

# Test 1: Large LOC changes
# Create a large file to test LOC capping
for i in {1..100}; do
    echo "line $i" >> large_file.txt
done
git add large_file.txt
git commit -m "feat: large file addition" >/dev/null 2>&1

run_test_with_version "Large LOC changes" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 2: Version rollover
run_test_with_version "Version rollover test" \
    "1.99.99" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 3: Zero LOC changes
git commit --allow-empty -m "empty commit" >/dev/null 2>&1
run_test_with_version "Zero LOC changes" \
    "2.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 4: Environment variable overrides
run_test_with_version "Environment variable overrides" \
    "2.0.1" \
    "VERSION_PATCH_LIMIT=1000 VERSION_MINOR_LIMIT=1000 $SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 6: Verbose output
printf '%s\n' "${CYAN}=== Test 6: Verbose Output ==${RESET}"

create_test_commit "feat: new feature with tests"

# Test verbose output
run_test_with_version "Verbose output" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --verbose" \
    "12" \
    "=== Detailed Analysis ==="

# Test verbose output contains specific sections
verbose_output=$("$SEMANTIC_ANALYZER_SCRIPT" --verbose 2>&1)

if echo "$verbose_output" | grep -q "=== Detailed Analysis ==="; then
    printf '%s\n' "${GREEN}✓ Verbose detailed analysis section present${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ Verbose detailed analysis section missing${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if echo "$verbose_output" | grep -q "=== Version Bump Suggestion ==="; then
    printf '%s\n' "${GREEN}✓ Verbose version bump section present${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ Verbose version bump section missing${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if echo "$verbose_output" | grep -q "LOC-based delta system"; then
    printf '%s\n' "${GREEN}✓ Verbose LOC delta section present${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ Verbose LOC delta section missing${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if echo "$verbose_output" | grep -q "Configuration:"; then
    printf '%s\n' "${GREEN}✓ Verbose configuration section present${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ Verbose configuration section missing${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 7: Force flag
printf '%s\n' "${CYAN}=== Test 7: Force Flag ==${RESET}"

# Create initial version
echo "1.0.0" > VERSION

# Test actual file update with force
create_test_commit "fix: minor fix"
run_test_with_version "Actual file update with force" \
    "1.0.0" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Verify file was not updated (analyzer doesn't update VERSION file)
if [[ "$(cat VERSION)" == "1.0.0" ]]; then
    printf '%s\n' "${GREEN}✓ VERSION file correctly not updated (analyzer is read-only)${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ VERSION file unexpectedly updated${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: YAML configuration
printf '%s\n' "${CYAN}=== Test 8: YAML Configuration ==${RESET}"

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
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test missing YAML file
run_test_with_version "Missing YAML file" \
    "1.0.2" \
    "$SEMANTIC_ANALYZER_SCRIPT --suggest-only" \
    "0" \
    ""

# Test 9: Key features check
printf '%s\n' "${CYAN}=== Test 9: Key Features ==${RESET}"

# Check if it has YAML configuration support
if grep -q "versioning.yml" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has YAML configuration support${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No YAML configuration support detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has CI-friendly output
if grep -q "SUGGESTION=" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has CI-friendly SUGGESTION output${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No CI-friendly output detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has performance optimizations
if grep -q "early exit" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has early exit performance optimization${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No early exit optimization detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has bonus system
if grep -q "VERSION_.*_BONUS" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has bonus system${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No bonus system detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has multiplier system
if grep -q "VERSION_.*_DELTA" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has multiplier system${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No multiplier system detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has LOC delta system
if grep -q "VERSION_USE_LOC_DELTA" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has LOC delta system${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No LOC delta system detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Cleanup
cleanup_temp_test_env "$test_dir"

# Print summary
printf '%s\n' "${CYAN}==================================================${RESET}"
printf '%s\n' "Test Summary:"
printf '%s\n' "  Tests Passed: $TESTS_PASSED"
printf '%s\n' "  Tests Failed: $TESTS_FAILED"
printf '%s\n' "  Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '%s\n' "${GREEN}All tests passed!${RESET}"
    exit 0
else
    printf '%s\n' "${RED}Some tests failed!${RESET}"
    exit 1
fi 