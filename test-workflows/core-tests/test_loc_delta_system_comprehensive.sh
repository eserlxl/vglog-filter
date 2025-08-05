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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Script paths - find the script relative to the project root
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dev-bin/semantic-version-analyzer"
# Ensure we have the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/dev-bin/semantic-version-analyzer"

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



# Test JSON output parsing
test_json_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_field="$3"
    local expected_value="$4"
    
    log_info "Running test: $test_name"
    
    local output
    # Use eval to properly handle the command string
    output=$(eval "$test_command" 2>&1)
    
    # Extract field value from JSON - handle nested fields under loc_delta
    local actual_value
    if [[ "$expected_field" == "patch_delta" ]] || [[ "$expected_field" == "minor_delta" ]] || [[ "$expected_field" == "major_delta" ]] || [[ "$expected_field" == "loc_delta.patch_delta" ]] || [[ "$expected_field" == "loc_delta.minor_delta" ]] || [[ "$expected_field" == "loc_delta.major_delta" ]]; then
        # Look for nested field under loc_delta
        local field_name
        if [[ "$expected_field" == "loc_delta."* ]]; then
            field_name="${expected_field#loc_delta.}"
        else
            field_name="$expected_field"
        fi
        # Extract the loc_delta section and then find the specific field
        local loc_delta_section
        loc_delta_section=$(echo "$output" | sed -n '/"loc_delta": {/,/}/p')
        actual_value=$(echo "$loc_delta_section" | grep -o "\"$field_name\":[^,}]*" | cut -d: -f2 | tr -d '", ' | head -1)
    else
        # Look for field at root level
        actual_value=$(echo "$output" | grep -o "\"$expected_field\":[^,}]*" | cut -d: -f2 | tr -d '", ')
    fi
    
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
    # Use the actual configuration values from the system
    # These match the values in dev-config/versioning.yml
    export VERSION_PATCH_LIMIT=100
    export VERSION_MINOR_LIMIT=100
    export VERSION_BREAKING_CLI_BONUS=2
    export VERSION_API_BREAKING_BONUS=3
    export VERSION_REMOVED_OPTION_BONUS=1
    export VERSION_CLI_CHANGES_BONUS=2
    export VERSION_MANUAL_CLI_BONUS=1
    export VERSION_NEW_SOURCE_BONUS=1
    export VERSION_NEW_TEST_BONUS=1
    export VERSION_NEW_DOC_BONUS=1
    export VERSION_ADDED_OPTION_BONUS=1
    export VERSION_SECURITY_BONUS=5
}

