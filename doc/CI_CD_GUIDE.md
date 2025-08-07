# CI/CD and Testing Guide

This guide provides comprehensive information about the Continuous Integration and Continuous Deployment (CI/CD) infrastructure for `vglog-filter`, including GitHub Actions workflows, testing procedures, and quality assurance processes. It aims to give developers a clear understanding of how code changes are validated and maintained.

## Table of Contents

- [Overview](#overview)
- [GitHub Actions Workflows](#github-actions-workflows)
  - [Core Testing Workflows](#core-testing-workflows)
  - [Quality Assurance Workflows](#quality-assurance-workflows)
  - [Performance and Compatibility Workflows](#performance-and-compatibility-workflows)
  - [Maintenance Workflows](#maintenance-workflows)
- [Build Configurations](#build-configurations)
- [Testing Procedures](#testing-procedures)
  - [Unit Testing](#unit-testing)
  - [Integration Testing](#integration-testing)
  - [Workflow Testing](#workflow-testing)
  - [Memory Safety Testing](#memory-safety-testing)
- [Quality Assurance](#quality-assurance)
- [Development Workflow](#development-workflow)
- [Local Development Setup](#local-development-setup)
- [Troubleshooting CI/CD Issues](#troubleshooting-cicd-issues)

## Overview

The `vglog-filter` project leverages a robust CI/CD pipeline built on GitHub Actions to ensure high code quality, reliability, and cross-platform compatibility. This automated pipeline is triggered by code pushes and pull requests, performing a series of checks including:

-   **Automated Builds**: Compiling the project across various configurations and operating systems.
-   **Extensive Testing**: Running unit, integration, and workflow tests to validate functionality.
-   **Static Analysis**: Identifying potential bugs, code style violations, and security vulnerabilities.
-   **Memory Safety Checks**: Detecting memory leaks and other memory-related errors.
-   **Performance Benchmarking**: Monitoring performance characteristics to prevent regressions.

This comprehensive approach helps maintain a stable and high-quality codebase, allowing for rapid and confident development.

[↑ Back to top](#ci/cd-and-testing-guide)

## GitHub Actions Workflows

All CI/CD workflows are defined in the `.github/workflows/` directory. Each workflow serves a specific purpose in ensuring the project's quality and stability.

### Core Testing Workflows

These workflows focus on building the project and running various levels of tests.

#### 1. Build and Test (`test.yml`)
-   **Purpose**: Performs basic build verification and runs a subset of functionality tests.
-   **Triggers**: Pushes to source files (`src/`), build configuration files (`CMakeLists.txt`, `build.sh`), or changes to the workflow itself.
-   **Matrix**: Tests 4 fundamental build configurations: default, performance-optimized, debug, and builds with extended warnings.
-   **Key Features**:
    -   Compiles the project with different optimization levels.
    -   Verifies basic application functionality and correct help output.
    -   Checks binary characteristics (e.g., presence of debug symbols).
    -   Executes tests with sample input data.
    -   Validates build artifacts and binary integrity.

#### 2. Comprehensive Test (`comprehensive-test.yml`)
-   **Purpose**: Executes the full test suite across a wide array of build configuration combinations.
-   **Triggers**: Pushes to the `main` branch or changes to the workflow file.
-   **Matrix**: Covers 12 distinct build configuration combinations, ensuring thorough testing.
-   **Key Features**:
    -   Tests nearly all possible combinations of build options (e.g., Debug + Warnings + Tests).
    -   Includes binary characteristic verification for each configuration.
    -   Runs the entire test suite when the build configuration includes testing.
    -   Validates both performance-optimized and debug builds.
    -   Ensures cross-platform compatibility across different Linux distributions.

#### 3. Debug Build Test (`debug-build-test.yml`)
-   **Purpose**: Specifically tests the integrity and usability of debug builds.
-   **Triggers**: Pushes to source files or changes to the workflow file.
-   **Key Features**:
    -   Verifies the presence and correctness of debug symbols.
    -   Includes basic GDB (GNU Debugger) integration testing.
    -   Validates debug section integrity within the compiled binary.
    -   Analyzes binary size to ensure debug symbols are correctly included.
    -   Tests debug-specific code paths and assertions.

[↑ Back to top](#ci/cd-and-testing-guide)

### Quality Assurance Workflows

These workflows focus on static analysis, memory safety, and security.

#### 4. Clang-Tidy (`clang-tidy.yml`)
-   **Purpose**: Performs static analysis using Clang-Tidy to enforce code style, detect potential bugs, and suggest performance improvements.
-   **Key Features**:
    -   Identifies common programming errors and anti-patterns.
    -   Validates adherence to coding standards and style guides.
    -   Suggests optimizations and modern C++ idioms.
    -   Enforces consistent code formatting and naming conventions.
    -   Detects potential undefined behavior and portability issues.

#### 5. Memory Sanitizer (`memory-sanitizer.yml`)
-   **Purpose**: Detects various memory errors at runtime using MemorySanitizer (MSan).
-   **Key Features**:
    -   Detects uses of uninitialized memory.
    -   Identifies memory leaks, use-after-free, and double-free errors.
    -   Helps prevent buffer overflows and other memory corruption issues.
    -   Validates proper memory management patterns.
    -   *Note: Requires Clang compiler and specific build configuration.*

#### 6. CodeQL (`codeql.yml`)
-   **Purpose**: Conducts deep security analysis to find vulnerabilities and enforce security best practices.
-   **Key Features**:
    -   Scans for common security vulnerabilities (e.g., injection flaws, cross-site scripting).
    -   Detects potential malicious code patterns.
    -   Ensures adherence to secure coding guidelines.
    -   Provides detailed security reports and recommendations.
    -   Integrates with GitHub Security features.

#### 7. ShellCheck (`shellcheck.yml`)
-   **Purpose**: Lints and validates shell scripts within the repository.
-   **Key Features**:
    -   Checks for syntax errors and common pitfalls in shell scripts.
    -   Enforces best practices for shell scripting.
    -   Identifies potential portability issues across different shell environments.
    -   Validates script security and proper quoting.
    -   Ensures consistent shell script formatting.

[↑ Back to top](#ci/cd-and-testing-guide)

### Performance and Compatibility Workflows

These workflows ensure the project performs well and is compatible across different environments.

#### 8. Performance Benchmark (`performance-benchmark.yml`)
-   **Purpose**: Measures and tracks the performance of `vglog-filter` to verify optimizations and prevent performance regressions.
-   **Triggers**: Pushes to `main`, pull requests, or a daily schedule.
-   **Key Features**:
    -   Runs automated performance benchmarks against various log sizes and patterns.
    -   Verifies the effectiveness of compiler optimizations.
    -   Profiles memory usage and analyzes binary size to ensure efficiency.
    -   Tracks performance metrics over time to detect regressions.
    -   Validates optimization flags and build configurations.

#### 9. Cross-Platform Test (`cross-platform.yml`)
-   **Purpose**: Ensures `vglog-filter` builds and runs correctly on multiple Linux distributions.
-   **Key Features**:
    -   Tests compatibility with Ubuntu (latest LTS).
    -   Verifies functionality on Arch Linux.
    -   Checks build and runtime on Fedora.
    -   Confirms compatibility with Debian.
    -   Validates package dependencies and system requirements.

[↑ Back to top](#ci/cd-and-testing-guide)

### Maintenance Workflows

These workflows automate routine maintenance tasks.

#### 10. Dependency Check (`dependency-check.yml`)
-   **Purpose**: Scans for security vulnerabilities in project dependencies (system packages and libraries).
-   **Triggers**: Weekly schedule or changes to dependency-related files.
-   **Key Features**:
    -   Identifies known vulnerabilities in system packages.
    -   Analyzes binary dependencies for security risks.
    -   Generates security audit reports.
    -   Monitors dependency updates and security advisories.
    -   Provides actionable recommendations for dependency updates.

#### 11. Tag Cleanup (`tag-cleanup.yml`)
-   **Purpose**: Automates the cleanup and maintenance of Git tags.
-   **Key Features**:
    -   Ensures proper organization of version tags.
    -   Manages release tags to keep the repository clean.
    -   Validates tag naming conventions.
    -   Removes obsolete or invalid tags.
    -   Maintains tag history and release tracking.

#### 12. Version Bump (`version-bump.yml`)
-   **Purpose**: Automates semantic versioning based on Conventional Commits.
-   **Key Features**:
    -   Automatically bumps the project's version number (major, minor, patch).
    -   Parses conventional commit messages to determine the appropriate version increment.
    -   Integrates with automated release management processes.
    -   Updates version files and generates release notes.
    -   Creates Git tags for releases.

[↑ Back to top](#ci/cd-and-testing-guide)

## Build Configurations

The CI/CD pipeline rigorously tests `vglog-filter` across various build configurations to ensure robustness and optimal performance under different scenarios. These configurations are primarily controlled via CMake build types and custom flags.

### Basic Configurations

-   **Default**: A standard build with `-O2` optimizations, suitable for general use.
-   **Performance**: Highly optimized build using `-O3` optimizations, Link Time Optimization (LTO), and native architecture tuning (`-march=native -mtune=native`). This configuration is designed for maximum runtime speed.
-   **Debug**: A build configured for debugging, including debug symbols (`-g`) and no optimizations (`-O0`). This is ideal for development and troubleshooting.
-   **Warnings**: A build that enables extensive compiler warnings (`-Wall -pedantic -Wextra`) to catch potential issues and enforce strict code quality.

### Combined Configurations

To ensure comprehensive coverage, the CI/CD pipeline also tests combinations of these basic configurations, such as:

-   `Performance + Warnings`
-   `Debug + Warnings`
-   `Tests` (a build specifically configured to run the test suite)
-   `Performance + Tests`
-   `Debug + Tests`
-   `Warnings + Tests`
-   `Performance + Warnings + Tests`
-   `Debug + Warnings + Tests`

### Configuration Details

Each configuration involves specific compiler flags and CMake definitions:

#### Performance Build Details
-   **Compiler Flags**: `-O3 -march=native -mtune=native`
-   **LTO**: Link Time Optimization is enabled for whole-program optimization.
-   **Defines**: `NDEBUG` is defined to disable assertions and debug-only code.
-   **Verification**: CI checks confirm the presence of `-O3` flags and LTO in the compiled binary.
-   **Optimizations**: Enables aggressive optimizations for maximum performance.

#### Debug Build Details
-   **Compiler Flags**: `-g -O0` (generate debug symbols, no optimization).
-   **Debug Symbols**: Verified to be present and correctly linked.
-   **Defines**: `DEBUG` is defined to enable debug-specific code paths.
-   **GDB Integration**: Tested to ensure the binary is debuggable with GDB.
-   **Assertions**: Debug assertions are enabled for runtime validation.

#### Warnings Build Details
-   **Compiler Flags**: `-Wall -pedantic -Wextra` (enables all common warnings, strict ISO C++ compliance, and extra warnings).
-   **Code Quality**: Aims to catch a wide range of potential issues and enforce high code quality standards.
-   **Best Practices**: Encourages adherence to C++ best practices through compiler warnings.
-   **Portability**: Ensures code compatibility across different compilers and platforms.

### Build Script Usage

The project uses a custom build script (`build.sh`) that provides a unified interface for all build configurations:

```sh
# Basic usage
./build.sh [performance] [warnings] [debug] [clean] [tests] [-j N] [--build-dir DIR]

# Examples
./build.sh                    # Default build
./build.sh performance        # Performance-optimized build
./build.sh debug              # Debug build
./build.sh warnings           # Build with extra warnings
./build.sh debug tests        # Debug build with tests
./build.sh performance warnings tests  # Performance build with warnings and tests
./build.sh clean debug        # Clean rebuild in debug mode
```

[↑ Back to top](#ci/cd-and-testing-guide)

## Testing Procedures

`vglog-filter` employs a multi-layered testing strategy, combining automated and manual testing to ensure reliability.

### Unit Testing

Unit tests are located in the `test/` directory and focus on testing individual components in isolation.

**Key Test Files:**
-   `test_basic.cpp`: Core functionality tests
-   `test_canonicalization.cpp`: Path canonicalization logic
-   `test_path_validation.cpp`: Path validation and security checks
-   `test_cli_options.cpp`: Command-line interface testing
-   `test_regex_patterns.cpp`: Regular expression pattern matching
-   `test_edge_cases.cpp`: Boundary conditions and edge cases
-   `test_edge_utf8_perm.cpp`: UTF-8 encoding and permission handling
-   `test_memory_leaks.cpp`: Memory leak detection and prevention
-   `test_comprehensive.cpp`: Comprehensive integration scenarios
-   `test_integration.cpp`: Component integration testing

**Running Unit Tests:**
```sh
# Run all unit tests
./test/run_unit_tests.sh

# Run tests with specific build configuration
./build.sh debug tests

# Run tests with verbose output
./test/run_unit_tests.sh --verbose

# Run specific test categories (if supported)
./test/run_unit_tests.sh --help
```

**Test Results:**
-   Test results are stored in `test_results/` directory
-   Detailed logs include build configuration, test execution, and failure details
-   Summary reports provide pass/fail statistics and coverage information

### Integration Testing

Integration tests verify that multiple components work together correctly.

**Key Features:**
-   Tests component interactions and data flow
-   Validates end-to-end functionality
-   Ensures proper error handling across components
-   Verifies performance characteristics under realistic conditions
-   Tests file system operations and path handling

### Workflow Testing

Workflow tests are located in the `test-workflows/` directory and test the complete development and deployment workflows.

**Test Categories:**
-   **Core Tests** (`core-tests/`): Fundamental workflow functionality, versioning, and semantic analysis
-   **CLI Tests** (`cli-tests/`): Command-line interface workflows and user interactions
-   **Debug Tests** (`debug-tests/`): Debugging and development workflows
-   **Edge Case Tests** (`edge-case-tests/`): Unusual scenarios and error conditions
-   **ERE Tests** (`ere-tests/`): Extended Regular Expression handling
-   **File Handling Tests** (`file-handling-tests/`): File system operations and content processing
-   **Utility Tests** (`utility-tests/`): Helper functions and utilities
-   **Fixture Tests** (`fixture-tests/`): Test data and sample files

**Running Workflow Tests:**
```sh
# Run all workflow tests
./test-workflows/run_workflow_tests.sh

# Run specific test categories
./test-workflows/run_workflow_tests.sh --help

# Run tests with specific configuration
./test-workflows/run_loc_delta_tests.sh

# Run comprehensive semantic version analyzer tests
./test-workflows/test_semantic_version_analyzer_comprehensive.sh
```

**Test Infrastructure:**
-   Uses `test_helper.sh` for common test utilities and setup
-   Includes source fixtures for realistic testing scenarios
-   Provides MSan suppressions for known false positives
-   Supports parallel test execution for faster feedback

### Memory Safety Testing

Memory safety is a critical concern for `vglog-filter`, and multiple testing approaches are employed:

**Memory Sanitizer (MSan):**
-   Detects uninitialized memory usage
-   Identifies memory leaks and use-after-free errors
-   Validates proper memory management patterns
-   Requires specific build configuration with Clang compiler

**Dedicated Memory Tests:**
-   `test_memory_leaks.cpp`: Comprehensive memory leak detection
-   `test-workflows/simple_msan_test.sh`: MSan integration testing
-   `test-workflows/test_msan_fix.sh`: MSan issue resolution testing
-   `test-workflows/test_msan_simulation.sh`: MSan simulation and validation

**MSan Suppressions:**
-   `test-workflows/msan_suppressions.txt`: Known false positives and intentional suppressions
-   `test-workflows/test-msan-fix.txt`: MSan fix validation and testing

**Running Memory Tests:**
```sh
# Run MSan tests (requires Clang)
./test-workflows/simple_msan_test.sh

# Run memory leak tests
./test/run_unit_tests.sh --memory

# Run MSan fix validation
./test-workflows/test_msan_fix.sh

# Run MSan simulation
./test-workflows/test_msan_simulation.sh
```

[↑ Back to top](#ci/cd-and-testing-guide)

### Automated Testing

Automated tests are integrated into the CI/CD pipeline and run on every code change.

1.  **Build Verification**: Confirms that all specified build configurations complete successfully without compilation errors.
2.  **Binary Validation**: Verifies critical characteristics of the compiled binaries, such as the presence of debug symbols or specific optimization flags.
3.  **Functionality Testing**: Executes a suite of tests to ensure the core features of `vglog-filter` work as expected with various inputs.
4.  **Test Suite Execution**: When a build configuration includes tests, the comprehensive test suite (unit, integration, workflow tests) is automatically run.
5.  **Cross-Platform Testing**: Ensures compatibility and correct behavior across different Linux distributions.

### Manual Testing

While automated tests cover most scenarios, manual testing can be performed locally for specific debugging or validation purposes.

```sh
# Example: Test all build configurations locally with warnings and tests enabled
./build.sh performance warnings tests
./build.sh debug warnings tests

# Example: Verify debug builds by attaching a debugger
./build.sh debug
gdb build/bin/vglog-filter # Then run your program within gdb

# Example: Test performance builds and verify optimizations
./build.sh performance
# Use tools like `objdump -d build/bin/vglog-filter | grep -i "-O3"` to verify optimizations

# Example: Run smoke tests
./test/smoke_test.sh

# Example: Run comprehensive workflow tests
./test-workflows/run_workflow_tests.sh

# Example: Test specific workflow components
./test-workflows/test-modular-components.sh
```

### Quality Checks

Beyond functional testing, several quality checks are integrated:

-   **Static Analysis**: Performed by Clang-Tidy and CodeQL to identify potential issues without running the code.
-   **Memory Safety**: Ensured through Memory Sanitizer, detecting runtime memory errors.
-   **Security**: Dependency vulnerability scanning helps identify known security risks in third-party components.
-   **Code Style**: ShellCheck and other linting tools enforce consistent code formatting and best practices.
-   **Performance**: Automated benchmarking and optimization verification ensure the tool remains efficient.

[↑ Back to top](#ci/cd-and-testing-guide)

## Quality Assurance

Quality Assurance (QA) for `vglog-filter` is an ongoing process, integrated throughout the development lifecycle.

### Code Quality
-   **Static Analysis**: Automated tools continuously analyze the codebase for potential issues, ensuring high code quality from the outset.
-   **Memory Safety**: Rigorous memory error detection helps prevent crashes and undefined behavior.
-   **Security**: Regular vulnerability scanning of both the codebase and its dependencies mitigates security risks.
-   **Style Consistency**: Automated linting and formatting tools enforce a consistent coding style, improving readability and maintainability.

### Performance
-   **Optimization Verification**: Performance-optimized builds are thoroughly tested to confirm that intended optimizations are effective.
-   **Benchmarking**: Automated benchmarks track performance metrics over time, allowing for early detection of regressions.
-   **Memory Usage**: Continuous monitoring and validation of memory efficiency ensure the tool remains lightweight, especially for large inputs.
-   **Binary Size**: Efforts are made to optimize binary size without compromising functionality or performance.

### Compatibility
-   **Cross-Platform**: Extensive testing across multiple Linux distributions guarantees broad compatibility.
-   **Architecture Optimization**: Builds are tested with native architecture optimizations to ensure peak performance on target systems.
-   **Dependency Management**: Careful management of system package dependencies ensures smooth operation across different environments.
-   **Portability**: Shell scripts and other components are designed and tested for maximum portability.

### Reliability
-   **Test Coverage**: A comprehensive test suite (unit, integration, workflow tests) aims for high test coverage, reducing the likelihood of undetected bugs.
-   **Error Handling**: Robust error handling mechanisms are implemented and tested to ensure graceful degradation and informative error messages.
-   **Edge Cases**: Specific tests are designed to cover boundary conditions and unusual inputs, improving the tool's resilience.
-   **Regression Testing**: Automated regression tests prevent the reintroduction of previously fixed bugs.

[↑ Back to top](#ci/cd-and-testing-guide)

## Development Workflow

This section outlines the typical development workflow, emphasizing how CI/CD integrates into daily tasks.

### Local Development
1.  **Setup**: Clone the repository and install all necessary build and runtime dependencies as described in the [Build Guide](BUILD.md).
2.  **Build**: Use `./build.sh` with appropriate options (e.g., `debug` for development) to compile your changes.
3.  **Test**: Run local tests frequently using `./run_tests.sh` or by specifying `tests` with `build.sh` (e.g., `./build.sh debug tests`).
4.  **Quality Checks**: Optionally run local static analysis tools (e.g., `clang-tidy`) before committing.
5.  **Commit**: Ensure your commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This is crucial for automated versioning.

### CI/CD Integration
1.  **Push Changes**: Push your local changes to a feature branch or open a pull request. This will automatically trigger the relevant GitHub Actions workflows.
2.  **Automated Testing**: All configured workflows will run, providing immediate feedback on your changes' impact on build status, tests, and quality metrics.
3.  **Review Workflow Results**: Monitor the GitHub Actions tab for your repository to review the results and logs of the triggered workflows.
4.  **Address Issues**: If any workflow fails, analyze the logs, fix the issues, and push new commits. The workflows will re-run automatically.
5.  **Merge**: Once all checks pass and the code review is complete, your changes can be merged into the `main` branch.

### Release Process

`vglog-filter` follows an automated release process:

1.  **Version Bump**: The `version-bump.yml` workflow automatically updates the project's version based on conventional commit messages in the `main` branch.
2.  **Tagging**: A new Git tag corresponding to the new version is automatically created.
3.  **Comprehensive Testing**: The `comprehensive-test.yml` workflow runs on the new tag to ensure the release candidate is stable.
4.  **Validation**: Additional quality and security checks are performed.
5.  **Release Creation**: An automated release is created on GitHub, often including release notes generated from commit messages.

### Monitoring
-   **Workflow Status**: Regularly check the status of all GitHub Actions workflows to ensure the pipeline is healthy.
-   **Performance Metrics**: Monitor performance benchmark results to track trends and identify any regressions.
-   **Security Alerts**: Pay attention to security scan results and address any reported vulnerabilities promptly.
-   **Quality Metrics**: Track code quality trends reported by static analysis tools.

[↑ Back to top](#ci/cd-and-testing-guide)

## Local Development Setup

Setting up a local development environment for `vglog-filter` involves several steps to ensure you can build, test, and contribute effectively.

### Prerequisites

**System Requirements:**
-   Linux distribution (Arch Linux, Ubuntu, Fedora, or Debian recommended)
-   GCC or Clang compiler (version 10 or later)
-   CMake (version 3.16 or later)
-   Git
-   Basic development tools (make, pkg-config, etc.)

**Arch Linux:**
```sh
sudo pacman -S base-devel cmake git
```

**Ubuntu/Debian:**
```sh
sudo apt update
sudo apt install build-essential cmake git
```

**Fedora:**
```sh
sudo dnf groupinstall "Development Tools"
sudo dnf install cmake git
```

### Repository Setup

```sh
# Clone the repository
git clone https://github.com/eserlxl/vglog-filter.git
cd vglog-filter

# Configure git user (if not already set)
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### Build Environment

**Basic Build:**
```sh
# Default build
./build.sh

# Debug build for development
./build.sh debug

# Performance build
./build.sh performance

# Build with warnings enabled
./build.sh warnings

# Build and run tests
./build.sh debug tests
```

**Build Options:**
-   `performance`: Enables `-O3` optimizations and LTO
-   `debug`: Enables debug symbols and `-O0` optimization
-   `warnings`: Enables extensive compiler warnings
-   `tests`: Builds and runs the test suite
-   `clean`: Removes build directory for clean rebuild
-   `-j N`: Sets parallel build jobs (default: auto-detected)

### Testing Setup

**Unit Tests:**
```sh
# Run all unit tests
./test/run_unit_tests.sh

# Run tests with specific build configuration
./build.sh debug tests

# Check test results
ls -la test_results/
```

**Workflow Tests:**
```sh
# Run all workflow tests
./test-workflows/run_workflow_tests.sh

# Run specific test categories
./test-workflows/run_loc_delta_tests.sh

# Run comprehensive tests
./test-workflows/test_semantic_version_analyzer_comprehensive.sh
```

**Memory Safety Testing:**
```sh
# Run MSan tests (requires Clang)
./test-workflows/simple_msan_test.sh

# Run memory leak tests
./test/run_unit_tests.sh --memory

# Run MSan fix validation
./test-workflows/test_msan_fix.sh
```

### Development Tools

**Static Analysis:**
```sh
# Run Clang-Tidy locally (if available)
clang-tidy src/*.cpp -- -Iinclude

# Run ShellCheck on scripts
shellcheck *.sh test/*.sh test-workflows/*.sh

# Check for code style issues
./build.sh warnings
```

**Debugging:**
```sh
# Build debug version
./build.sh debug

# Run with GDB
gdb build/bin/vglog-filter

# Run with Valgrind (if available)
valgrind --leak-check=full build/bin/vglog-filter

# Run with AddressSanitizer
./build.sh debug
ASAN_OPTIONS=detect_leaks=1 build/bin/vglog-filter
```

**Performance Analysis:**
```sh
# Build performance version
./build.sh performance

# Profile with perf (if available)
perf record build/bin/vglog-filter
perf report

# Check binary optimizations
objdump -d build/bin/vglog-filter | grep -i "-O3"
```

[↑ Back to top](#ci/cd-and-testing-guide)

## Troubleshooting CI/CD Issues

If you encounter issues with the CI/CD pipeline, here are some common troubleshooting steps:

### Common Issues
-   **Build Failures**: Often due to missing dependencies, incorrect compiler versions, or syntax errors. Check the build logs for specific error messages.
-   **Test Failures**: Could indicate a bug in your code, an issue with the test environment, or an incorrect test expectation. Reproduce locally if possible.
-   **Performance Issues**: If benchmarks show regressions, review recent code changes for inefficient algorithms or excessive resource usage. Check optimization flags.
-   **Security Issues**: Address reported vulnerabilities by updating dependencies or fixing insecure code patterns.

### Debugging Workflows
-   **Workflow Logs**: The most crucial step is to examine the detailed logs of the failing GitHub Actions workflow run. These logs provide step-by-step output and error messages.
-   **Local Reproduction**: Attempt to reproduce the issue locally using the exact commands from the CI workflow. This helps isolate environment differences.
-   **Environment Differences**: Be aware of potential differences between your local development environment and the CI environment (e.g., compiler versions, installed libraries).
-   **Dependency Issues**: Verify that all required dependencies are correctly installed and at the expected versions in the CI environment.

### Local Debugging

**Build Issues:**
```sh
# Clean build to avoid cached issues
./build.sh clean debug

# Check compiler version
gcc --version
clang --version

# Verify CMake configuration
cmake --version

# Check build configuration
./build.sh --help
```

**Test Issues:**
```sh
# Run tests with verbose output
./test/run_unit_tests.sh --verbose

# Run specific failing test
./test/run_unit_tests.sh --test-name "test_specific_function"

# Check test environment
./test/smoke_test.sh

# Run workflow tests individually
./test-workflows/run_workflow_tests.sh
```

**Memory Issues:**
```sh
# Run MSan tests locally
./test-workflows/simple_msan_test.sh

# Check for memory leaks
valgrind --leak-check=full build/bin/vglog-filter

# Run memory-specific tests
./test/run_unit_tests.sh --memory

# Run MSan fix validation
./test-workflows/test_msan_fix.sh
```

**Performance Issues:**
```sh
# Verify optimization flags
./build.sh performance
objdump -d build/bin/vglog-filter | grep -i "-O3"

# Run performance benchmarks
./build.sh performance tests

# Profile with perf
perf record build/bin/vglog-filter
perf report
```

### Seeking Support
-   **Documentation**: Always refer to the relevant documentation (e.g., [Build Guide](BUILD.md), [Developer Guide](DEVELOPER_GUIDE.md)) first.
-   **GitHub Issues**: If you identify a bug in the CI/CD setup or the project itself, please [open an issue](https://github.com/eserlxl/vglog-filter/issues) on the GitHub repository.
-   **GitHub Discussions**: For general questions, discussions, or seeking advice, utilize GitHub Discussions.
-   **Contributing Guidelines**: When contributing fixes or new features, ensure you follow the [Contributing Guidelines](.github/CONTRIBUTING.md).

[↑ Back to top](#ci/cd-and-testing-guide)