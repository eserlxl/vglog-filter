#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test helper script for vglog-filter tests
# Provides utilities for creating temporary test environments

set -Euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter for tracking test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to log test results
log_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✓ $test_name: $message${NC}"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗ $test_name: $message${NC}"
            ((TESTS_FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ $test_name: $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ $test_name: $message${NC}"
            ;;
    esac
}

# Function to create a temporary test environment
create_temp_test_env() {
    local test_name="${1:-default}"
    local temp_dir="/tmp/vglog-filter-test-${test_name}-$$"
    
    # Validate test name
    if [[ -z "$test_name" ]]; then
        echo "Error: Test name cannot be empty" >&2
        return 1
    fi
    
    # Create temporary directory
    if ! mkdir -p "$temp_dir"; then
        echo "Error: Failed to create temporary directory $temp_dir" >&2
        return 1
    fi
    
    # Get the project root (use environment variable if available, otherwise calculate from script location)
    local project_root
    project_root="${PROJECT_ROOT:-$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")}"
    
    # Validate project root exists
    if [[ ! -d "$project_root" ]]; then
        echo "Error: Project root directory not found: $project_root" >&2
        return 1
    fi
    
    # Create a minimal project structure
    if ! cd "$temp_dir"; then
        echo "Error: Failed to change to temporary directory" >&2
        return 1
    fi
    
    # Copy essential project files
    cp "$project_root/VERSION" . 2>/dev/null || echo "1.0.0" > VERSION
    cp "$project_root/CMakeLists.txt" . 2>/dev/null || echo "project(test)" > CMakeLists.txt
    cp -r "$project_root/src" . 2>/dev/null || mkdir -p src
    
    # Note: dev-bin scripts are accessed from the original project directory
    # to avoid copying and ensure we're testing the actual scripts
    
    # Create test-workflows structure
    mkdir -p test-workflows/source-fixtures
    cp -r "$project_root/test-workflows/source-fixtures" test-workflows/ 2>/dev/null || true
    
    # Initialize git repository
    if ! git init --quiet; then
        echo "Error: Failed to initialize git repository" >&2
        return 1
    fi
    
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Add initial files
    git add . >/dev/null 2>&1 || true
    git commit -m "Initial commit" >/dev/null 2>&1 || true
    
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

# Function to run a test in a temporary environment
run_test_in_temp_env() {
    local test_name="$1"
    local test_script="$2"
    
    if [[ -z "$test_name" || -z "$test_script" ]]; then
        echo "Error: Test name and script are required" >&2
        return 1
    fi
    
    if [[ ! -f "$test_script" ]]; then
        echo "Error: Test script not found: $test_script" >&2
        return 1
    fi
    
    echo "Setting up temporary environment for $test_name..."
    local temp_dir
    if ! temp_dir=$(create_temp_test_env "$test_name"); then
        echo "Error: Failed to create temporary environment" >&2
        return 1
    fi
    
    # Change to temporary directory
    if ! cd "$temp_dir"; then
        echo "Error: Failed to change to temporary directory" >&2
        cleanup_temp_test_env "$temp_dir"
        return 1
    fi
    
    # Run the test script
    local exit_code=0
    if bash "$test_script"; then
        log_test_result "$test_name" "PASS" "Test completed successfully"
    else
        log_test_result "$test_name" "FAIL" "Test failed"
        exit_code=1
    fi
    
    # Cleanup
    cleanup_temp_test_env "$temp_dir"
    
    return $exit_code
}

# Function to check if we're in a git repository
is_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Function to safely run git commands
safe_git() {
    if ! is_git_repo; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    git "$@"
}

# Function to create test files
create_test_file() {
    local file_path="$1"
    local content="$2"
    
    if [[ -z "$file_path" ]]; then
        echo "Error: File path is required" >&2
        return 1
    fi
    
    if ! mkdir -p "$(dirname "$file_path")"; then
        echo "Error: Failed to create directory for $file_path" >&2
        return 1
    fi
    
    echo "$content" > "$file_path"
}

# Function to commit test files
commit_test_files() {
    local message="$1"
    shift
    
    if [[ -z "$message" ]]; then
        echo "Error: Commit message is required" >&2
        return 1
    fi
    
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            git add "$file" 2>/dev/null || true
        else
            echo "Warning: File not found: $file" >&2
        fi
    done
    
    git commit -m "$message" >/dev/null 2>&1 || true
}

# Function to generate license header for test source files
generate_license_header() {
    local file_type="$1"  # "c", "cpp", "h", "hh", etc.
    local description="$2"  # Optional description of the file's purpose
    
    # Get current year, with minimum of 2025
    local current_year
    current_year=$(date +%Y)
    if [[ "$current_year" -lt 2025 ]]; then
        current_year=2025
    fi
    
    # Generate appropriate comment style based on file type
    case "$file_type" in
        "c"|"cpp"|"h"|"hh"|"hpp")
            # C/C++ style comments
            cat << EOF
// Copyright © $current_year Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter test suite and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.
EOF
            if [[ -n "$description" ]]; then
                echo "//"
                echo "// $description"
            fi
            echo ""
            ;;
        "sh"|"bash")
            # Shell script style comments
            cat << EOF
# Copyright © $current_year Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter test suite and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
EOF
            if [[ -n "$description" ]]; then
                echo "#"
                echo "# $description"
            fi
            echo ""
            ;;
        *)
            # Default to C-style comments for unknown file types
            cat << EOF
// Copyright © $current_year Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter test suite and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.
EOF
            if [[ -n "$description" ]]; then
                echo "//"
                echo "// $description"
            fi
            echo ""
            ;;
    esac
}

# Function to validate test environment
validate_test_env() {
    local temp_dir="$1"
    
    if [[ -z "$temp_dir" || ! -d "$temp_dir" ]]; then
        log_test_result "ENV_VALIDATION" "FAIL" "Invalid temporary directory"
        return 1
    fi
    
    if [[ ! -f "$temp_dir/VERSION" ]]; then
        log_test_result "ENV_VALIDATION" "FAIL" "VERSION file not found"
        return 1
    fi
    
    if ! cd "$temp_dir" || ! is_git_repo; then
        log_test_result "ENV_VALIDATION" "FAIL" "Git repository not properly initialized"
        return 1
    fi
    
    log_test_result "ENV_VALIDATION" "PASS" "Test environment is valid"
    return 0
}

# Function to print test summary
print_test_summary() {
    echo ""
    echo "=== Test Summary ==="
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Export functions for use in test scripts
export -f create_temp_test_env
export -f cleanup_temp_test_env
export -f run_test_in_temp_env
export -f is_git_repo
export -f safe_git
export -f create_test_file
export -f commit_test_files
export -f generate_license_header
export -f validate_test_env
export -f log_test_result
export -f print_test_summary 