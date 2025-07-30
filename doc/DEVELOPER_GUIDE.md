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
- **docs**, **style**, **refactor**, **perf**, **test**, **chore**: No version bump

### Manual Version Management
For manual version control, use the provided tools:

```sh
# Analyze changes and suggest version bump
./dev-bin/semantic-version-analyzer --verbose

# Manually bump version
./dev-bin/bump-version [major|minor|patch]

# Manage git tags
./dev-bin/tag-manager list
./dev-bin/tag-manager cleanup [count]
```

[↑ Back to top](#developer-guide)

## Testing & CI/CD

### Test Suite Overview

The project includes a comprehensive test suite with multiple test types:

#### C++ Unit Tests
Located in the `test/` directory:
- **test_basic.cpp**: Basic functionality tests
- **test_comprehensive.cpp**: Comprehensive feature tests
- **test_edge_cases.cpp**: Edge case and boundary condition tests
- **test_integration.cpp**: Integration tests
- **test_memory_leaks.cpp**: Memory leak detection tests
- **test_path_validation.cpp**: Path validation security tests
- **test_regex_patterns.cpp**: Regex pattern matching and replacement tests
- **test_cli_options.cpp**: Command-line argument parsing tests

#### Test Workflows
Located in the `test-workflows/` directory:
- **cli-tests/**: Command-line interface functionality tests
- **debug-tests/**: Debugging and manual testing scripts
- **ere-tests/**: Extended Regular Expression functionality tests
- **file-handling-tests/**: File processing and handling tests
- **utility-tests/**: Utility function tests

### GitHub Actions Workflows

The project uses 12 comprehensive GitHub Actions workflows:

#### Core Testing Workflows
1. **Build and Test** (`test.yml`): Basic build verification and functionality testing
2. **Comprehensive Test** (`comprehensive-test.yml`): Complete testing of all build configurations
3. **Debug Build Test** (`debug-build-test.yml`): Dedicated testing for debug builds

#### Quality Assurance Workflows
4. **Clang-Tidy** (`clang-tidy.yml`): Static analysis and code quality checks
5. **Memory Sanitizer** (`memory-sanitizer.yml`): Memory error detection
6. **CodeQL** (`codeql.yml`): Security analysis and vulnerability detection
7. **ShellCheck** (`shellcheck.yml`): Shell script validation

#### Performance and Compatibility Workflows
8. **Performance Benchmark** (`performance-benchmark.yml`): Performance testing and optimization verification
9. **Cross-Platform Test** (`cross-platform.yml`): Multi-platform compatibility testing

#### Version Management Workflows
10. **Auto Version Bump** (`version-bump.yml`): Automated version bumping and release creation
11. **Tag Cleanup** (`tag-cleanup.yml`): Automated tag management and cleanup

#### Security Workflows
12. **Security Scanning** (`security-scan.yml`): Comprehensive security analysis

### Local Testing

#### Quick Test Run
```sh
# Run all tests
./run_tests.sh

# Run only C++ tests
./test/run_unit_tests.sh

# Run only workflow tests
./test-workflows/run_workflow_tests.sh
```

#### Individual Test Suites
```sh
# Run specific C++ test
./build/bin/test_basic

# Run specific workflow test
./test-workflows/cli-tests/test_extract.sh
```

#### Build and Test
```sh
# Build and run all tests
./build.sh tests

# Build with specific options and test
./build.sh tests debug warnings
```

### Development Tools

#### Version Management Tools
- **semantic-version-analyzer**: Analyzes code changes and suggests version bumps
- **bump-version**: Handles version bumping and release creation
- **tag-manager**: Manages git tags and cleanup
- **cursor-version-bump**: Cursor IDE integration for version bumping

#### Testing Tools
- **run_tests.sh**: Main test runner for all test suites
- **run_unit_tests.sh**: C++ unit test runner
- **run_workflow_tests.sh**: Workflow test runner

#### Build Tools
- **build.sh**: Main build script with multiple configuration options
- **CMakeLists.txt**: CMake configuration with comprehensive build options

## Development Workflow

### 1. Setup Development Environment

```sh
# Clone the repository
git clone <repository-url>
cd vglog-filter

# Install dependencies (Arch Linux)
sudo pacman -S base-devel cmake gcc

# Install dependencies (Ubuntu/Debian)
sudo apt-get install build-essential cmake
```

### 2. Build and Test

```sh
# Build with tests
./build.sh tests

# Build with debug mode
./build.sh debug tests

# Build with performance optimizations
./build.sh performance warnings
```

### 3. Development Cycle

```sh
# Make changes to source code
# Run tests to ensure everything works
./build.sh tests

# Commit changes with conventional commit format
git commit -m "feat: add new feature"

# Push changes
git push origin main
```

### 4. Version Management

```sh
# Analyze changes since last release
./dev-bin/semantic-version-analyzer --verbose

# Create release if needed
# (Automatic via GitHub Actions or manual trigger)
```

## Build Configurations

### Available Build Modes

| Mode | CMake Option | Description | Compiler Flags |
|------|-------------|-------------|----------------|
| Default | None | Standard build | `-O2 -g` |
| Performance | `PERFORMANCE_BUILD=ON` | Optimized build | `-O3 -march=native -flto` |
| Debug | `DEBUG_MODE=ON` | Debug build | `-O0 -g -fsanitize=address,undefined` |
| Warnings | `WARNING_MODE=ON` | Extra warnings | `-Wall -Wextra -Wpedantic` |

### Build Matrix

The CI/CD pipeline tests all combinations:
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

## Code Quality

### Static Analysis
- **Clang-Tidy**: Static code analysis and style checking
- **CodeQL**: Security vulnerability scanning
- **ShellCheck**: Shell script validation

### Memory Safety
- **Memory Sanitizer**: Memory error detection in debug builds
- **Address Sanitizer**: Memory corruption detection
- **Undefined Behavior Sanitizer**: Undefined behavior detection

### Performance
- **Performance Benchmark**: Automated performance testing
- **LTO/IPO**: Link-time optimization for performance builds
- **Native Optimization**: Architecture-specific optimizations

## Troubleshooting

### Common Build Issues

1. **CMake version too old**: Update to CMake 3.16 or newer
2. **Compiler not C++20 compatible**: Update to GCC 10+ or Clang 10+
3. **Missing dependencies**: Install build essentials and CMake
4. **Permission issues**: Check file permissions and ownership

### Test Failures

1. **Unit test failures**: Check test output for specific error messages
2. **Workflow test failures**: Verify test environment and dependencies
3. **Memory sanitizer errors**: Address memory issues in debug builds
4. **Performance test failures**: Check system resources and optimization flags

### Version Issues

1. **Version not detected**: Ensure VERSION file exists and is readable
2. **Tag conflicts**: Use tag manager to clean up old tags
3. **Release not created**: Check if changes meet automatic release thresholds

## Getting Help

- **Documentation**: Check the `doc/` directory for comprehensive guides
- **Issues**: Open an issue on GitHub for bugs or feature requests
- **CI/CD**: Check GitHub Actions for build and test status
- **Version Analysis**: Use semantic version analyzer for change analysis

---

For more detailed information, see:
- [Test Suite Documentation](TEST_SUITE.md)
- [CI/CD Guide](CI_CD_GUIDE.md)
- [Versioning Guide](VERSIONING.md)
- [Build Guide](BUILD.md) 