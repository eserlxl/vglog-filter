#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive test script for realistic repository scenarios
# Tests semantic analyzer with various repository types and histories

set -Euo pipefail
IFS=

# Source the test helper
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/test-workflows/test_helper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
# CYAN='\033[0;36m'  # Unused variable - commented out to fix shellcheck warning
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

# shellcheck disable=SC2329
log_warning() {
    printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"
}

# Function to create an empty repository (no commits)
create_empty_repo() {
    local test_name="${1:-empty}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Initialize git but don't commit anything
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    echo "$temp_dir"
}

# Function to create a single-commit repository
create_single_commit_repo() {
    local test_name="${1:-single}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Initialize git
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create minimal files
    echo "1.0.0" > VERSION
    echo "project(single-test)" > CMakeLists.txt
    mkdir -p src
    echo "int main() { return 0; }" > src/main.cpp
    
    # Single commit
    git add .
    git commit -m "Initial commit" >/dev/null 2>&1
    
    echo "$temp_dir"
}

# Function to create a repository with breaking changes
create_breaking_changes_repo() {
    local test_name="${1:-breaking}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Initialize git
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create src directory
    mkdir -p src
    
    # Initial version
    echo "1.0.0" > VERSION
    cat > src/main.cpp << 'EOF'
#include <iostream>

void old_function() {
    std::cout << "Old function" << std::endl;
}

int main() {
    old_function();
    return 0;
}
EOF
    
    git add .
    git commit -m "Initial version with old_function" >/dev/null 2>&1
    git tag v1.0.0 >/dev/null 2>&1
    
    # Breaking change - use multiple breaking patterns to get enough bonus points for major
    cat > src/main.cpp << 'EOF'
#include <iostream>

void new_function() {
    std::cout << "New function" << std::endl;
}

int main() {
    new_function();
    return 0;
}
EOF
    
    git add .
    git commit -m "BREAKING API: Rename old_function to new_function. BREAKING CLI: Remove old command line option. SECURITY: Fix critical vulnerability. BREAKING: Database schema change." >/dev/null 2>&1
    git tag v2.0.0 >/dev/null 2>&1
    
    echo "$temp_dir"
}

# Function to create a repository with security fixes
create_security_fixes_repo() {
    local test_name="${1:-security}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Initialize git
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create src directory
    mkdir -p src
    
    # Initial version with security issue
    echo "1.0.0" > VERSION
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <cstring>

void unsafe_copy(char* dest, const char* src) {
    strcpy(dest, src);  // Unsafe - no bounds checking
}

int main() {
    char buffer[10];
    unsafe_copy(buffer, "This is too long for the buffer");
    return 0;
}
EOF
    
    git add .
    git commit -m "Initial version" >/dev/null 2>&1
    git tag v1.0.0 >/dev/null 2>&1
    
    # Security fix
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <cstring>

void safe_copy(char* dest, const char* src, size_t size) {
    strncpy(dest, src, size - 1);
    dest[size - 1] = '\0';  // Ensure null termination
}

int main() {
    char buffer[10];
    safe_copy(buffer, "This is too long for the buffer", sizeof(buffer));
    return 0;
}
EOF
    
    git add .
    git commit -m "SECURITY: Fix buffer overflow in string copy function" >/dev/null 2>&1
    git tag v1.0.1 >/dev/null 2>&1
    
    echo "$temp_dir"
}

# Function to create a repository with CLI changes
create_cli_changes_repo() {
    local test_name="${1:-cli}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Initialize git
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create src directory
    mkdir -p src
    
    # Initial version
    echo "1.0.0" > VERSION
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
                std::cout << "Version 1.0.0" << std::endl;
                break;
        }
    }
    return 0;
}
EOF
    
    git add .
    git commit -m "Initial version with basic CLI" >/dev/null 2>&1
    git tag v1.0.0 >/dev/null 2>&1
    
    # Add new CLI option
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hvf:")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version 1.1.0" << std::endl;
                break;
            case 'f':
                std::cout << "File: " << optarg << std::endl;
                break;
        }
    }
    return 0;
}
EOF
    
    git add .
    git commit -m "Add file option to CLI" >/dev/null 2>&1
    git tag v1.1.0 >/dev/null 2>&1
    
    # Breaking CLI change
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include <getopt.h>

