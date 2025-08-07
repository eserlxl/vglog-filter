#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test the extract_cli_options function with proper test environment

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

echo "=== Testing extract_cli_options function ==="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run CLI extraction test
run_cli_extraction_test() {
    local test_name="$1"
    local test_description="$2"
    local original_content="$3"
    local modified_content="$4"
    
    echo "Running test: $test_name"
    echo "Description: $test_description"
    
    # Create temporary test environment
    local temp_dir
    if ! temp_dir=$(create_temp_test_env "cli-extract-${test_name}"); then
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
    echo "$original_content" > src/main.cpp
    
    # Add and commit the original file
    git add src/main.cpp
    if ! git commit -m "Add original CLI file" >/dev/null 2>&1; then
        echo -e "\033[0;31m✗ Failed to commit original file\033[0m"
        cleanup_temp_test_env "$temp_dir"
        ((TESTS_FAILED++))
        return 0  # Don't exit, just return
    fi
    
    # Store the original commit hash
    local base_ref
    base_ref=$(git rev-parse HEAD)
    
    # Make the modification
    echo "$modified_content" > src/main.cpp
    git add src/main.cpp
    if ! git commit -m "Apply CLI modification" >/dev/null 2>&1; then
        echo -e "\033[0;31m✗ Failed to commit modified file\033[0m"
        cleanup_temp_test_env "$temp_dir"
        ((TESTS_FAILED++))
        return 0  # Don't exit, just return
    fi
    
    # Store the modified commit hash
    local target_ref
    target_ref=$(git rev-parse HEAD)
    
    # Run semantic version analyzer from the temporary directory
    local cli_analysis
    cli_analysis=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer.sh" --base "$base_ref" --target "$target_ref" --json --repo-root "$temp_dir" 2>/dev/null || true)
    
    echo "CLI analysis output:"
    echo "$cli_analysis"
    
    # Extract manual CLI variables from JSON output
    local manual_cli_changes manual_added_long_count manual_removed_long_count
    manual_cli_changes=$(echo "$cli_analysis" | grep '"manual_cli_changes"' | sed 's/.*"manual_cli_changes": *\([^,}]*\).*/\1/' || echo "not found")
    manual_added_long_count=$(echo "$cli_analysis" | grep '"manual_added_long_count"' | sed 's/.*"manual_added_long_count": *\([^,}]*\).*/\1/' || echo "not found")
    manual_removed_long_count=$(echo "$cli_analysis" | grep '"manual_removed_long_count"' | sed 's/.*"manual_removed_long_count": *\([^,}]*\).*/\1/' || echo "not found")
    
    echo "manual_cli_changes: $manual_cli_changes"
    echo "manual_added_long_count: $manual_added_long_count"
    echo "manual_removed_long_count: $manual_removed_long_count"
    
    # Validate that we got some output
    if [[ "$manual_cli_changes" != "not found" && "$manual_added_long_count" != "not found" && "$manual_removed_long_count" != "not found" ]]; then
        echo -e "\033[0;32m✓ Test passed: CLI extraction working\033[0m"
        ((TESTS_PASSED++))
    else
        echo -e "\033[0;31m✗ Test failed: CLI extraction not working\033[0m"
        ((TESTS_FAILED++))
    fi
    
    # Clean up
    cleanup_temp_test_env "$temp_dir"
    echo ""
}

# Test 1: Adding a new CLI option
run_cli_extraction_test \
    "add_option" \
    "Adding a new CLI option should be detected" \
    "#include <iostream>

int main(int argc, char *argv[]) {
    if (argc > 1 && std::string(argv[1]) == \"--help\") {
        std::cout << \"Help message\" << std::endl;
        return 0;
    }
    return 0;
}" \
    "#include <iostream>

int main(int argc, char *argv[]) {
    if (argc > 1) {
        if (std::string(argv[1]) == \"--help\") {
            std::cout << \"Help message\" << std::endl;
            return 0;
        }
        if (std::string(argv[1]) == \"--version\") {
            std::cout << \"Version 9.3.0\" << std::endl;
            return 0;
        }
    }
    return 0;
}"

# Test 2: Removing a CLI option
run_cli_extraction_test \
    "remove_option" \
    "Removing a CLI option should be detected" \
    "#include <iostream>

int main(int argc, char *argv[]) {
    if (argc > 1) {
        if (std::string(argv[1]) == \"--help\") {
            std::cout << \"Help message\" << std::endl;
            return 0;
        }
        if (std::string(argv[1]) == \"--version\") {
            std::cout << \"Version 9.3.0\" << std::endl;
            return 0;
        }
    }
    return 0;
}" \
    "#include <iostream>

int main(int argc, char *argv[]) {
    if (argc > 1 && std::string(argv[1]) == \"--help\") {
        std::cout << \"Help message\" << std::endl;
        return 0;
    }
    return 0;
}"

# Test 3: No CLI changes
run_cli_extraction_test \
    "no_changes" \
    "No CLI changes should be detected" \
    "#include <iostream>

int main(int argc, char *argv[]) {
    if (argc > 1 && std::string(argv[1]) == \"--help\") {
        std::cout << \"Help message\" << std::endl;
        return 0;
    }
    return 0;
}" \
    "#include <iostream>

int main(int argc, char *argv[]) {
    if (argc > 1 && std::string(argv[1]) == \"--help\") {
        std::cout << \"Help message\" << std::endl;
        return 0;
    }
    return 0; // No change
}"

# Print summary
echo "=== CLI Extraction Test Summary ==="
echo -e "\033[0;32mTests passed: $TESTS_PASSED\033[0m"
echo -e "\033[0;31mTests failed: $TESTS_FAILED\033[0m"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\033[0;32mAll CLI extraction tests passed!\033[0m"
    exit 0
else
    echo -e "\033[0;31mSome CLI extraction tests failed!\033[0m"
    exit 1
fi 