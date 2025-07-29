#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for semantic-version-analyzer
# Tests all improvements and edge cases
# shellcheck disable=SC2317 # eval is used for dynamic command execution

set -Euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Script path
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../dev-bin/semantic-version-analyzer"

# Helper functions
log_info() {
    printf '%s[INFO]%s %s\n' "${BLUE}" "${NC}" "$1"
}

log_success() {
    printf '%s[PASS]%s %s\n' "${GREEN}" "${NC}" "$1"
    ((TESTS_PASSED++))
}

log_error() {
    printf '%s[FAIL]%s %s\n' "${RED}" "${NC}" "$1"
    ((TESTS_FAILED++))
}

log_warning() {
    printf '%s[WARN]%s %s\n' "${YELLOW}" "${NC}" "$1"
}

# Test function
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
        printf 'Expected: %s\n' "$expected_output"
        printf 'Got: %s\n' "$output"
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
    
    if [[ "$output" == *"Semantic Version Analyzer v3 for vglog-filter"* ]]; then
        log_success "Help output"
    else
        log_error "Help output"
        printf 'Expected: Semantic Version Analyzer v3 for vglog-filter\n'
        printf 'Got: %s\n' "$output"
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
        printf 'Expected: SUGGESTION=\n'
        printf 'Got: %s\n' "$output"
    fi
}

# Test path classification
test_path_classification() {
    log_info "Testing path classification..."
    
    # Create a temporary test repository
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
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
    
    # Test that source files are classified correctly
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *"New source files: 1"* ]]; then
        log_success "Source file classification"
    else
        log_error "Source file classification"
    fi
    
    if [[ "$output" == *"New test files: 1"* ]]; then
        log_success "Test file classification"
    else
        log_error "Test file classification"
    fi
    
    if [[ "$output" == *"New doc files: 1"* ]]; then
        log_success "Doc file classification"
    else
        log_error "Doc file classification"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test file paths with spaces and special characters
test_file_paths_with_spaces() {
    log_info "Testing file paths with spaces and special characters..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
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
    
    if [[ "$output" == *"New source files: 1"* ]]; then
        log_success "File paths with spaces"
    else
        log_error "File paths with spaces"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test rename and copy handling
test_rename_and_copy() {
    log_info "Testing rename and copy handling..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
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
    
    if [[ "$output" == *"Modified files: 1"* ]]; then
        log_success "File rename handling"
    else
        log_error "File rename handling"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test CLI change detection
test_cli_change_detection() {
    log_info "Testing CLI change detection..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
    # Create initial source file
    mkdir -p src
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
    
    if [[ "$output" == *"CLI interface changes: true"* ]]; then
        log_success "CLI change detection"
    else
        log_error "CLI change detection"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test breaking CLI changes
test_breaking_cli_changes() {
    log_info "Testing breaking CLI changes..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
    # Create initial source file with CLI options
    mkdir -p src
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
    
    if [[ "$output" == *"Breaking CLI changes: true"* ]]; then
        log_success "Breaking CLI change detection"
    else
        log_error "Breaking CLI change detection"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test no changes scenario
test_no_changes() {
    log_info "Testing no changes scenario..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
    # Create a file and commit it
    echo "test" > test.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Test with no changes
    local output
    output=$("$SCRIPT_PATH" --verbose 2>&1)
    
    if [[ "$output" == *"SUGGESTION=none"* ]]; then
        log_success "No changes scenario"
    else
        log_error "No changes scenario"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test threshold configuration
test_threshold_configuration() {
    log_info "Testing threshold configuration..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
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
    
    # Create files to trigger different thresholds
    for i in {1..5}; do
        echo "source code $i" > "src/file$i.cpp"
        echo "test code $i" > "test/test$i.cpp"
        echo "doc content $i" > "doc/doc$i.md"
    done
    
    # Add and commit new files
    git add . >/dev/null 2>&1
    git commit -m "Add multiple files" >/dev/null 2>&1
    
    # Test with default thresholds
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    
    if [[ "$output" == *"New source files: 5"* ]]; then
        log_success "Threshold configuration"
    else
        log_error "Threshold configuration"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
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
    
    if [[ "$output" == *"Not in a git repository"* ]] || [[ "$output" == *"git command not found"* ]] || [[ "$output" == *"fatal"* ]]; then
        log_success "Git repository check"
    else
        log_error "Git repository check"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    rm -rf "$test_dir"
}

# Test JSON output
test_json_output() {
    log_info "Testing JSON output..."
    
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || exit 1
    
    # Initialize git repository
    git init >/dev/null 2>&1
    echo "0.0.0" > VERSION
    
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
    rm -rf "$test_dir"
}

# Main test runner
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
    test_threshold_configuration
    test_error_handling
    test_json_output
    
    # Print summary
    printf '\n%s=== Test Summary ===%s\n' "${BLUE}" "${NC}"
    printf 'Tests passed: %s%d%s\n' "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf 'Tests failed: %s%d%s\n' "${RED}" "$TESTS_FAILED" "${NC}"
    printf 'Total tests: %d\n' $((TESTS_PASSED + TESTS_FAILED))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf '\n%sAll tests passed!%s\n' "${GREEN}" "${NC}"
        exit 0
    else
        printf '\n%sSome tests failed!%s\n' "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 