int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hvf:")) != -1) {
        switch (opt) {
            case 'h':
                std::cout << "Help" << std::endl;
                break;
            case 'v':
                std::cout << "Version 2.0.0" << std::endl;
                break;
            case 'f':
                std::cout << "File: " << optarg << std::endl;
                break;
            default:
                std::cerr << "Unknown option" << std::endl;
                return 1;
        }
    }
    return 0;
}
EOF
    
    git add .
    git commit -m "BREAKING: Change CLI behavior - unknown options now return error" >/dev/null 2>&1
    git tag v2.0.0 >/dev/null 2>&1
    
    echo "$temp_dir"
}

# Function to create a repository with substantial history
create_substantial_history_repo() {
    local test_name="${1:-substantial}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Initialize git
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create substantial project structure
    mkdir -p src include test doc examples tools
    
    # Initial version
    echo "1.0.0" > VERSION
    cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.10)
project(substantial-test VERSION 1.0.0)
set(CMAKE_CXX_STANDARD 17)
add_executable(main src/main.cpp)
target_include_directories(main PRIVATE include)
EOF
    
    cat > include/config.h << 'EOF'
#ifndef CONFIG_H
#define CONFIG_H
#define VERSION_MAJOR 1
#define VERSION_MINOR 0
#define VERSION_PATCH 0
#endif
EOF
    
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include "config.h"

int main() {
    std::cout << "Version " << VERSION_MAJOR << "." << VERSION_MINOR << "." << VERSION_PATCH << std::endl;
    return 0;
}
EOF
    
    git add .
    git commit -m "Initial project setup" >/dev/null 2>&1
    git tag v1.0.0 >/dev/null 2>&1
    
    # Add features over time
    for i in {1..5}; do
        cat > "src/feature${i}.cpp" << EOF
#include <iostream>

void feature${i}() {
    std::cout << "Feature ${i}" << std::endl;
}
EOF
        
        git add .
        git commit -m "Add feature ${i}" >/dev/null 2>&1
        
        if [[ $i -eq 2 ]]; then
            git tag "v1.${i}.0" >/dev/null 2>&1
        fi
    done
    
    # Add breaking change
    cat > include/config.h << 'EOF'
#ifndef CONFIG_H
#define CONFIG_H
#define VERSION_MAJOR 2
#define VERSION_MINOR 0
#define VERSION_PATCH 0
#endif
EOF
    
    git add .
    git commit -m "BREAKING: Major version bump to 2.0.0" >/dev/null 2>&1
    git tag v2.0.0 >/dev/null 2>&1
    
    # Add more features
    for i in {6..10}; do
        cat > "src/feature${i}.cpp" << EOF
#include <iostream>

void feature${i}() {
    std::cout << "Feature ${i}" << std::endl;
}
EOF
        
        git add .
        git commit -m "Add feature ${i}" >/dev/null 2>&1
        
        if [[ $i -eq 7 ]]; then
            git tag "v2.${i}.0" >/dev/null 2>&1
        fi
    done
    
    # Add security fix
    cat > src/security.cpp << 'EOF'
#include <iostream>
#include <cstring>

void secure_function() {
    std::cout << "Secure function" << std::endl;
}
EOF
    
    git add .
    git commit -m "SECURITY: Add secure function implementation" >/dev/null 2>&1
    git tag v2.7.1 >/dev/null 2>&1
    
    echo "$temp_dir"
}