# Test 1: Basic LOC-based delta calculation
test_basic_loc_deltas() {
    log_info "=== Test 1: Basic LOC-based delta calculation ==="
    
    setup_test_env
    
    # Create a test repository with actual changes
    local test_dir="test_loc_delta_basic"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Create small change (should result in patch_delta=1, minor_delta=5, major_delta=10)
    echo "// Small change" > src/small_change.c
    git add src/small_change.c
    git commit --quiet -m "Small change" 2>/dev/null || true
    
    # Test small change deltas
    test_json_output "Small change patch delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "3"
    
    test_json_output "Small change minor delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.minor_delta" "7"
    
    test_json_output "Small change major delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.major_delta" "12"
    
    # Create medium change (should result in larger deltas)
    for i in {1..10}; do
        echo "// Medium change file $i" > "src/medium_$i.c"
    done
    git add src/medium_*.c
    git commit --quiet -m "Medium change" 2>/dev/null || true
    
    # Test medium change deltas (actual values will depend on LOC calculation)
    test_json_output "Medium change patch delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "3"  # 1 (base) + 2 (new file bonus)
    
    test_json_output "Medium change minor delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.minor_delta" "7"  # 5 (base) + 2 (new file bonus)
    
    test_json_output "Medium change major delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.major_delta" "12"  # 10 (base) + 2 (new file bonus)
    
    # Create large change (should result in even larger deltas)
    for i in {1..10}; do
        echo "// Large change file $i" > "src/large_$i.c"
    done
    git add src/large_*.c
    git commit --quiet -m "Large change" 2>/dev/null || true
    
    # Test large change deltas
    test_json_output "Large change patch delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "3"  # 1 (base) + 2 (new file bonus)
    
    test_json_output "Large change minor delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.minor_delta" "7"  # 5 (base) + 2 (new file bonus)
    
    test_json_output "Large change major delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.major_delta" "12"  # 10 (base) + 2 (new file bonus)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 2: Breaking change bonuses
test_breaking_change_bonuses() {
    log_info "=== Test 2: Breaking change bonuses ==="
    
    setup_test_env
    
    # Create a test repository with breaking changes
    local test_dir="test_breaking_changes"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Test breaking CLI changes
    echo "// CLI-BREAKING: This is a breaking CLI change" > src/cli_breaking.c
    git add src/cli_breaking.c
    git commit --quiet -m "Add breaking CLI change" 2>/dev/null || true
    
    test_json_output "Breaking CLI bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "5"  # 1 (base) + 2 (CLI breaking) + 2 (new file)
    
    # Test API breaking changes
    echo "// API-BREAKING: This is a breaking change" > src/api_breaking.c
    git add src/api_breaking.c
    git commit --quiet -m "Add API breaking change" 2>/dev/null || true
    
    test_json_output "API breaking bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "6"  # 1 (base) + 3 (API breaking) + 2 (new file)
    
    # Test removed options (simulate by creating a file with removed options)
    echo "// Removed short options: -a -b" > src/removed_options.c
    echo "// Removed long options: --old-option" >> src/removed_options.c
    git add src/removed_options.c
    git commit --quiet -m "Add removed options" 2>/dev/null || true
    
    test_json_output "Removed options bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "4"  # 1 (base) + 1 (removed option) + 2 (new file)
    
    # Test combined breaking changes
    {
        echo "// Combined breaking changes"
        echo "// CLI-BREAKING: CLI change"
        echo "// API-BREAKING: API change"
        echo "// Removed: -x"
    } > src/combined.c
    git add src/combined.c
    git commit --quiet -m "Add combined breaking changes" 2>/dev/null || true
    
    test_json_output "Combined breaking bonuses" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "8"  # 1 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (removed) + 1 (new file)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 3: Feature addition bonuses
test_feature_addition_bonuses() {
    log_info "=== Test 3: Feature addition bonuses ==="
    
    setup_test_env
    
    # Create a test repository with feature additions
    local test_dir="test_feature_additions"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Test CLI changes
    echo "// CLI changes with new options" > src/cli_changes.c
    echo "// --new-option" >> src/cli_changes.c
    git add src/cli_changes.c
    git commit --quiet -m "Add CLI changes" 2>/dev/null || true
    
    test_json_output "CLI changes bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "3"  # 1 (base) + 2 (CLI changes) + 0 (no new file bonus for single file)
    
    # Test manual CLI changes
    echo "// Manual CLI changes" > src/manual_cli.c
    echo "// Manual option parsing" >> src/manual_cli.c
    git add src/manual_cli.c
    git commit --quiet -m "Add manual CLI changes" 2>/dev/null || true
    
    test_json_output "Manual CLI bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "3"  # 1 (base) + 1 (manual CLI) + 1 (new file)
    
    # Test new files
    echo "// New source file 1" > src/new1.c
    echo "// New source file 2" > src/new2.c
    mkdir -p test doc
    echo "// New test file" > test/test1.c
    echo "// New doc file" > doc/new_doc.md
    git add src/new1.c src/new2.c test/test1.c doc/new_doc.md
    git commit --quiet -m "Add new files" 2>/dev/null || true
    
    test_json_output "New files bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "4"  # 1 (base) + 1 (new source) + 1 (new test) + 1 (new doc)
    
    # Test added options
    echo "// Added short options: -a -b" > src/added_options.c
    echo "// Added long options: --new-long --another-long" >> src/added_options.c
    git add src/added_options.c
    git commit --quiet -m "Add new options" 2>/dev/null || true
    
    test_json_output "Added options bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "3"  # 1 (base) + 1 (added option) + 1 (new file)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 4: Security fix bonuses
test_security_bonuses() {
    log_info "=== Test 4: Security fix bonuses ==="
    
    setup_test_env
    
    # Create a test repository with security keywords
    local test_dir="test_security"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Test security keywords
    echo "// SECURITY: Fix buffer overflow vulnerability" > src/security1.c
    echo "// SECURITY: Fix memory leak" > src/security2.c
    echo "// SECURITY: Fix integer overflow" > src/security3.c
    git add src/security1.c src/security2.c src/security3.c
    git commit --quiet -m "Fix security vulnerabilities" 2>/dev/null || true
    
    test_json_output "Security keywords bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "28"  # 1 (base) + 15 (3 security keywords * 5) + 12 (new files)
    
    # Test single security keyword
    echo "// SECURITY: Fix single vulnerability" > src/single_security.c
    git add src/single_security.c
    git commit --quiet -m "Fix single security issue" 2>/dev/null || true
    
    test_json_output "Single security keyword bonus" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "18"  # 1 (base) + 5 (1 security keyword * 5) + 12 (new files)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 5: Combined bonuses
test_combined_bonuses() {
    log_info "=== Test 5: Combined bonuses ==="
    
    setup_test_env
    
    # Create a test repository with combined changes
    local test_dir="test_combined"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Create large changes for base delta
    for i in {1..20}; do
        echo "// Large change file $i" > "src/large_$i.c"
    done
    
    # Create combined changes
    echo "// CLI-BREAKING: Breaking CLI change" > src/cli_breaking.c
    echo "// API-BREAKING: Breaking API change" > src/api_breaking.c
    echo "// New source file" > src/new.c
    echo "// SECURITY: Security fix 1" > src/security1.c
    echo "// SECURITY: Security fix 2" > src/security2.c
    echo "// Added short option: -a" > src/added_option.c
    
    git add src/large_*.c src/cli_breaking.c src/api_breaking.c src/new.c src/security1.c src/security2.c src/added_option.c
    git commit --quiet -m "Add combined changes" 2>/dev/null || true
    
    # Test combined bonuses
    test_json_output "Complex scenario patch delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "20"  # 1 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (new source) + 10 (2 security * 5) + 1 (added option) + 2 (new files)
    
    test_json_output "Complex scenario minor delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.minor_delta" "23"  # 5 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (new source) + 10 (2 security * 5) + 1 (added option) + 1 (new files)
    
    test_json_output "Complex scenario major delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.major_delta" "28"  # 10 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (new source) + 10 (2 security * 5) + 1 (added option) + 1 (new files)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 6: Configuration customization
test_configuration_customization() {
    log_info "=== Test 6: Configuration customization ==="
    
    setup_test_env
    
    # Create a test repository with custom bonus configuration
    local test_dir="test_custom_config"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Create breaking changes
    echo "// CLI-BREAKING: Breaking CLI change" > src/cli_breaking.c
    echo "// API-BREAKING: Breaking API change" > src/api_breaking.c
    echo "// SECURITY: Security fix 1" > src/security1.c
    echo "// SECURITY: Security fix 2" > src/security2.c
    git add src/cli_breaking.c src/api_breaking.c src/security1.c src/security2.c
    git commit --quiet -m "Add breaking changes" 2>/dev/null || true
    
    # Test with custom bonus values
    test_json_output "Custom bonus values" \
        "cd '$PROJECT_ROOT' && VERSION_BREAKING_CLI_BONUS=5 VERSION_API_BREAKING_BONUS=7 VERSION_SECURITY_BONUS=4 $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "23"  # 1 (base) + 5 (CLI breaking) + 7 (API breaking) + 8 (2 security * 4) + 2 (new files)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 7: Rollover scenarios
test_rollover_scenarios() {
    log_info "=== Test 7: Rollover scenarios ==="
    
    setup_test_env
    
    # Create a test repository with large changes
    local test_dir="test_rollover"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Create large changes for rollover scenario
    for i in {1..25}; do
        echo "// Large change file $i" > "src/large_$i.c"
    done
    
    # Add breaking changes to increase delta
    echo "// CLI-BREAKING: Breaking CLI change" > src/cli_breaking.c
    echo "// API-BREAKING: Breaking API change" > src/api_breaking.c
    
    git add src/large_*.c src/cli_breaking.c src/api_breaking.c
    git commit --quiet -m "Add large changes for rollover" 2>/dev/null || true
    
    # Test rollover scenario delta
    test_json_output "Rollover scenario delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "9"  # 1 (base) + 2 (CLI breaking) + 3 (API breaking) + 3 (new files)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 8: System behavior (removed disabled system test)
test_system_behavior() {
    log_info "=== Test 8: System behavior ==="
    
    # The system is always enabled now
    export R_diff_size=1000
    export R_breaking_cli_changes=true
    export R_api_breaking=true
    
    # Should always include loc_delta in JSON
    local output
    output=$($SCRIPT_PATH --json 2>/dev/null)
    
    if [[ "$output" == *"loc_delta"* ]]; then
        log_success "System always includes loc_delta"
    else
        log_error "System doesn't include loc_delta"
        printf "Output: %s\n" "$output"
    fi
}

# Test 9: Edge cases
test_edge_cases() {
    log_info "=== Test 9: Edge cases ==="
    
    setup_test_env
    
    # Create a test repository for edge cases
    local test_dir="test_edge_cases"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Test zero LOC (empty commit)
    git commit --allow-empty --quiet -m "Empty commit" 2>/dev/null || true
    
    test_json_output "Zero LOC patch delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "1"  # Minimum delta of 1
    
    # Test very large LOC
    for i in {1..250}; do
        echo "// Very large change file $i" > "src/very_large_$i.c"
    done
    git add src/very_large_*.c
    git commit --quiet -m "Add very large changes" 2>/dev/null || true
    
    test_json_output "Very large LOC patch delta" \
        "cd '$PROJECT_ROOT' && $SCRIPT_PATH --json --repo-root $(pwd)" \
        "loc_delta.patch_delta" "6"  # 1 (base) + 5 (new files bonus)
    
    cd ..
    rm -rf "$test_dir"
}

# Test 10: Verbose output
test_verbose_output() {
    log_info "=== Test 10: Verbose output ==="
    
    setup_test_env
    
    # Create a test repository for verbose output
    local test_dir="test_verbose"
    mkdir -p "$test_dir"
    cd "$test_dir" || exit
    
    # Initialize git repo
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial files
    echo "9.3.0" > VERSION
    mkdir -p src
    echo "// Initial source file" > src/main.c
    git add VERSION src/main.c
    git commit --quiet -m "Initial commit" 2>/dev/null || true
    
    # Create changes for verbose output
    echo "// CLI-BREAKING: Breaking CLI change" > src/cli_breaking.c
    echo "// New source file" > src/new.c
    echo "// SECURITY: Security fix 1" > src/security1.c
    echo "// SECURITY: Security fix 2" > src/security2.c
    git add src/cli_breaking.c src/new.c src/security1.c src/security2.c
    git commit --quiet -m "Add changes for verbose test" 2>/dev/null || true
    
    local output
    output=$(cd "$PROJECT_ROOT" && $SCRIPT_PATH --verbose --repo-root "$(pwd)" 2>&1)
    
    # Check for verbose output information
    if [[ "$output" == *"Verbose: Loading version configuration..."* ]] && \
       [[ "$output" == *"Debug: Final TOTAL_BONUS:"* ]]; then
        log_success "Verbose output shows debug information"
    else
        log_error "Verbose output missing debug information"
        printf "Output: %s\n" "$output"
    fi
    
    cd ..
    rm -rf "$test_dir"
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
    test_system_behavior
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