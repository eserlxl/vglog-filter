# Test Suite Documentation

This document provides comprehensive information about the vglog-filter test suite, including how to run tests, test organization, and development guidelines.

## Table of Contents

- [Overview](#overview)
- [Test Organization](#test-organization)
  - [C++ Unit Tests](#c-unit-tests)
  - [Test Workflows](#test-workflows)
- [Running Tests](#running-tests)
  - [Quick Start](#quick-start)
  - [Individual Test Suites](#individual-test-suites)
  - [Manual Testing](#manual-testing)
- [Test Configuration](#test-configuration)
- [Adding New Tests](#adding-new-tests)
- [CI/CD Testing](#cicd-testing)
- [Test Output and Debugging](#test-output-and-debugging)

## Overview

vglog-filter includes a comprehensive test suite designed to ensure code quality, functionality, and performance across all build configurations. The test infrastructure consists of:

- **C++ Unit Tests**: Core functionality tests in the `test/` directory
- **Test Workflows**: Integration and workflow tests in `test-workflows/`
- **CI/CD Integration**: Automated testing across multiple platforms and configurations
- **Performance Testing**: Automated benchmarks and optimization verification

## Test Organization

### C++ Unit Tests

Located in the `test/` directory, these tests cover core functionality:

- **`test_basic.cpp`** - Basic functionality tests
- **`test_comprehensive.cpp`** - Comprehensive feature tests  
- **`test_edge_cases.cpp`** - Edge case and boundary condition tests
- **`test_integration.cpp`** - Integration tests
- **`test_memory_leaks.cpp`** - Memory leak detection tests
- **`test_path_validation.cpp`** - Path validation security tests
- **`test_regex_patterns.cpp`** - Regex pattern matching and replacement tests
- **`test_cli_options.cpp`** - Command-line argument parsing tests

#### Test Configuration

C++ tests are configured with:
- Debug build mode for better error reporting
- Warning mode enabled for stricter compilation
- Sanitizers enabled for memory and undefined behavior detection
- C++20 standard
- Automatic cleanup of temporary files

### Test Workflows

Located in the `test-workflows/` directory, these tests cover integration scenarios:

#### `cli-tests/`
Contains tests related to command-line interface functionality:
- `test_extract.sh` - Tests for CLI option extraction
- `test_fixes.sh` - Tests for CLI-related fixes and improvements
- `test_manual_cli_nested.c` - Sample C file with CLI options for testing

#### `debug-tests/`
Contains debugging and manual testing scripts:
- `test_debug.sh` - Manual CLI detection testing script

#### `ere-tests/`
Contains tests for Extended Regular Expression (ERE) functionality:
- `test_ere.c` - ERE test file with CLI options
- `test_ere_fix.c` - ERE test file with additional options

#### `fixture-tests/`
Contains test fixtures and sample data:
- `test_whitespace.txt` - Whitespace-only test file

#### `source-fixtures/`
Contains copies of source files used for testing:
- `test-workflows/source-fixtures/internal/header.hh` - Internal header file for API testing
- `test-workflows/source-fixtures/cli/main.c` - CLI main file for testing
- `cli/simple_cli_test.c` - Simple CLI test program with basic argument handling
- `test_content_simple.txt` - Simple test content file for basic file processing tests
- `test_content_renamed.txt` - Test content file for rename handling tests
- `debug_log_with_marker.txt` - Debug log content with markers for log filtering tests

## Running Tests

### Quick Start

Run all tests using the main test runner:

```bash
./run_tests.sh
```

This will run both the test-workflows tests and the C++ tests in sequence.

### Individual Test Suites

#### C++ Tests Only

To run only the C++ tests:

```bash
./test/run_unit_tests.sh
```

#### Test Workflows Only

To run only the test-workflows tests:

```bash
./test-workflows/run_workflow_tests.sh
```

### Manual Testing

#### C++ Tests Manual Build

If you prefer to build and run C++ tests manually:

```bash
# Create build directory
mkdir -p build-test
cd build-test

# Configure with testing enabled
cmake .. -DBUILD_TESTING=ON -DCMAKE_BUILD_TYPE=Debug

# Build tests
make -j20

# Run tests
ctest --output-on-failure
```

#### Using build.sh

The `build.sh` script provides convenient test integration:

```bash
# Build and run tests
./build.sh tests

# Run tests with specific build configuration
./build.sh tests debug warnings

# Run tests with performance optimizations
./build.sh tests performance warnings
```

## Test Configuration

### Build Configurations

All tests are run across multiple build configurations:

- **Default build** - Standard compilation
- **Performance build** - Optimized with `-O3 -march=native -flto`
- **Debug build** - Debug symbols and sanitizers enabled
- **Warnings build** - Extra compiler warnings enabled
- **All combinations** - Performance + Debug + Warnings + Tests

### Test Environment

Tests are configured with:
- **Debug mode**: Better error reporting and stack traces
- **Warning mode**: Stricter compilation for code quality
- **Sanitizers**: Memory and undefined behavior detection
- **C++20 standard**: Modern C++ features
- **Parallel compilation**: Uses `make -j20` for faster builds

## Adding New Tests

### C++ Tests

To add a new C++ test:

1. Create a new `.cpp` file in the `test/` directory
2. Follow the naming convention: `test_*.cpp`
3. The test will be automatically picked up by CMake
4. Use standard C++ testing practices (assertions, etc.)
5. Include proper cleanup in destructors or test teardown

Example test structure:
```cpp
#include <cassert>
#include <iostream>

int main() {
    // Test setup
    // ... test logic ...
    
    // Assertions
    assert(condition && "Test description");
    
    // Cleanup
    // ... cleanup code ...
    
    std::cout << "Test passed!" << std::endl;
    return 0;
}
```

### Test Workflows

To add new test workflows:

1. Create test scripts in appropriate subdirectories
2. Follow the existing naming conventions
3. Ensure scripts are executable (`chmod +x`)
4. Update `test-workflows/run_workflow_tests.sh` if needed

## CI/CD Testing

### GitHub Actions Workflows

The project includes comprehensive CI/CD testing:

- **Build and Test**: Multi-platform testing with multiple build configurations
- **Comprehensive Test**: Tests all 12 build configuration combinations
- **Debug Build Test**: Dedicated testing for debug builds with GDB integration
- **Cross-Platform Test**: Tests builds across Ubuntu, Arch Linux, Fedora, and Debian
- **Performance Benchmark**: Automated performance testing and optimization verification
- **Memory Sanitizer**: Memory error detection using Clang's MemorySanitizer
- **Clang-Tidy**: Static analysis and code quality checks
- **CodeQL**: Security analysis and vulnerability detection
- **ShellCheck**: Shell script linting and validation

### Local Testing

All build configurations are tested locally and in CI:
- Default build
- Performance build (optimized)
- Debug build
- Warnings build (extra compiler warnings)
- All combinations with tests
- Performance + Warnings
- Debug + Warnings
- Performance + Tests
- Debug + Tests
- Warnings + Tests
- Performance + Warnings + Tests
- Debug + Warnings + Tests

## Test Output and Debugging

### Test Runner Output

The test runners provide:
- **Colored output**: Easy-to-read success/error indicators
- **Detailed error reporting**: Specific failure information
- **Individual test executable output**: Detailed output from each test
- **CTest summary**: Structured test results
- **Progress reporting**: Real-time progress updates

### Debugging Failed Tests

#### C++ Tests

For debugging C++ test failures:

```bash
# Run with debug symbols
./build.sh tests debug

# Run individual test with GDB
gdb build-test/test_basic

# Run with sanitizers for memory issues
./build.sh tests debug
```

#### Test Workflows

For debugging test workflow failures:

```bash
# Run individual test scripts
./test-workflows/cli-tests/test_extract.sh

# Enable debug output
bash -x ./test-workflows/run_workflow_tests.sh
```

### Common Issues

1. **Build failures**: Check compiler version and dependencies
2. **Test failures**: Review test output for specific error messages
3. **Memory issues**: Run with sanitizers enabled
4. **Performance regressions**: Compare with previous benchmark results

## Performance Testing

### Automated Benchmarks

The CI/CD includes automated performance testing:
- **Performance regression detection**: Compares against baseline
- **Optimization verification**: Ensures performance flags work correctly
- **Memory usage tracking**: Monitors memory consumption during tests

### Manual Performance Testing

```bash
# Run performance tests
./build.sh tests performance

# Monitor memory usage
./test/run_unit_tests.sh  # Includes memory monitoring
```

## Quality Assurance

The test suite ensures:
- **Code coverage**: All major functionality is tested
- **Edge case handling**: Boundary conditions and error scenarios
- **Memory safety**: Leak detection and sanitizer testing
- **Performance**: Optimization verification and benchmarking
- **Cross-platform compatibility**: Testing across different Linux distributions
- **Static analysis**: Code quality and security scanning

For more information about the testing infrastructure, see the [CI/CD Guide](CI_CD_GUIDE.md). 