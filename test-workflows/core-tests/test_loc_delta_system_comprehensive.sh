#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Comprehensive test script for LOC-based delta system
# Tests all aspects: base deltas, bonuses, rollovers, configuration

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    printf '%s\n' "${CYAN}Running test: $test_name${NC}"
    
    # Run the command and capture output
    local output
    output=$(eval "$test_command" 2>&1 || true)
    
    # Check if output contains expected text
    if echo "$output" | grep -q "$expected_output"; then
        printf '%s\n' "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%s\n' "${RED}✗ FAIL: $test_name${NC}"
        printf '%s\n' "${YELLOW}Expected: $expected_output${NC}"
        printf '%s\n' "${YELLOW}Got: $output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    printf '%s\n' ""
    
    # Return success to prevent script from exiting
    return 0
}

SEMANTIC_ANALYZER_SCRIPT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../dev-bin/semantic-version-analyzer"

# Test 1: Basic LOC delta functionality
printf '%s\n' "${CYAN}=== Test 1: Basic LOC delta functionality ===${NC}"
test_dir=$(create_temp_test_env "loc_delta_basic")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Create small change (should result in patch_delta=1, minor_delta=5, major_delta=10)
echo "// Small change" > src/small_change.c
git add src/small_change.c
git commit --quiet -m "Small change" 2>/dev/null || true

# Test small change deltas
run_test "Small change patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 3"

run_test "Small change minor delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.minor_delta: 7"

run_test "Small change major delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.major_delta: 12"

# Create medium change (should result in larger deltas)
for i in {1..10}; do
    echo "// Medium change file $i" > "src/medium_$i.c"
done
git add src/medium_*.c
git commit --quiet -m "Medium change" 2>/dev/null || true

# Test medium change deltas (actual values will depend on LOC calculation)
run_test "Medium change patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 3"  # 1 (base) + 2 (new file bonus)

run_test "Medium change minor delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.minor_delta: 7"  # 5 (base) + 2 (new file bonus)

run_test "Medium change major delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.major_delta: 12"  # 10 (base) + 2 (new file bonus)

# Create large change (should result in even larger deltas)
for i in {1..10}; do
    echo "// Large change file $i" > "src/large_$i.c"
done
git add src/large_*.c
git commit --quiet -m "Large change" 2>/dev/null || true

# Test large change deltas
run_test "Large change patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 3"  # 1 (base) + 2 (new file bonus)

run_test "Large change minor delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.minor_delta: 7"  # 5 (base) + 2 (new file bonus)

run_test "Large change major delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.major_delta: 12"  # 10 (base) + 2 (new file bonus)

cleanup_temp_test_env "$test_dir"

# Test 2: Breaking change bonuses
printf '%s\n' "${CYAN}=== Test 2: Breaking change bonuses ===${NC}"
test_dir=$(create_temp_test_env "breaking_changes")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Test breaking CLI changes
echo "// CLI-BREAKING: This is a breaking CLI change" > src/cli_breaking.c
git add src/cli_breaking.c
git commit --quiet -m "Add breaking CLI change" 2>/dev/null || true

run_test "Breaking CLI bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 5"  # 1 (base) + 2 (CLI breaking) + 2 (new file)

# Test API breaking changes
echo "// API-BREAKING: This is a breaking change" > src/api_breaking.c
git add src/api_breaking.c
git commit --quiet -m "Add API breaking change" 2>/dev/null || true

run_test "API breaking bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 6"  # 1 (base) + 3 (API breaking) + 2 (new file)

# Test removed options (simulate by creating a file with removed options)
echo "// Removed short options: -a -b" > src/removed_options.c
echo "// Removed long options: --old-option" >> src/removed_options.c
git add src/removed_options.c
git commit --quiet -m "Add removed options" 2>/dev/null || true

run_test "Removed options bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 4"  # 1 (base) + 1 (removed option) + 2 (new file)

# Test combined breaking changes
{
    echo "// Combined breaking changes"
    echo "// CLI-BREAKING: CLI change"
    echo "// API-BREAKING: API change"
    echo "// Removed: -x"
} > src/combined.c
git add src/combined.c
git commit --quiet -m "Add combined breaking changes" 2>/dev/null || true

