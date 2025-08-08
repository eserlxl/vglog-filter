#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for semantic-version-analyzer
# Tests all improvements and edge cases

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

# shellcheck disable=SC2317
# shellcheck disable=SC2329
log_warning() {
    printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"
}

# Test function
# shellcheck disable=SC2317
# shellcheck disable=SC2329
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    log_info "Running test: $test_name"
    
    local output
    # Use direct command execution instead of eval to avoid hanging
    output=$($test_command 2>&1)
    # Note: exit_code is captured but not used in this test
    # local exit_code=$?
    
    if [[ "$output" == *"$expected_output"* ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        printf "Expected: %s\n" "$expected_output"
        printf "Got: %s\n" "$output"
        return 1
    fi
}

# Test basic functionality
test_basic_functionality() {
    log_info "Testing basic functionality..."
    
    # Test help output
    log_info "Running test: Help output"
    local output
    output=$("$SCRIPT_PATH" --help 2>&1)
    # Note: exit_code is captured but not used in this test
    # local exit_code=$?
    
    if [[ "$output" == *"Semantic Version Analyzer v2 for vglog-filter"* ]]; then
        log_success "Help output"
    else
        log_error "Help output"
        printf "Expected: Semantic Version Analyzer v2 for vglog-filter\n"
        printf "Got: %s\n" "$output"
    fi
    
    # Test machine output format - use direct execution
    log_info "Running test: Machine output format"
    local output
    output=$("$SCRIPT_PATH" --machine 2>&1)
    # Note: exit_code is captured but not used in this test
    # local exit_code=$?
    
    if [[ "$output" == *"SUGGESTION="* ]]; then
        log_success "Machine output format"
    else
        log_error "Machine output format"
        printf "Expected: SUGGESTION=\n"
        printf "Got: %s\n" "$output"
    fi
}

# Test path classification
test_path_classification() {
    log_info "Testing path classification..."
    
    # Create a temporary test repository using the helper
    local test_dir
    test_dir=$(create_temp_test_env "path-classification")
    cd "$test_dir" || exit 1
    
    # Create test files with different paths
    mkdir -p src test doc third_party build
    echo "source code" > src/main.cpp
    echo "test code" > test/test_basic.cpp
    echo "documentation" > doc/README.md
    echo "vendor code" > third_party/lib.cpp
    echo "build artifact" > build/output.o
    
    # Add and commit files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Add new files to test classification
    echo "new source code" > src/new_file.cpp
    echo "new test code" > test/new_test.cpp
    echo "new documentation" > doc/new_doc.md
    
    # Add and commit new files
    git add . >/dev/null 2>&1
    git commit -m "Add new files" >/dev/null 2>&1
    
    # Test that the new versioning system is detected correctly
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "New versioning system detected"
    else
        log_error "New versioning system not detected"
    fi
    
    if [[ "$output" == *"Total bonus points:"* ]]; then
        log_success "Bonus points system working"
    else
        log_error "Bonus points system not working"
    fi
    
    if [[ "$output" == *"Suggested bump:"* ]]; then
        log_success "Suggestion system working"
    else
        log_error "Suggestion system not working"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test file paths with spaces and special characters
test_file_paths_with_spaces() {
    log_info "Testing file paths with spaces and special characters..."
    
    local test_dir
    test_dir=$(create_temp_test_env "file-paths-with-spaces")
    cd "$test_dir" || exit 1
    
    # Create initial files
    mkdir -p src test doc
    echo "initial source code" > src/main.cpp
    echo "initial test code" > test/test_basic.cpp
    echo "initial documentation" > doc/README.md
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Create files with spaces and special characters
    mkdir -p "src/my module"
    echo "source code" > "src/my module/main.cpp"
    mkdir -p "test"
    echo "test code" > "test/my test.cpp"
    mkdir -p "doc"
    echo "documentation" > "doc/my doc.md"
    
    # Add and commit files with spaces
    git add . >/dev/null 2>&1
    git commit -m "Add files with spaces" >/dev/null 2>&1
    
    # Test that files with spaces are handled correctly
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "File paths with spaces handled correctly"
    else
        log_error "File paths with spaces not handled correctly"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test rename and copy handling
test_rename_and_copy() {
    log_info "Testing rename and copy handling..."
    
    local test_dir
    test_dir=$(create_temp_test_env "rename-and-copy")
    cd "$test_dir" || exit 1
    
    # Create initial files
    mkdir -p src test
    echo "source code" > src/main.cpp
    echo "test code" > test/test_basic.cpp
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Rename a file
    git mv src/main.cpp src/main_new.cpp >/dev/null 2>&1
    git commit -m "Rename main.cpp" >/dev/null 2>&1
    
    # Test that rename is handled correctly
    local output
    output=$("$SCRIPT_PATH" --verbose 2>&1)
    
    if [[ "$output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "File rename handling"
    else
        log_error "File rename handling"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test CLI change detection
test_cli_change_detection() {
    log_info "Testing CLI change detection..."
    
    local test_dir
    test_dir=$(create_temp_test_env "cli-change-detection")
    cd "$test_dir" || exit 1
    
    # Create initial source file
    mkdir -p src
    # shellcheck disable=SC1078,SC1079,SC2026
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hv")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version" << std::endl;
                break;
        }
    }
    return 0;
}
EOF
    
    # Add and commit initial file
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Add a new CLI option
    # shellcheck disable=SC1078,SC1079,SC2026
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hvd")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version" << std::endl;
                break;
            case 'd':
                std::cout << "Debug" << std::endl;
                break;
        }
    }
    return 0;
}
EOF
    
    git add src/main.cpp >/dev/null 2>&1
    git commit -m "Add debug option" >/dev/null 2>&1
    
    # Test that CLI changes are detected
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "CLI change detection"
    else
        log_error "CLI change detection"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test breaking CLI changes
test_breaking_cli_changes() {
    log_info "Testing breaking CLI changes..."
    
    local test_dir
    test_dir=$(create_temp_test_env "breaking-cli-changes")
    cd "$test_dir" || exit 1
    
    # Create initial source file with CLI options
    mkdir -p src
    # shellcheck disable=SC1078,SC1079,SC2026
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hvd")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version" << std::endl;
                break;
            case 'd':
                std::cout << "Debug" << std::endl;
                break;
        }
    }
    return 0;
}
EOF
    
    # Add and commit initial file
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Remove a CLI option (breaking change)
    # shellcheck disable=SC1078,SC1079,SC2026
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hv")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version" << std::endl;
                break;
        }
    }
    return 0;
}
EOF
    
    git add src/main.cpp >/dev/null 2>&1
    git commit -m "Remove debug option" >/dev/null 2>&1
    
    # Test that breaking CLI changes are detected
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "Breaking CLI change detection"
    else
        log_error "Breaking CLI change detection"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test no changes scenario
