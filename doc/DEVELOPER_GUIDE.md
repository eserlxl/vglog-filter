# Developer Guide

This guide provides comprehensive information for developers working on vglog-filter, including build options, versioning system, and testing infrastructure.

## Table of Contents

- [Build Options](#build-options)
  - [Usage with build.sh](#usage-with-buildsh)
- [Versioning System](#versioning-system)
  - [Current Version](#current-version)
  - [Automated Version Bumping](#automated-version-bumping)
  - [Manual Version Management](#manual-version-management)
- [Testing & CI/CD](#testing--cicd)
  - [Test Suite Overview](#test-suite-overview)
  - [GitHub Actions Workflows](#github-actions-workflows)
  - [Local Testing](#local-testing)
  - [Development Tools](#development-tools)

## Build Options

This project supports several build modes via CMake options and the `build.sh` script:

- **PERFORMANCE_BUILD**: Enables performance optimizations (`-O3 -march=native -mtune=native -flto`, defines `NDEBUG`).
- **WARNING_MODE**: Enables extra compiler warnings (`-Wextra` in addition to `-Wall -pedantic`).
- **DEBUG_MODE**: Enables debug flags (`-g -O0`, defines `DEBUG`). Mutually exclusive with PERFORMANCE_BUILD (debug takes precedence).

### Usage with build.sh

You can use the `build.sh` script to configure builds with these options:

- Default build:
  ```sh
  ./build.sh
  ```
- Performance build:
  ```sh
  ./build.sh performance
  ```
- Extra warnings:
  ```sh
  ./build.sh warnings
  ```
- Debug build:
  ```sh
  ./build.sh debug
  ```
- Clean build (removes all build artifacts):
  ```sh
  ./build.sh clean
  ```
- Combine options (e.g., debug + warnings):
  ```sh
  ./build.sh debug warnings
  ```
- Performance build with warnings and clean:
  ```sh
  ./build.sh performance warnings clean
  ```
- Build and run tests:
  ```sh
  ./build.sh tests
  ```
- Build and run tests with warnings:
  ```sh
  ./build.sh tests warnings
  ```
- Build and run tests in debug mode:
  ```sh
  ./build.sh tests debug
  ```

If both `debug` and `performance` are specified, debug mode takes precedence. The `clean` and `tests` options can be combined with any other options.

[↑ Back to top](#developer-guide)

## Versioning System

vglog-filter uses [Semantic Versioning](https://semver.org/) with automated version management:

### Current Version
The current version is stored in the `VERSION` file and displayed with:
```sh
vglog-filter --version
# or
vglog-filter -V
```

**Note**: The version is read from multiple locations in order of preference:
1. `./VERSION` (local development)
2. `../VERSION` (build directory)
3. `/usr/share/vglog-filter/VERSION` (system installation)
4. `/usr/local/share/vglog-filter/VERSION` (local installation)

If none of these files are accessible, the version will be displayed as "unknown".

### Automated Version Bumping
The project uses GitHub Actions to automatically bump versions based on [Conventional Commits](https://www.conventionalcommits.org/):

- **BREAKING CHANGE**: Triggers a **major** version bump
- **feat**: Triggers a **minor** version bump  
- **fix**: Triggers a **patch** version bump
- **docs**, **style**, **refactor**, **perf**, **test**, **chore**: Triggers a **patch** version bump

### Manual Version Management
For manual version bumps, use the provided tools:

```sh
# Command-line version bump
./dev-bin/bump-version [major|minor|patch] [--commit] [--tag]

# Interactive version bump (Cursor IDE)
./dev-bin/cursor-version-bump
```

[↑ Back to top](#developer-guide)

## Testing & CI/CD

The project includes comprehensive testing infrastructure with detailed documentation available in [TEST_SUITE.md](TEST_SUITE.md).

### Test Suite Overview

vglog-filter includes multiple test suites:

- **C++ Unit Tests** (`test/` directory): Core functionality tests with automatic CMake integration
- **Test Workflows** (`test-workflows/` directory): Integration and workflow tests
- **Comprehensive Test Runner** (`run_tests.sh`): Runs all test suites in sequence
- **CI/CD Integration**: Automated testing across multiple platforms and configurations

For detailed information about running tests, adding new tests, and debugging test failures, see the [Test Suite Documentation](TEST_SUITE.md).

### GitHub Actions Workflows
- **Build and Test**: Multi-platform testing with multiple build configurations
- **Comprehensive Test**: Tests all 12 build configuration combinations
- **Debug Build Test**: Dedicated testing for debug builds with GDB integration
- **Cross-Platform Test**: Tests builds across Ubuntu, Arch Linux, Fedora, and Debian
- **Performance Benchmark**: Automated performance testing and optimization verification
- **Memory Sanitizer**: Memory error detection using Clang's MemorySanitizer
- **Clang-Tidy**: Static analysis and code quality checks
- **CodeQL**: Security analysis and vulnerability detection
- **ShellCheck**: Shell script linting and validation
- **Automated Versioning**: Semantic version bumping based on commit messages

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

#### Test Framework
The project includes a basic test framework in the `test/` directory:
- **test_basic.cpp**: Unit tests for core functionality
- **Test Coverage**: Version file reading, empty file handling, basic parsing
- **Automatic Cleanup**: Tests automatically clean up temporary files
- **Build Integration**: Tests can be built and run with `./build.sh tests`

#### Running Tests
```sh
# Build and run tests
./build.sh tests

# Run tests with specific build configuration
./build.sh tests debug warnings

# Run tests with performance optimizations
./build.sh tests performance warnings

# Manual test compilation (if needed)
g++ -std=c++20 -Wall -pedantic -Wextra -O2 test/test_basic.cpp -o build/bin/test_basic
./build/bin/test_basic
```

#### CI/CD Testing
The GitHub Actions workflows automatically test all build configurations:
- **Comprehensive Test**: Tests all 12 build configuration combinations
- **Debug Build Test**: Verifies debug symbols and GDB integration
- **Performance Benchmark**: Tests performance optimizations and LTO
- **Cross-Platform**: Ensures compatibility across different Linux distributions

#### Performance Features
- **Automatic large file detection**: Files >5MB automatically use stream processing
- **Memory optimization**: Vector capacity reservation and efficient string operations
- **Regex optimization**: All patterns use `std::regex::optimize` flag
- **Stream processing**: Line-by-line processing for large files to prevent OOM
- **Smart defaults**: Optimal processing mode selected automatically

### Recent Performance Optimizations

The project has undergone significant performance improvements:

#### String Operations Optimization
- **std::string_view**: Added `std::string_view` support for better performance
- **String trimming**: Optimized with `ltrim_view()`, `rtrim_view()`, and `trim_view()` functions
- **Canonicalization**: Added `canon()` overload for `string_view` to avoid unnecessary copies
- **Memory efficiency**: Reduced string allocations in processing loops

#### Regex Pattern Optimization
- **ECMAScript flags**: All regex patterns now use `std::regex::ECMAScript` flag for better performance
- **Optimized patterns**: Enhanced regex patterns in both `canon()` and `process()` functions
- **Consistent flags**: Standardized regex flags across all patterns for maintainability

#### Large File Processing Improvements
- **Efficient file detection**: Replaced `fopen/fseek/ftell` with `stat()` for single file operation
- **Regular file checking**: Added `S_ISREG()` check to avoid processing directories
- **Optimized thresholds**: Reduced default threshold to 5MB for better auto-detection

#### Array Operations Enhancement
- **std::span support**: Added C++20 `std::span` support for memory-efficient array handling
- **Span helpers**: Added `create_span_from_vector()` and `find_marker_in_span()` functions
- **Marker trimming**: Optimized marker search using `std::span` for better performance

#### New Features

##### Progress Reporting
- **Real-time feedback**: Progress updates every 1000 lines during processing
- **Percentage display**: Shows completion percentage and line counts
- **File-specific**: Progress reporting includes filename for clarity
- **Stdin handling**: Automatically disabled for stdin to avoid performance impact

##### Memory Monitoring
- **Real-time tracking**: Monitor memory usage at key processing stages
- **Performance analysis**: Use `-M` flag to identify memory bottlenecks
- **Resource optimization**: Helps optimize processing for very large files
- **Cross-platform**: Uses `getrusage()` for Linux compatibility

##### Enhanced Error Handling
- **Detailed messages**: Added `create_error_message()` helper for consistent formatting
- **File context**: All error messages include file names and operation details
- **Troubleshooting hints**: Better guidance for common issues
- **Memory failures**: Specific error handling for memory allocation issues

### Development Tools
The `dev-bin/` directory contains development utilities:
- `bump-version`: Command-line version management
- `cursor-version-bump`: Interactive version bumping for Cursor IDE

[↑ Back to top](#developer-guide) 