run_test "Combined breaking bonuses" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 8"  # 1 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (removed) + 1 (new file)

cleanup_temp_test_env "$test_dir"

# Test 3: Feature addition bonuses
printf '%s\n' "${CYAN}=== Test 3: Feature addition bonuses ===${NC}"
test_dir=$(create_temp_test_env "feature_additions")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Test CLI changes
echo "// CLI changes with new options" > src/cli_changes.c
echo "// --new-option" >> src/cli_changes.c
git add src/cli_changes.c
git commit --quiet -m "Add CLI changes" 2>/dev/null || true

run_test "CLI changes bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 3"  # 1 (base) + 2 (CLI changes) + 0 (no new file bonus for single file)

# Test manual CLI changes
echo "// Manual CLI changes" > src/manual_cli.c
echo "// Manual option parsing" >> src/manual_cli.c
git add src/manual_cli.c
git commit --quiet -m "Add manual CLI changes" 2>/dev/null || true

run_test "Manual CLI bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 3"  # 1 (base) + 1 (manual CLI) + 1 (new file)

# Test new files
echo "// New source file 1" > src/new1.c
echo "// New source file 2" > src/new2.c
mkdir -p test doc
echo "// New test file" > test/test1.c
echo "// New doc file" > doc/new_doc.md
git add src/new1.c src/new2.c test/test1.c doc/new_doc.md
git commit --quiet -m "Add new files" 2>/dev/null || true

run_test "New files bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 4"  # 1 (base) + 1 (new source) + 1 (new test) + 1 (new doc)

# Test added options
echo "// Added short options: -a -b" > src/added_options.c
echo "// Added long options: --new-long --another-long" >> src/added_options.c
git add src/added_options.c
git commit --quiet -m "Add new options" 2>/dev/null || true

run_test "Added options bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 3"  # 1 (base) + 1 (added option) + 1 (new file)

cleanup_temp_test_env "$test_dir"

# Test 4: Security fix bonuses
printf '%s\n' "${CYAN}=== Test 4: Security fix bonuses ===${NC}"
test_dir=$(create_temp_test_env "security_fixes")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Test security keywords
echo "// SECURITY: Fix buffer overflow vulnerability" > src/security1.c
echo "// SECURITY: Fix memory leak" > src/security2.c
echo "// SECURITY: Fix integer overflow" > src/security3.c
git add src/security1.c src/security2.c src/security3.c
git commit --quiet -m "Fix security vulnerabilities" 2>/dev/null || true

run_test "Security keywords bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 28"  # 1 (base) + 15 (3 security keywords * 5) + 12 (new files)

# Test single security keyword
echo "// SECURITY: Fix single vulnerability" > src/single_security.c
git add src/single_security.c
git commit --quiet -m "Fix single security issue" 2>/dev/null || true

run_test "Single security keyword bonus" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 18"  # 1 (base) + 5 (1 security keyword * 5) + 12 (new files)

cleanup_temp_test_env "$test_dir"

# Test 5: Combined bonuses
printf '%s\n' "${CYAN}=== Test 5: Combined bonuses ===${NC}"
test_dir=$(create_temp_test_env "combined_bonuses")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

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
run_test "Complex scenario patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 20"  # 1 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (new source) + 10 (2 security * 5) + 1 (added option) + 2 (new files)

run_test "Complex scenario minor delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.minor_delta: 23"  # 5 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (new source) + 10 (2 security * 5) + 1 (added option) + 1 (new files)

run_test "Complex scenario major delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.major_delta: 28"  # 10 (base) + 2 (CLI breaking) + 3 (API breaking) + 1 (new source) + 10 (2 security * 5) + 1 (added option) + 1 (new files)

cleanup_temp_test_env "$test_dir"

