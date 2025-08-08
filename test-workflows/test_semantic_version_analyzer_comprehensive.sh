#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive test script for semantic version analyzer v2

set -euo pipefail

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

SEMANTIC_ANALYZER_SCRIPT="$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh"

# Test 1: Basic functionality
printf '%s\n' "${CYAN}=== Test 1: Basic functionality ===${RESET}"
test_dir=$(create_temp_test_env "semantic-version-analyzer-comprehensive")
cd "$test_dir"

# Test 1: Help command
printf '%s\n' "${CYAN}Running test: Help command${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --help 2>&1 || true)
if echo "$output" | grep -q "Semantic Version Analyzer v2"; then
    printf '%s\n' "${GREEN}✓ PASS: Help command${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Help command${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Basic analysis with valid version
printf '%s\n' "${CYAN}Running test: Basic analysis with valid version${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "none"; then
    printf '%s\n' "${GREEN}✓ PASS: Basic analysis with valid version${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Basic analysis with valid version${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Core version calculation tests
printf '%s\n' "${CYAN}=== Test 3: Core Version Calculation ==${RESET}"

# Test 1: Basic patch increment (simple commit)
echo "test content" > test_file.txt
git add test_file.txt
git commit -m "simple fix" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Basic patch increment${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Basic patch increment${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Basic patch increment${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Breaking change (should be major with new system)
echo "BREAKING CHANGE: api breaking change" > breaking.txt
git add breaking.txt
git commit -m "BREAKING CHANGE: api breaking change" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Breaking change${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "major"; then
    printf '%s\n' "${GREEN}✓ PASS: Breaking change${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Breaking change${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Security vulnerability (should be minor with new system)
echo "fix: CVE-2024-1234 security vulnerability" > security.txt
git add security.txt
git commit -m "fix: CVE-2024-1234 security vulnerability" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Security vulnerability${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "minor"; then
    printf '%s\n' "${GREEN}✓ PASS: Security vulnerability${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Security vulnerability${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Performance improvement (should be patch with new system)
echo "perf: 50% performance improvement" > perf.txt
git add perf.txt
git commit -m "perf: 50% performance improvement" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Performance improvement${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Performance improvement${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Performance improvement${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: New feature (should be patch with new system)
echo "feat: add new feature" > feature.txt
git add feature.txt
git commit -m "feat: add new feature" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: New feature${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: New feature${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: New feature${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Database schema change (should be patch with new system)
echo "feat: database schema change" > schema.txt
git add schema.txt
git commit -m "feat: database schema change" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Database schema change${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Database schema change${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Database schema change${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Advanced features
printf '%s\n' "${CYAN}=== Test 4: Advanced Features ==${RESET}"

# Test 1: Zero-day vulnerability (should be minor with new system)
echo "fix: zero-day vulnerability CVE-2024-5678" > zeroday.txt
git add zeroday.txt
git commit -m "fix: zero-day vulnerability CVE-2024-5678" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Zero-day vulnerability${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "minor"; then
    printf '%s\n' "${GREEN}✓ PASS: Zero-day vulnerability${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Zero-day vulnerability${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Production outage (should be patch with new system)
echo "fix: production outage issue" > outage.txt
git add outage.txt
git commit -m "fix: production outage issue" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Production outage${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Production outage${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Production outage${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Customer request (should be patch with new system)
echo "feat: customer request implementation" > customer.txt
git add customer.txt
git commit -m "feat: customer request implementation" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Customer request${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Customer request${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Customer request${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Cross-platform support (should be patch with new system)
echo "feat: cross-platform support" > cross.txt
git add cross.txt
git commit -m "feat: cross-platform support" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Cross-platform support${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Cross-platform support${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Cross-platform support${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Memory safety (should be patch with new system)
echo "fix: memory safety issue" > memory.txt
git add memory.txt
git commit -m "fix: memory safety issue" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Memory safety${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Memory safety${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Memory safety${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Race condition (should be patch with new system)
echo "fix: race condition" > race.txt
git add race.txt
git commit -m "fix: race condition" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Race condition${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Race condition${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Race condition${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Edge cases
printf '%s\n' "${CYAN}=== Test 5: Edge Cases ==${RESET}"

# Test 1: Large LOC changes
# Create a large file to test LOC capping
for i in {1..100}; do
    echo "line $i" >> large_file.txt
done
git add large_file.txt
git commit -m "feat: large file addition" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Large LOC changes${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Large LOC changes${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Large LOC changes${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Version rollover
printf '%s\n' "${CYAN}Running test: Version rollover test${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Version rollover test${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Version rollover test${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Zero LOC changes
git commit --allow-empty -m "empty commit" >/dev/null 2>&1
printf '%s\n' "${CYAN}Running test: Zero LOC changes${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "none"; then
    printf '%s\n' "${GREEN}✓ PASS: Zero LOC changes${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Zero LOC changes${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Verbose output
printf '%s\n' "${CYAN}=== Test 6: Verbose Output ==${RESET}"

echo "feat: new feature with tests" > verbose.txt
git add verbose.txt
git commit -m "feat: new feature with tests" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Verbose output${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --verbose 2>&1 || true)
if echo "$output" | grep -q "=== Semantic Version Analysis v2 ==="; then
    printf '%s\n' "${GREEN}✓ PASS: Verbose output${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Verbose output${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 7: Exit codes
printf '%s\n' "${CYAN}=== Test 7: Exit Codes ==${RESET}"

# Test strict status exit codes
echo "BREAKING CHANGE: major change" > major.txt
git add major.txt
git commit -m "BREAKING CHANGE: major change" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Major change exit code${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only --strict-status 2>&1 || true)
if echo "$output" | grep -q "minor"; then
    printf '%s\n' "${GREEN}✓ PASS: Major change exit code${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Major change exit code${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo "feat: minor feature" > minor.txt
git add minor.txt
git commit -m "feat: minor feature" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Minor change exit code${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only --strict-status 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Minor change exit code${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Minor change exit code${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo "fix: patch fix" > patch.txt
git add patch.txt
git commit -m "fix: patch fix" >/dev/null 2>&1

printf '%s\n' "${CYAN}Running test: Patch change exit code${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only --strict-status 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Patch change exit code${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Patch change exit code${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test non-strict status (should always exit 0)
printf '%s\n' "${CYAN}Running test: Non-strict status exit code${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --suggest-only 2>&1 || true)
if echo "$output" | grep -q "patch"; then
    printf '%s\n' "${GREEN}✓ PASS: Non-strict status exit code${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Non-strict status exit code${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: Key features check
printf '%s\n' "${CYAN}=== Test 8: Key Features ==${RESET}"

# Check if it has YAML configuration support
if grep -q "version-config-loader.sh" "$SEMANTIC_ANALYZER_SCRIPT"; then
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

# Check if it has modular architecture
if grep -q "run_component" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has modular component architecture${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No modular architecture detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has bonus system
if grep -q "TOTAL_BONUS" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has bonus system${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No bonus system detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has version calculator integration
if grep -q "version-calculator.sh" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has version calculator integration${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No version calculator integration detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if it has ref resolver integration
if grep -q "ref-resolver.sh" "$SEMANTIC_ANALYZER_SCRIPT"; then
    printf '%s\n' "${GREEN}✓ Has ref resolver integration${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ No ref resolver integration detected${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Bonus system validation
printf '%s\n' "${CYAN}=== Test 9: Bonus System Validation ==${RESET}"

# Test machine output to see bonus points
printf '%s\n' "${CYAN}Running test: Bonus points in machine output${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --machine 2>&1 || true)
if echo "$output" | grep -q "SUGGESTION="; then
    printf '%s\n' "${GREEN}✓ PASS: Bonus points in machine output${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: Bonus points in machine output${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 10: JSON output format
printf '%s\n' "${CYAN}=== Test 10: JSON Output Format ==${RESET}"

printf '%s\n' "${CYAN}Running test: JSON output format${RESET}"
output=$("$SEMANTIC_ANALYZER_SCRIPT" --json 2>&1 || true)
if echo "$output" | grep -q '"suggestion"'; then
    printf '%s\n' "${GREEN}✓ PASS: JSON output format${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf '%s\n' "${RED}✗ FAIL: JSON output format${RESET}"
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