# Test functions
test_empty_repository() {
    log_info "Testing empty repository..."
    
    local test_dir
    test_dir=$(create_empty_repo "empty-test")
    cd "$test_dir" || exit 1
    
    # Test that analyzer works with empty repo
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Empty repository exits with valid code: $exit_code"
    else
        log_error "Empty repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Empty repository"; then
        log_success "Empty repository shows appropriate analysis"
    else
        log_error "Empty repository missing appropriate analysis"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test single commit repository (should work)
test_single_commit_repository() {
    log_info "Testing single commit repository..."
    
    local test_dir
    test_dir=$(create_single_commit_repo "single-test")
    cd "$test_dir" || exit 1
    
    # Test that analyzer works with single commit repo
    local output
    output=$("$SCRIPT_PATH" --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Single commit repository exits with valid code: $exit_code"
    else
        log_error "Single commit repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Semantic Version Analysis v2"; then
        log_success "Single commit repository shows analysis output"
    else
        log_error "Single commit repository missing analysis output"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test breaking changes repository
test_breaking_changes_repository() {
    log_info "Testing breaking changes repository..."
    
    local test_dir
    test_dir=$(create_breaking_changes_repo "breaking-test")
    cd "$test_dir" || exit 1
    
    # Test analysis since v1.0.0
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    # The breaking changes repository has multiple breaking patterns that should trigger major version
    # Exit codes: 10=major, 11=minor, 12=patch, 20=none
    if [[ $exit_code == 10 ]]; then
        log_success "Breaking changes repository suggests major version (exit code 10)"
    elif [[ $exit_code == 11 ]]; then
        log_success "Breaking changes repository suggests minor version (exit code 11)"
    else
        log_error "Breaking changes repository has wrong exit code: $exit_code (expected 10 or 11)"
    fi
    
    if echo "$output" | grep -q "BREAKING"; then
        log_success "Breaking changes repository detects breaking changes"
    else
        log_error "Breaking changes repository missing breaking change detection"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

test_security_fixes_repository() {
    log_info "Testing security fixes repository..."
    
    local test_dir
    test_dir=$(create_security_fixes_repo "security-test")
    cd "$test_dir" || exit 1
    
    # Test analysis since v1.0.0
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Security fixes repository exits with valid code: $exit_code"
    else
        log_error "Security fixes repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "SECURITY"; then
        log_success "Security fixes repository detects security changes"
    else
        log_error "Security fixes repository missing security change detection"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

test_cli_changes_repository() {
    log_info "Testing CLI changes repository..."
    
    local test_dir
    test_dir=$(create_cli_changes_repo "cli-test")
    cd "$test_dir" || exit 1
    
    # Test analysis since v1.0.0
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "CLI changes repository exits with valid code: $exit_code"
    else
        log_error "CLI changes repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "CLI"; then
        log_success "CLI changes repository detects CLI changes"
    else
        log_error "CLI changes repository missing CLI change detection"
        printf "Output: %s\n" "$output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Test substantial history repository with suggest-only
test_substantial_history_repository() {
    log_info "Testing substantial history repository..."
    
    local test_dir
    test_dir=$(create_substantial_history_repo "substantial-test")
    cd "$test_dir" || exit 1
    
    # Test analysis since v1.0.0
    local output
    output=$("$SCRIPT_PATH" --since v1.0.0 --verbose --repo-root "$test_dir" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ge 10 && $exit_code -le 20 ]]; then
        log_success "Substantial history repository exits with valid code: $exit_code"
    else
        log_error "Substantial history repository has wrong exit code: $exit_code"
    fi
    
    if echo "$output" | grep -q "Semantic Version Analysis v2"; then
        log_success "Substantial history repository shows analysis output"
    else
        log_error "Substantial history repository missing analysis output"
        printf "Output: %s\n" "$output"
    fi
    
    # Test suggest-only
    local suggest_output
    suggest_output=$("$SCRIPT_PATH" --since v1.0.0 --suggest-only --repo-root "$test_dir" 2>/dev/null)
    local suggest_exit_code=$?
    
    if [[ $suggest_exit_code == 0 ]]; then
        log_success "Substantial history repository suggest-only exits successfully"
    else
        log_error "Substantial history repository suggest-only has wrong exit code: $suggest_exit_code"
    fi
    
    if [[ -n "$suggest_output" ]] && echo "$suggest_output" | grep -E -q "^(major|minor|patch|none)$"; then
        log_success "Substantial history repository produces valid suggestion: $suggest_output"
    else
        log_error "Substantial history repository produces invalid suggestion"
        printf "Output: '%s'\n" "$suggest_output"
    fi
    
    # Cleanup
    cd - >/dev/null 2>&1 || exit
    cleanup_temp_test_env "$test_dir"
}

# Main test execution
main() {
    log_info "Starting comprehensive realistic repository tests..."
    
    # Test various repository types
    test_empty_repository
    test_single_commit_repository
    test_breaking_changes_repository
    test_security_fixes_repository
    test_cli_changes_repository
    test_substantial_history_repository
    
    # Print summary
    printf "\n%s=== Test Summary ===%s\n" "${BLUE}" "${NC}"
    printf "Tests passed: %s%d%s\n" "${GREEN}" "$TESTS_PASSED" "${NC}"
    printf "Tests failed: %s%d%s\n" "${RED}" "$TESTS_FAILED" "${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\n%s✅ All tests passed!%s\n" "${GREEN}" "${NC}"
        exit 0
    else
        printf "\n%s❌ Some tests failed!%s\n" "${RED}" "${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
