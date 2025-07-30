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

#### `edge-case-tests/`
Contains tests for edge cases and boundary conditions:
- `test_cli_detection_fix.sh` - CLI detection edge case fixes
- `test_env_normalization.sh` - Environment variable normalization tests
- `test_ere_fix.sh` - ERE edge case fixes

#### `file-handling-tests/`
Contains tests for file processing and handling:
- `test_breaking_case_detection.sh` - Breaking case detection tests
- `test_header_removal.sh` - Header removal functionality tests
- `test_nul_safety.sh` - Null byte safety tests
- `test_rename_handling.sh` - File rename handling tests
- `test_whitespace_ignore.sh` - Whitespace handling tests

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

#### `utility-tests/`
Contains utility function tests:
- `debug_test.sh` - Debug utility tests
- `test_case.sh` - Case handling tests
- `test_classify.sh` - Classification function tests
- `test_classify_fixed.sh` - Fixed classification tests
- `test_classify_inline.sh` - Inline classification tests
- `test_classify_inline2.sh` - Additional inline classification tests
- `test_func.sh` - Function utility tests
- `test_func2.sh` - Additional function utility tests

## Running Tests

### Quick Start

Run all tests using the main test runner:

```bash
./run_tests.sh
```

This will run both the test-workflows tests and the C++ tests in sequence.

### Individual Test Suites

#### C++ Tests Only

```bash
# Run C++ unit tests
./test/run_unit_tests.sh

# Run specific C++ test
./build/bin/test_basic
./build/bin/test_comprehensive
./build/bin/test_edge_cases
./build/bin/test_integration
./build/bin/test_memory_leaks
./build/bin/test_path_validation
./build/bin/test_regex_patterns
./build/bin/test_cli_options
```

#### Workflow Tests Only

```bash
# Run all workflow tests
./test-workflows/run_workflow_tests.sh

# Run specific workflow test categories
./test-workflows/cli-tests/test_extract.sh
./test-workflows/file-handling-tests/test_whitespace_ignore.sh
./test-workflows/utility-tests/test_classify.sh
```

#### Build and Test

```bash
# Build and run all tests
./build.sh tests

# Build with specific options and test
./build.sh tests debug warnings
./build.sh tests performance warnings
```

### Manual Testing

For manual testing and debugging:

```bash
# Test specific functionality
./build/bin/vglog-filter --help
./build/bin/vglog-filter --version

# Test with sample input
echo "test input" | ./build/bin/vglog-filter

# Test file processing
./build/bin/vglog-filter test-workflows/fixture-tests/test_whitespace.txt
```

## Test Configuration

### Build Configurations

Tests are run across multiple build configurations:

- **Default**: Standard build with O2 optimizations
- **Performance**: O3 optimizations with LTO and native architecture tuning
- **Debug**: Debug symbols with O0 optimization for debugging
- **Warnings**: Extra compiler warnings for code quality
- **Combinations**: All possible combinations of the above

### Test Environment

Tests are configured with:
- **Automatic cleanup**: Temporary files are cleaned up before and after tests
- **Isolated execution**: Each test runs in isolation to prevent interference
- **Error reporting**: Comprehensive error messages for debugging
- **Cross-platform**: Tests work across different Linux distributions

## Adding New Tests

### C++ Unit Tests

To add a new C++ unit test:

1. Create a new test file in the `test/` directory:
   ```cpp
   // test_new_feature.cpp
   #include <cassert>
   #include <iostream>
   #include <string>
   
   int main() {
       // Test implementation
       std::cout << "Running new feature test..." << std::endl;
       
       // Add test assertions
       assert(true && "Basic test passed");
       
       std::cout << "All tests passed!" << std::endl;
       return 0;
   }
   ```

2. The test will be automatically included in the CMake build system

3. Run the test:
   ```bash
   ./build/bin/test_new_feature
   ```

### Workflow Tests

To add a new workflow test:

1. Create a new test script in the appropriate `test-workflows/` subdirectory
2. Make the script executable: `chmod +x test_new_workflow.sh`
3. The test will be automatically included in the workflow test runner

### Test Guidelines