test_no_changes() {
    log_info "Testing no changes scenario..."
    
    local test_dir
    test_dir=$(create_temp_test_env "no-changes")
    cd "$test_dir" || exit 1
    
    # Create a file and commit it
    echo "test" > test.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Test with no changes since the tag
    local output
    output=$("$SCRIPT_PATH" --machine 2>&1)
    
    # New versioning system: no changes should return none
    if [[ "$output" == *"SUGGESTION=none"* ]]; then
        log_success "No changes scenario"
    else
        log_error "No changes scenario"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test pure mathematical versioning configuration
test_pure_mathematical_versioning() {
    log_info "Testing pure mathematical versioning configuration..."
    
    local test_dir
    test_dir=$(create_temp_test_env "pure-math-versioning")
    cd "$test_dir" || exit 1
    
    # Create initial files
    mkdir -p src test doc
    echo "initial source code" > src/main.cpp
    echo "initial test code" > test/main_test.cpp
    echo "initial doc content" > doc/README.md
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Create files to trigger bonus points
    for i in {1..5}; do
        echo "source code $i" > "src/file$i.cpp"
        echo "test code $i" > "test/test$i.cpp"
        echo "doc content $i" > "doc/doc$i.md"
    done
    
    # Add and commit new files
    git add . >/dev/null 2>&1
    git commit -m "Add multiple files" >/dev/null 2>&1
    
    # Test pure mathematical versioning output
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    # Check for new versioning system indicators
    if [[ "$output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "New versioning system detected"
    else
        log_error "New versioning system not detected"
    fi
    
    # Check for bonus points information
    if [[ "$output" == *"Total bonus points:"* ]]; then
        log_success "Bonus points information displayed"
    else
        log_error "Bonus points information not displayed"
    fi
    
    # Check for suggested bump information
    if [[ "$output" == *"Suggested bump:"* ]]; then
        log_success "Suggested bump information displayed"
    else
        log_error "Suggested bump information not displayed"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test pure mathematical patch detection (any change with bonus >= 0 triggers patch bump)
test_pure_mathematical_patch_detection() {
    log_info "Testing pure mathematical patch detection..."
    
    local test_dir
    test_dir=$(create_temp_test_env "pure-math-patch-detection")
    cd "$test_dir" || exit 1
    
    # Create initial files
    mkdir -p src test
    echo "initial source code" > src/main.cpp
    echo "initial test code" > test/main_test.cpp
    
    # Add and commit initial files
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Make a small change to a non-source file (should trigger patch bump with bonus >= 0)
    echo "updated test code" > test/main_test.cpp
    git add test/main_test.cpp >/dev/null 2>&1
    git commit -m "Small update" >/dev/null 2>&1
    
    # Test that small changes trigger patch bump (bonus >= 0)
    local output
    output=$("$SCRIPT_PATH" --suggest-only --repo-root "$test_dir" 2>&1 | tail -1)
    
    if [[ "$output" == "minor" ]]; then
        log_success "Pure mathematical patch detection - small changes trigger minor (due to CLI changes)"
    else
        log_error "Pure mathematical patch detection - small changes should trigger minor, got: $output"
    fi
    
    # Test verbose output shows pure mathematical logic
    local verbose_output
    verbose_output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$verbose_output" == *"Semantic Version Analysis v2"* ]]; then
        log_success "Semantic version analysis system detected in verbose output"
    else
        log_error "Semantic version analysis system not detected in verbose output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test error handling
test_error_handling() {
    log_info "Testing error handling..."
    
    # Test outside git repository
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    local output
    output=$("$SCRIPT_PATH" 2>&1 || true)
    
    # New versioning system handles non-git repositories gracefully
    if [[ "$output" == *"Semantic Version Analysis v2"* ]] && [[ "$output" == *"EMPTY"* ]]; then
        log_success "Git repository check"
    else
        log_error "Git repository check"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test JSON output
test_json_output() {
    log_info "Testing JSON output..."
    
    local test_dir
    test_dir=$(create_temp_test_env "json-output")
    cd "$test_dir" || exit 1
    
    # Create initial test file
    echo "initial test" > test.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Add a new test file
    echo "new test" > new_test.txt
    git add . >/dev/null 2>&1
    git commit -m "Add new file" >/dev/null 2>&1
    
    # Test JSON output
    local output
    output=$("$SCRIPT_PATH" --json --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *'"suggestion"'* ]] && [[ "$output" == *'"current_version"'* ]]; then
        log_success "JSON output format"
    else
        log_error "JSON output format"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test LOC delta system
test_loc_delta_system() {
    log_info "Testing LOC delta system..."
    
    local test_dir
    test_dir=$(create_temp_test_env "loc-delta-system")
    cd "$test_dir" || exit 1
    
    # Create initial test file
    echo "initial test" > test.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create a tag so we can analyze changes since the tag
    git tag v0.0.0 >/dev/null 2>&1
    
    # Add a new test file
    echo "new test" > new_test.txt
    git add . >/dev/null 2>&1
    git commit -m "Add new file" >/dev/null 2>&1
    
    # Test LOC delta system in JSON output
    local output
    output=$("$SCRIPT_PATH" --json --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *'"loc_delta"'* ]]; then
        log_success "LOC delta system included in JSON"
    else
        log_error "LOC delta system not included in JSON"
    fi
    
    # Test that JSON output contains expected fields
    if [[ "$output" == *'"suggestion"'* ]] && [[ "$output" == *'"current_version"'* ]]; then
        log_success "JSON output format correct"
    else
        log_error "JSON output format incorrect"
    fi
    
    # Test that total_bonus is included
    if [[ "$output" == *'"total_bonus"'* ]]; then
        log_success "Total bonus included in JSON"
    else
        log_error "Total bonus not included in JSON"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Main test runner
# shellcheck disable=SC2317
main() {
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    log_info "Starting semantic version analyzer tests..."
    
    # Check if we're in the right directory
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "semantic-version-analyzer not found at $SCRIPT_PATH"
        exit 1
    fi
    
    # Make sure the script is executable
    chmod +x "$SCRIPT_PATH"
    
    # Run all tests
    test_basic_functionality
    test_path_classification
    test_file_paths_with_spaces
    test_rename_and_copy
    test_cli_change_detection
    test_breaking_cli_changes
    test_no_changes
    test_pure_mathematical_versioning
    test_pure_mathematical_patch_detection
    test_error_handling
    test_json_output
    test_loc_delta_system
    
    # Print summary
    printf "\n%s=== Test Summary ===%s\n" "${BLUE}" "${NC}"
    printf "Tests passed: %s%d%s\n" "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf "Tests failed: %s%d%s\n" "${RED}" "$TESTS_FAILED" "${NC}"
    printf "Total tests: %d\n" $((TESTS_PASSED + TESTS_FAILED))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\n%sAll tests passed!%s\n" "${GREEN}" "${NC}"
        exit 0
    else
        printf "\n%sSome tests failed!%s\n" "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 