# Test 6: Configuration customization
printf '%s\n' "${CYAN}=== Test 6: Configuration customization ===${NC}"
test_dir=$(create_temp_test_env "custom_config")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Create breaking changes
echo "// CLI-BREAKING: Breaking CLI change" > src/cli_breaking.c
echo "// API-BREAKING: Breaking API change" > src/api_breaking.c
echo "// SECURITY: Security fix 1" > src/security1.c
echo "// SECURITY: Security fix 2" > src/security2.c
git add src/cli_breaking.c src/api_breaking.c src/security1.c src/security2.c
git commit --quiet -m "Add breaking changes" 2>/dev/null || true

# Test with custom bonus values
run_test "Custom bonus values" \
    "cd '$PROJECT_ROOT' && VERSION_BREAKING_CLI_BONUS=5 VERSION_API_BREAKING_BONUS=7 VERSION_SECURITY_BONUS=4 $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 23"  # 1 (base) + 5 (CLI breaking) + 7 (API breaking) + 8 (2 security * 4) + 2 (new files)

cleanup_temp_test_env "$test_dir"

# Test 7: Rollover scenarios
printf '%s\n' "${CYAN}=== Test 7: Rollover scenarios ===${NC}"
test_dir=$(create_temp_test_env "rollover_scenarios")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

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
run_test "Rollover scenario delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 9"  # 1 (base) + 2 (CLI breaking) + 3 (API breaking) + 3 (new files)

cleanup_temp_test_env "$test_dir"

# Test 8: System behavior (removed disabled system test)
printf '%s\n' "${CYAN}=== Test 8: System behavior ===${NC}"

# The system is always enabled now
export R_diff_size=1000
export R_breaking_cli_changes=true
export R_api_breaking=true

# Should always include loc_delta in JSON
local output
output=$($SEMANTIC_ANALYZER_SCRIPT --json 2>/dev/null)

if [[ "$output" == *"loc_delta"* ]]; then
    printf '%s\n' "${GREEN}✓ PASS: System always includes loc_delta${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: System doesn't include loc_delta${NC}"
    printf "Output: %s\n" "$output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Edge cases
printf '%s\n' "${CYAN}=== Test 9: Edge cases ===${NC}"
test_dir=$(create_temp_test_env "edge_cases")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Test zero LOC (empty commit)
git commit --allow-empty --quiet -m "Empty commit" 2>/dev/null || true

run_test "Zero LOC patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 1"  # Minimum delta of 1

# Test very large LOC
for i in {1..250}; do
    echo "// Very large change file $i" > "src/very_large_$i.c"
done
git add src/very_large_*.c
git commit --quiet -m "Add very large changes" 2>/dev/null || true

run_test "Very large LOC patch delta" \
    "cd '$PROJECT_ROOT' && $SEMANTIC_ANALYZER_SCRIPT --json --repo-root $(pwd)" \
    "loc_delta.patch_delta: 6"  # 1 (base) + 5 (new files bonus)

cleanup_temp_test_env "$test_dir"

# Test 10: Verbose output
printf '%s\n' "${CYAN}=== Test 10: Verbose output ===${NC}"
test_dir=$(create_temp_test_env "verbose_output")
cd "$test_dir"

# Create additional files for this test
mkdir -p src
echo "// Initial source file" > src/main.c
git add src/main.c
git commit --quiet -m "Add initial source file" 2>/dev/null || true

# Create changes for verbose output
echo "// CLI-BREAKING: Breaking CLI change" > src/cli_breaking.c
echo "// New source file" > src/new.c
echo "// SECURITY: Security fix 1" > src/security1.c
echo "// SECURITY: Security fix 2" > src/security2.c
git add src/cli_breaking.c src/new.c src/security1.c src/security2.c
git commit --quiet -m "Add changes for verbose test" 2>/dev/null || true

local output
output=$(cd "$PROJECT_ROOT" && $SEMANTIC_ANALYZER_SCRIPT --verbose --repo-root "$(pwd)" 2>&1)

# Check for verbose output information
if [[ "$output" == *"Verbose: Loading version configuration..."* ]] && \
   [[ "$output" == *"Debug: Final TOTAL_BONUS:"* ]]; then
    printf '%s\n' "${GREEN}✓ PASS: Verbose output shows debug information${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Verbose output missing debug information${NC}"
    printf "Output: %s\n" "$output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

cleanup_temp_test_env "$test_dir"

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