#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test whitespace ignore functionality in semantic-version-analyzer
# This test verifies that whitespace-only changes don't trigger major version bumps

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "=== Testing Whitespace Ignore ==="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a whitespace test
run_whitespace_test() {
    local test_name="$1"
    local test_description="$2"
    local original_content="$3"
    local modified_content="$4"
    local expected_behavior="$5"
    
    echo "Running test: $test_name"
    echo "Description: $test_description"
    
    # Create temporary test environment
    local temp_dir
    if ! temp_dir=$(create_temp_test_env "whitespace-${test_name}"); then
        echo -e "\033[0;31m✗ Failed to create test environment\033[0m"
        ((TESTS_FAILED++))
        return 0  # Don't exit, just return
    fi
    
    # Change to temporary directory
    if ! cd "$temp_dir"; then
        echo -e "\033[0;31m✗ Failed to change to test directory\033[0m"
        cleanup_temp_test_env "$temp_dir"
        ((TESTS_FAILED++))
        return 0  # Don't exit, just return
    fi
    
    # Create test source file
    mkdir -p src
    echo "$original_content" > src/test_file.cpp
    
    # Add and commit the original file
    git add src/test_file.cpp
    if ! git commit -m "Add original test file" >/dev/null 2>&1; then
        echo -e "\033[0;31m✗ Failed to commit original file\033[0m"
        cleanup_temp_test_env "$temp_dir"
        ((TESTS_FAILED++))
        return 0  # Don't exit, just return
    fi
    
    # Store the original commit hash
    local base_ref
    base_ref=$(git rev-parse HEAD)
    
    # Make the modification
    echo "$modified_content" > src/test_file.cpp
    git add src/test_file.cpp
    if ! git commit -m "Apply modification" >/dev/null 2>&1; then
        echo -e "\033[0;31m✗ Failed to commit modified file\033[0m"
        cleanup_temp_test_env "$temp_dir"
        ((TESTS_FAILED++))
        return 0  # Don't exit, just return
    fi
    
    # Store the modified commit hash
    local target_ref
    target_ref=$(git rev-parse HEAD)
    
    # Run semantic version analyzer without --ignore-whitespace
    local result1
    result1=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --machine --repo-root "$temp_dir" --base "$base_ref" --target "$target_ref" 2>/dev/null || true)
    
    # Run semantic version analyzer with --ignore-whitespace
    local result2
    result2=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --ignore-whitespace --machine --repo-root "$temp_dir" --base "$base_ref" --target "$target_ref" 2>/dev/null || true)
    
    # Extract suggestions
    local suggestion1 suggestion2
    suggestion1=$(echo "$result1" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")
    suggestion2=$(echo "$result2" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")
    
    echo "Without --ignore-whitespace: $suggestion1"
    echo "With --ignore-whitespace: $suggestion2"
    
    # Verify the expected behavior
    local test_passed=false
    case "$expected_behavior" in
        "same")
            if [[ "$suggestion1" = "$suggestion2" ]]; then
                test_passed=true
            fi
            ;;
        "different")
            if [[ "$suggestion1" != "$suggestion2" ]]; then
                test_passed=true
            fi
            ;;
        "whitespace_ignored")
            # For now, just check that we get some output
            if [[ "$suggestion1" != "unknown" && "$suggestion2" != "unknown" ]]; then
                test_passed=true
            fi
            ;;
    esac
    
    if [[ "$test_passed" = true ]]; then
        echo -e "\033[0;32m✓ Test passed: $test_name\033[0m"
        ((TESTS_PASSED++))
    else
        echo -e "\033[0;31m✗ Test failed: $test_name\033[0m"
        echo "Expected behavior: $expected_behavior"
        ((TESTS_FAILED++))
    fi
    
    # Clean up
    cleanup_temp_test_env "$temp_dir"
    echo ""
}

# Test 1: Simple indentation change
run_whitespace_test \
    "simple_indent" \
    "Simple indentation change should be ignored" \
    "int main() {
    std::cout << \"Hello, World!\" << std::endl;
    return 0;
}" \
    "int main() {
        std::cout << \"Hello, World!\" << std::endl;
        return 0;
}" \
    "different"

# Test 2: Mixed whitespace and content changes
run_whitespace_test \
    "mixed_changes" \
    "Mixed whitespace and content changes should not be ignored" \
    "int main() {
    std::cout << \"Hello, World!\" << std::endl;
    return 0;
}" \
    "int main() {
        std::cout << \"Hello, Updated World!\" << std::endl;
        return 0;
}" \
    "same"

# Test 3: Only trailing whitespace
run_whitespace_test \
    "trailing_whitespace" \
    "Trailing whitespace changes should be ignored" \
    "int main() {
    return 0;
}" \
    "int main() {
    return 0;  
}" \
    "different"

# Test 4: No whitespace changes
run_whitespace_test \
    "no_whitespace_changes" \
    "No whitespace changes should produce same result" \
    "int main() {
    return 0;
}" \
    "int main() {
    return 0; // No change
}" \
    "same"

# Test 5: Complex whitespace changes
run_whitespace_test \
    "complex_whitespace" \
    "Complex whitespace changes should be ignored" \
    "int main() {
    std::cout << \"Hello\" << std::endl;
    std::cout << \"World\" << std::endl;
    return 0;
}" \
    "int main() {
        std::cout << \"Hello\" << std::endl;
        std::cout << \"World\" << std::endl;
        return 0;
}" \
    "different"

# Print summary
echo "=== Whitespace Ignore Test Summary ==="
echo -e "\033[0;32mTests passed: $TESTS_PASSED\033[0m"
echo -e "\033[0;31mTests failed: $TESTS_FAILED\033[0m"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\033[0;32mAll whitespace ignore tests passed!\033[0m"
    exit 0
else
    echo -e "\033[0;31mSome whitespace ignore tests failed!\033[0m"
    exit 1
fi 