- **Naming**: Use descriptive names that indicate what is being tested
- **Isolation**: Each test should be independent and not rely on other tests
- **Cleanup**: Always clean up any temporary files or resources
- **Documentation**: Include comments explaining what the test verifies
- **Error handling**: Test both success and failure cases

## CI/CD Testing

### GitHub Actions Integration

The project uses comprehensive GitHub Actions workflows for automated testing:

#### Core Testing Workflows
- **Build and Test** (`test.yml`): Basic build verification and functionality testing
- **Comprehensive Test** (`comprehensive-test.yml`): Complete testing of all build configurations
- **Debug Build Test** (`debug-build-test.yml`): Dedicated testing for debug builds

#### Quality Assurance Workflows
- **Clang-Tidy** (`clang-tidy.yml`): Static analysis and code quality checks
- **Memory Sanitizer** (`memory-sanitizer.yml`): Memory error detection
- **CodeQL** (`codeql.yml`): Security analysis and vulnerability detection
- **ShellCheck** (`shellcheck.yml`): Shell script validation

#### Performance and Compatibility Workflows
- **Performance Benchmark** (`performance-benchmark.yml`): Performance testing and optimization verification
- **Cross-Platform Test** (`cross-platform.yml`): Multi-platform compatibility testing

### Build Matrix

The CI/CD pipeline tests all 12 build configuration combinations:
- Default build
- Performance build
- Debug build
- Warnings build
- Performance + Warnings
- Debug + Warnings
- Tests build
- Performance + Tests
- Debug + Tests
- Warnings + Tests
- Performance + Warnings + Tests
- Debug + Warnings + Tests

### Test Results

All tests must pass for:
- Pull request merges
- Release creation
- Deployment to production

## Test Output and Debugging

### Understanding Test Output

#### C++ Test Output
```
Running test_basic...
Test: Basic functionality test
Result: PASSED
Running test_comprehensive...
Test: Comprehensive feature test
Result: PASSED
All tests completed successfully.
```

#### Workflow Test Output
```
Running CLI tests...
✓ test_extract.sh passed
✓ test_fixes.sh passed
Running file handling tests...
✓ test_whitespace_ignore.sh passed
✓ test_nul_safety.sh passed
All workflow tests completed successfully.
```

### Debugging Failed Tests

#### C++ Test Debugging
```bash
# Run with debug output
./build/bin/test_basic

# Run with GDB for detailed debugging
gdb ./build/bin/test_basic
(gdb) run
(gdb) bt  # Backtrace on failure
```

#### Workflow Test Debugging
```bash
# Run with verbose output
bash -x ./test-workflows/cli-tests/test_extract.sh

# Run individual test steps
./test-workflows/cli-tests/test_extract.sh
```

### Common Test Issues

1. **Build failures**: Check compiler version and dependencies
2. **Test timeouts**: Increase timeout values for slow systems
3. **Permission errors**: Check file permissions and ownership
4. **Memory issues**: Run with memory sanitizer in debug builds
5. **Platform differences**: Test on multiple platforms

### Performance Testing

#### Benchmark Tests
```bash
# Run performance benchmarks
./build.sh performance tests

# Monitor memory usage
./build/bin/vglog-filter -M large_file.log > /dev/null
```

#### Optimization Verification
- **LTO verification**: Ensure link-time optimization is working
- **Native optimization**: Verify architecture-specific optimizations
- **Memory efficiency**: Check memory usage patterns
- **Processing speed**: Measure processing time for large files

## Test Maintenance

### Regular Maintenance Tasks

1. **Update test dependencies**: Keep test tools and libraries current
2. **Review test coverage**: Ensure new features have adequate test coverage
3. **Clean up old tests**: Remove obsolete or redundant tests
4. **Update test documentation**: Keep this document current

### Test Quality Metrics

- **Coverage**: Aim for high test coverage of core functionality
- **Reliability**: Tests should be stable and not flaky
- **Performance**: Tests should run quickly and efficiently
- **Maintainability**: Tests should be easy to understand and modify

---

For more information about the CI/CD infrastructure, see [CI_CD_GUIDE.md](CI_CD_GUIDE.md).
For build configuration details, see [BUILD.md](BUILD.md). 