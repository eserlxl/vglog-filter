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
    
    # Get the project root (use environment variable if available, otherwise use current directory)
    local project_root
    project_root="${PROJECT_ROOT:-$(pwd)}"
    
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
    # Create test-specific VERSION file in /tmp (never touch project files)
    echo "10.5.12" > VERSION
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

# Function to create a realistic test repository with substantial history
create_realistic_test_repo() {
    local test_name="${1:-realistic}"
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
    
    # Get the project root
    local project_root
    project_root="${PROJECT_ROOT:-$(pwd)}"
    
    # Validate project root exists
    if [[ ! -d "$project_root" ]]; then
        echo "Error: Project root directory not found: $project_root" >&2
        return 1
    fi
    
    # Create a realistic project structure
    if ! cd "$temp_dir"; then
        echo "Error: Failed to change to temporary directory" >&2
        return 1
    fi
    
    # Create realistic project structure
    mkdir -p src include test doc examples scripts tools
    
    # Initialize git repository
    if ! git init --quiet; then
        echo "Error: Failed to initialize git repository" >&2
        return 1
    fi
    
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial project files
    echo "1.0.0" > VERSION
    cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.10)
project(realistic-test VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(main src/main.cpp)
target_include_directories(main PRIVATE include)
EOF

    # Create initial source files
    cat > include/config.h << 'EOF'
#ifndef CONFIG_H
#define CONFIG_H

#define VERSION_MAJOR 1
#define VERSION_MINOR 0
#define VERSION_PATCH 0

// Basic configuration
#define DEFAULT_TIMEOUT 30
#define MAX_BUFFER_SIZE 1024

#endif // CONFIG_H
EOF

    cat > src/main.cpp << 'EOF'
#include <iostream>
#include "config.h"

int main() {
    std::cout << "Hello, World!" << std::endl;
    std::cout << "Version: " << VERSION_MAJOR << "." << VERSION_MINOR << "." << VERSION_PATCH << std::endl;
    return 0;
}
EOF

    cat > README.md << 'EOF'
# Realistic Test Project

This is a realistic test project for semantic version analysis.

## Features
- Basic functionality
- Configuration system
- Documentation

## Building
```bash
mkdir build && cd build
cmake ..
make
```
EOF

    # Initial commit
    git add . >/dev/null 2>&1
    git commit -m "Initial project setup" >/dev/null 2>&1
    
    # Create first release tag
    git tag v1.0.0 >/dev/null 2>&1
    
    # Add utility functions (minor feature)
    cat > src/utils.cpp << 'EOF'
#include "utils.h"
#include <string>
#include <sstream>

std::string format_message(const std::string& msg) {
    return "Formatted: " + msg;
}

int calculate_sum(int a, int b) {
    return a + b;
}

std::string version_string() {
    std::ostringstream oss;
    oss << VERSION_MAJOR << "." << VERSION_MINOR << "." << VERSION_PATCH;
    return oss.str();
}
EOF

    cat > include/utils.h << 'EOF'
#ifndef UTILS_H
#define UTILS_H

#include <string>

std::string format_message(const std::string& msg);
int calculate_sum(int a, int b);
std::string version_string();

#endif // UTILS_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add utility functions and version string helper" >/dev/null 2>&1
    
    # Add tests (minor feature)
    cat > test/test_utils.cpp << 'EOF'
#include "utils.h"
#include <cassert>
#include <iostream>

int main() {
    assert(format_message("test") == "Formatted: test");
    assert(calculate_sum(2, 3) == 5);
    assert(!version_string().empty());
    std::cout << "All tests passed!" << std::endl;
    return 0;
}
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add unit tests for utility functions" >/dev/null 2>&1
    
    # Create second release
    git tag v1.1.0 >/dev/null 2>&1
    
    # Add CLI functionality (minor feature)
    cat > src/cli.cpp << 'EOF'
#include "cli.h"
#include <iostream>
#include <string>

void process_cli_args(int argc, char* argv[]) {
    for (int i = 1; i < argc; ++i) {
        std::cout << "Processing: " << argv[i] << std::endl;
    }
}

void show_help() {
    std::cout << "Usage: program [options]" << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  --help     Show this help" << std::endl;
    std::cout << "  --version  Show version" << std::endl;
    std::cout << "  --verbose  Enable verbose output" << std::endl;
}
EOF

    cat > include/cli.h << 'EOF'
#ifndef CLI_H
#define CLI_H

void process_cli_args(int argc, char* argv[]);
void show_help();

#endif // CLI_H
EOF

    # Update main to use CLI
    cat > src/main.cpp << 'EOF'
#include <iostream>
#include "config.h"
#include "cli.h"
#include "utils.h"

int main(int argc, char* argv[]) {
    std::cout << "Hello, World!" << std::endl;
    std::cout << "Version: " << version_string() << std::endl;
    
    if (argc > 1) {
        process_cli_args(argc, argv);
    } else {
        show_help();
    }
    
    return 0;
}
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add CLI support with help and version options" >/dev/null 2>&1
    
    # Add documentation
    cat > doc/USAGE.md << 'EOF'
# Usage Guide

## Command Line Interface

The application supports various command line options:

- `--help`: Show help information
- `--version`: Show version information
- `--verbose`: Enable verbose output

## Examples

```bash
./main --help
./main --version
./main --verbose
```
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add usage documentation" >/dev/null 2>&1
    
    # Create third release
    git tag v1.2.0 >/dev/null 2>&1
    
    # Add security fixes (patch)
    cat > src/security.cpp << 'EOF'
#include "security.h"
#include <cstring>
#include <stdexcept>

void secure_copy(char* dest, const char* src, size_t size) {
    if (!dest || !src || size == 0) {
        throw std::invalid_argument("Invalid parameters for secure_copy");
    }
    strncpy(dest, src, size - 1);
    dest[size - 1] = '\0';  // Ensure null termination
}

bool validate_input(const std::string& input) {
    return !input.empty() && input.length() <= MAX_BUFFER_SIZE;
}
EOF

    cat > include/security.h << 'EOF'
#ifndef SECURITY_H
#define SECURITY_H

#include <cstddef>
#include <string>

void secure_copy(char* dest, const char* src, size_t size);
bool validate_input(const std::string& input);

#endif // SECURITY_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "SECURITY: Fix buffer overflow and add input validation" >/dev/null 2>&1
    
    # Create patch release
    git tag v1.2.1 >/dev/null 2>&1
    
    # Add breaking changes (major)
    cat > include/config.h << 'EOF'
#ifndef CONFIG_H
#define CONFIG_H

#define VERSION_MAJOR 2
#define VERSION_MINOR 0
#define VERSION_PATCH 0

// Breaking change: renamed constants
#define DEFAULT_TIMEOUT_SECONDS 30  // was DEFAULT_TIMEOUT
#define MAX_BUFFER_SIZE_BYTES 1024  // was MAX_BUFFER_SIZE

// New configuration options
#define ENABLE_LOGGING true
#define LOG_LEVEL 2

#endif // CONFIG_H
EOF

    # Update utils to use new constants
    cat > src/utils.cpp << 'EOF'
#include "utils.h"
#include <string>
#include <sstream>

std::string format_message(const std::string& msg) {
    return "Formatted: " + msg;
}

int calculate_sum(int a, int b) {
    return a + b;
}

std::string version_string() {
    std::ostringstream oss;
    oss << VERSION_MAJOR << "." << VERSION_MINOR << "." << VERSION_PATCH;
    return oss.str();
}

// New function with breaking change
std::string format_message_v2(const std::string& msg, bool uppercase) {
    std::string result = "Formatted: " + msg;
    if (uppercase) {
        for (char& c : result) {
            c = std::toupper(c);
        }
    }
    return result;
}
EOF

    cat > include/utils.h << 'EOF'
#ifndef UTILS_H
#define UTILS_H

#include <string>

std::string format_message(const std::string& msg);
int calculate_sum(int a, int b);
std::string version_string();
std::string format_message_v2(const std::string& msg, bool uppercase);

#endif // UTILS_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "BREAKING: Rename configuration constants and add format_message_v2" >/dev/null 2>&1
    
    # Create major release
    git tag v2.0.0 >/dev/null 2>&1
    
    # Add network features (minor)
    cat > src/network.cpp << 'EOF'
#include "network.h"
#include <iostream>
#include <string>

bool connect_to_server(const std::string& host, int port) {
    std::cout << "Connecting to " << host << ":" << port << std::endl;
    return true;  // Simplified
}

bool send_data(const std::string& data) {
    std::cout << "Sending data: " << data << std::endl;
    return true;  // Simplified
}

std::string receive_data() {
    return "Received data";  // Simplified
}
EOF

    cat > include/network.h << 'EOF'
#ifndef NETWORK_H
#define NETWORK_H

#include <string>

bool connect_to_server(const std::string& host, int port);
bool send_data(const std::string& data);
std::string receive_data();

#endif // NETWORK_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add network connectivity features" >/dev/null 2>&1
    
    # Add examples
    cat > examples/basic_usage.cpp << 'EOF'
#include "config.h"
#include "utils.h"
#include "cli.h"
#include <iostream>

int main() {
    std::cout << "Basic usage example" << std::endl;
    std::cout << format_message("Hello from example") << std::endl;
    std::cout << format_message_v2("Hello from example", true) << std::endl;
    return 0;
}
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add usage examples with new v2 API" >/dev/null 2>&1
    
    # Create minor release
    git tag v2.1.0 >/dev/null 2>&1
    
    # Add more security fixes (patch)
    cat > src/security.cpp << 'EOF'
#include "security.h"
#include <cstring>
#include <stdexcept>
#include <algorithm>

void secure_copy(char* dest, const char* src, size_t size) {
    if (!dest || !src || size == 0) {
        throw std::invalid_argument("Invalid parameters for secure_copy");
    }
    strncpy(dest, src, size - 1);
    dest[size - 1] = '\0';  // Ensure null termination
}

bool validate_input(const std::string& input) {
    return !input.empty() && input.length() <= MAX_BUFFER_SIZE_BYTES;
}

// New security function
bool sanitize_string(std::string& input) {
    // Remove potentially dangerous characters
    input.erase(std::remove(input.begin(), input.end(), '\0'), input.end());
    input.erase(std::remove(input.begin(), input.end(), '\r'), input.end());
    return true;
}
EOF

    cat > include/security.h << 'EOF'
#ifndef SECURITY_H
#define SECURITY_H

#include <cstddef>
#include <string>

void secure_copy(char* dest, const char* src, size_t size);
bool validate_input(const std::string& input);
bool sanitize_string(std::string& input);

#endif // SECURITY_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "SECURITY: Add string sanitization function" >/dev/null 2>&1
    
    # Create patch release
    git tag v2.1.1 >/dev/null 2>&1
    
    # Add database features (minor)
    cat > src/database.cpp << 'EOF'
#include "database.h"
#include <iostream>
#include <map>
#include <string>

class Database {
private:
    std::map<std::string, std::string> data;
public:
    bool connect(const std::string& connection_string) {
        std::cout << "Connecting to database: " << connection_string << std::endl;
        return true;
    }
    
    bool insert(const std::string& key, const std::string& value) {
        data[key] = value;
        return true;
    }
    
    std::string get(const std::string& key) {
        auto it = data.find(key);
        return (it != data.end()) ? it->second : "";
    }
};

static Database db;

bool db_connect(const std::string& connection_string) {
    return db.connect(connection_string);
}

bool db_insert(const std::string& key, const std::string& value) {
    return db.insert(key, value);
}

std::string db_get(const std::string& key) {
    return db.get(key);
}
EOF

    cat > include/database.h << 'EOF'
#ifndef DATABASE_H
#define DATABASE_H

#include <string>

bool db_connect(const std::string& connection_string);
bool db_insert(const std::string& key, const std::string& value);
std::string db_get(const std::string& key);

#endif // DATABASE_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "Add database connectivity and operations" >/dev/null 2>&1
    
    # Create minor release
    git tag v2.2.0 >/dev/null 2>&1
    
    # Add performance improvements (patch)
    cat > src/performance.cpp << 'EOF'
#include "performance.h"
#include <chrono>
#include <iostream>

void enable_performance_mode() {
    std::cout << "Performance mode enabled" << std::endl;
}

long long get_execution_time_ms() {
    static auto start_time = std::chrono::high_resolution_clock::now();
    auto current_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(current_time - start_time);
    return duration.count();
}
EOF

    cat > include/performance.h << 'EOF'
#ifndef PERFORMANCE_H
#define PERFORMANCE_H

void enable_performance_mode();
long long get_execution_time_ms();

#endif // PERFORMANCE_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "PERFORMANCE: Add performance monitoring and optimization" >/dev/null 2>&1
    
    # Create patch release
    git tag v2.2.1 >/dev/null 2>&1
    
    # Add breaking changes again (major)
    cat > include/config.h << 'EOF'
#ifndef CONFIG_H
#define CONFIG_H

#define VERSION_MAJOR 3
#define VERSION_MINOR 0
#define VERSION_PATCH 0

// Breaking change: restructured configuration
namespace config {
    const int DEFAULT_TIMEOUT_SECONDS = 30;
    const int MAX_BUFFER_SIZE_BYTES = 1024;
    const bool ENABLE_LOGGING = true;
    const int LOG_LEVEL = 2;
}

// Legacy compatibility (deprecated)
#define DEFAULT_TIMEOUT_SECONDS config::DEFAULT_TIMEOUT_SECONDS
#define MAX_BUFFER_SIZE_BYTES config::MAX_BUFFER_SIZE_BYTES
#define ENABLE_LOGGING config::ENABLE_LOGGING
#define LOG_LEVEL config::LOG_LEVEL

#endif // CONFIG_H
EOF

    # Update utils to use new namespace
    cat > src/utils.cpp << 'EOF'
#include "utils.h"
#include <string>
#include <sstream>

std::string format_message(const std::string& msg) {
    return "Formatted: " + msg;
}

int calculate_sum(int a, int b) {
    return a + b;
}

std::string version_string() {
    std::ostringstream oss;
    oss << VERSION_MAJOR << "." << VERSION_MINOR << "." << VERSION_PATCH;
    return oss.str();
}

std::string format_message_v2(const std::string& msg, bool uppercase) {
    std::string result = "Formatted: " + msg;
    if (uppercase) {
        for (char& c : result) {
            c = std::toupper(c);
        }
    }
    return result;
}

// New v3 API
std::string format_message_v3(const std::string& msg, const std::string& prefix) {
    return prefix + ": " + msg;
}
EOF

    cat > include/utils.h << 'EOF'
#ifndef UTILS_H
#define UTILS_H

#include <string>

std::string format_message(const std::string& msg);
int calculate_sum(int a, int b);
std::string version_string();
std::string format_message_v2(const std::string& msg, bool uppercase);
std::string format_message_v3(const std::string& msg, const std::string& prefix);

#endif // UTILS_H
EOF

    git add . >/dev/null 2>&1
    git commit -m "BREAKING: Restructure configuration into namespace and add v3 API" >/dev/null 2>&1
    
    # Create major release
    git tag v3.0.0 >/dev/null 2>&1
    
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
export -f create_realistic_test_repo
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