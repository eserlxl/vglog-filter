# Developer Guide

This guide provides comprehensive information for developers contributing to `vglog-filter`. It covers essential topics such as build options, the automated versioning system, testing infrastructure, and recommended development workflows.

## Table of Contents

- [Build Options](#build-options)
  - [Using `build.sh`](#using-buildsh)
- [Versioning System](#versioning-system)
  - [Current Version Retrieval](#current-version-retrieval)
  - [Automated Version Bumping](#automated-version-bumping)
  - [Manual Version Management](#manual-version-management)
- [Testing & CI/CD](#testing--cicd)
  - [Test Suite Overview](#test-suite-overview)
  - [GitHub Actions Workflows](#github-actions-workflows)
  - [Local Testing](#local-testing)
  - [Development Tools](#development-tools)
- [Development Workflow](#development-workflow)
- [Code Quality and Best Practices](#code-quality-and-best-practices)
- [Troubleshooting for Developers](#troubleshooting-for-developers)

## Build Options

For detailed information on building, including prerequisites and cross-compilation, refer to the [Build Guide](BUILD.md).

### Using `build.sh`

The `build.sh` script simplifies the process of configuring and compiling `vglog-filter` with different options. It automates CMake commands and manages build directories.

-   **Default build (Release with `-O2`)**:
    ```sh
    ./build.sh
    ```
-   **Performance-optimized build**:
    ```sh
    ./build.sh performance
    ```
-   **Build with extra warnings**:
    ```sh
    ./build.sh warnings
    ```
-   **Debug build**:
    ```sh
    ./build.sh debug
    ```
-   **Clean build (removes all build artifacts)**:
    ```sh
    ./build.sh clean
    ```
-   **Combine options (e.g., debug + warnings)**:
    ```sh
    ./build.sh debug warnings
    ```
-   **Performance build with warnings and clean**:
    ```sh
    ./build.sh performance warnings clean
    ```
-   **Build and run all tests**:
    ```sh
    ./build.sh tests
    ```
-   **Build and run tests with warnings**:
    ```sh
    ./build.sh tests warnings
    ```
-   **Build and run tests in debug mode**:
    ```sh
    ./build.sh tests debug
    ```

**Note**: If both `debug` and `performance` options are provided, `debug` mode will take precedence. The `clean` and `tests` options can be combined with any other build configuration options.

[↑ Back to top](#developer-guide)

## Versioning System

`vglog-filter` uses an advanced LOC-based delta versioning system that always increases only the last identifier (patch) with calculated increments based on change magnitude. The system is configured through `dev-config/versioning.yml` and provides intelligent rollover logic. Version management is largely automated through GitHub Actions and the semantic version analyzer.

### Current Version Retrieval

The current version of `vglog-filter` is stored in the `VERSION` file at the project root. You can retrieve the version at runtime using the `--version` or `-V` command-line options:

```sh
vglog-filter --version
# or
vglog-filter -V
```

**Version Resolution Order**: The `vglog-filter` executable attempts to read its version from several locations, in order of preference:
1.  `./VERSION` (relative to the executable, for local development/testing).
2.  `../VERSION` (when run from within a `build/bin` directory).
3.  `/usr/share/vglog-filter/VERSION` (standard system-wide installation path).
4.  `/usr/local/share/vglog-filter/VERSION` (local user installation path).

If the `VERSION` file is not found or accessible in any of these locations, the version will be reported as "unknown".

### Automated Version Bumping

The project utilizes GitHub Actions to automatically bump the version based on the type of [Conventional Commits](https://www.conventionalcommits.org/) made to the `main` branch:

-   Commits with `BREAKING CHANGE` in the footer will trigger a **major** version bump (e.g., `1.2.3` -> `2.0.0`).
-   Commits of type `feat` (features) will trigger a **minor** version bump (e.g., `1.2.3` -> `1.3.0`).
-   Commits of type `fix` (bug fixes) will trigger a **patch** version bump (e.g., `1.2.3` -> `1.2.4`).
-   Other commit types (e.g., `docs`, `style`, `refactor`, `perf`, `test`, `chore`) will **not** trigger a version bump.

This automation ensures that the project's version accurately reflects the nature of changes introduced.

### Manual Version Management

While automated versioning is preferred, tools are available for manual inspection and management of versions and Git tags:

```sh
# Analyze recent changes and suggest the next semantic version bump
./dev-bin/semantic-version-analyzer --verbose

# Manually bump the version (e.g., to major, minor, or patch)
./dev-bin/bump-version [major|minor|patch]

# List existing Git tags
./dev-bin/tag-manager list

# Clean up old Git tags (e.g., keep only the last 'count' tags)
./dev-bin/tag-manager cleanup [count]
```

For a more in-depth understanding of the versioning strategy and release process, refer to the [Versioning Guide](VERSIONING.md) and [Release Workflow Guide](RELEASE_WORKFLOW.md).

[↑ Back to top](#developer-guide)

## Testing & CI/CD

`vglog-filter` boasts a robust testing and CI/CD infrastructure to ensure code quality, stability, and cross-platform compatibility. Developers are encouraged to leverage these tools throughout their development cycle.

### Test Suite Overview

The project's test suite is comprehensive, covering various aspects of the application's functionality and robustness.

#### C++ Unit and Integration Tests
Located in the `test/` directory, these tests are written in C++ and cover specific modules and their interactions:

-   **`test_basic.cpp`**: Fundamental functionality and core logic tests.
-   **`test_comprehensive.cpp`**: Extensive feature tests covering various scenarios.
-   **`test_edge_cases.cpp`**: Tests designed to probe boundary conditions and unusual inputs.
-   **`test_integration.cpp`**: Verifies the correct interaction between different components of the application.
-   **`test_memory_leaks.cpp`**: Specifically designed to detect memory leaks using Valgrind or other memory analysis tools.
-   **`test_path_validation.cpp`**: Focuses on security and correctness of path handling and validation logic.
-   **`test_regex_patterns.cpp`**: Tests the regular expression matching and replacement capabilities.
-   **`test_cli_options.cpp`**: Validates the parsing and behavior of command-line arguments.
-   **`test_edge_utf8_perm.cpp`**: Tests edge cases related to UTF-8 character permutations.

#### Workflow Tests
Located in the `test-workflows/` directory, these are shell scripts that test the end-to-end behavior of the `vglog-filter` executable and its integration with other tools.

-   **`cli-tests/`**: Tests related to the command-line interface, including input/output handling and option parsing.
-   **`core-tests/`**: Tests core functionalities and utilities, including versioning tools.
-   **`debug-tests/`**: Scripts for debugging and manual verification of debug builds.
-   **`edge-case-tests/`**: Workflow-level tests for specific tricky scenarios.
-   **`ere-tests/`**: Tests for extended regular expression (ERE) functionality.
-   **`file-handling-tests/`**: Tests related to how `vglog-filter` processes and interacts with files.
-   **`fixture-tests/`**: Contains test data and fixtures used by other tests.
-   **`source-fixtures/`**: Source code fixtures for testing various scenarios.
-   **`utility-tests/`**: Tests for various utility scripts and functions.

### GitHub Actions Workflows

The project utilizes 12 comprehensive GitHub Actions workflows to automate testing, quality checks, and release processes. These are detailed in the [CI/CD Guide](CI_CD_GUIDE.md).

### Local Testing

Developers are strongly encouraged to run tests locally before pushing changes. This helps catch issues early and reduces reliance on CI.

#### Quick Test Run

```sh
# Run all C++ unit tests and workflow tests
./run_tests.sh

# Run only C++ unit tests
./test/run_unit_tests.sh

# Run only workflow tests
./test-workflows/run_workflow_tests.sh
```

#### Individual Test Suites

To run specific C++ test executables or individual workflow test scripts:

```sh
# Run a specific C++ test executable (after building)
./build/bin/test_basic

# Run a specific workflow test script
./test-workflows/cli-tests/test_extract.sh
```

#### Build and Test Combinations

Use the `build.sh` script to build with specific configurations and then run tests:

```sh
# Build in default mode and run all tests
./build.sh tests

# Build in debug mode with warnings and run all tests
./build.sh tests debug warnings
```

[↑ Back to top](#developer-guide)

### Development Tools

Several utility scripts and tools are provided in the `dev-bin/` directory to assist with development tasks.

#### Version Management Tools
-   **`semantic-version-analyzer`**: Analyzes Git history and commit messages to suggest the next appropriate semantic version bump.
-   **`bump-version`**: A script to manually increment the project's version (major, minor, or patch) and update the `VERSION` file.
-   **`tag-manager`**: Helps manage Git tags, including listing and cleaning up old tags.
-   **`cursor-version-bump`**: A utility specifically for integration with the Cursor IDE for version bumping.

#### Testing Tools
-   **`run_tests.sh`**: The primary script to execute all C++ unit tests and workflow tests.
-   **`run_unit_tests.sh`**: Executes only the C++ unit tests.
-   **`run_workflow_tests.sh`**: Executes only the shell-based workflow tests.

#### Build Tools
-   **`build.sh`**: The main script for building the project with various configurations.
-   **`CMakeLists.txt`**: The CMake build configuration file, defining how the project is built, its dependencies, and various build options.

[↑ Back to top](#developer-guide)

## Development Workflow

This section outlines a typical development workflow for contributing to `vglog-filter`.

### 1. Setup Your Development Environment

Start by cloning the repository and installing the necessary build dependencies as described in the [Build Guide](BUILD.md).

### 2. Build and Test Locally

Before making changes, ensure you can build the project and run its tests successfully:

```sh
# Build the project in debug mode and run all tests
./build.sh debug tests

# Alternatively, for a performance-optimized build with warnings
./build.sh performance warnings
```

### 3. Implement Changes and Iterate

As you develop, follow an iterative cycle of coding, building, and testing:

```sh
# Make your code changes in the src/ directory or other relevant files

# Rebuild and run tests frequently to catch issues early
./build.sh tests # Or ./build.sh debug tests for debugging

# If you're working on a specific test, run it individually
./build/bin/test_your_new_feature # For C++ tests
./test-workflows/your-new-workflow-test.sh # For workflow tests
```

### 4. Commit Your Changes

When committing, ensure your commit messages adhere to the [Conventional Commits](https://www.conventionalcommits.org/) specification. This is critical for the automated versioning and release process.

```sh
git add .
git commit -m "feat: add new feature for X functionality"
# Example: "fix(cli): resolve issue with -s option parsing"
```

### 5. Push and Monitor CI/CD

Push your changes to your feature branch or directly to `main` (if appropriate for small fixes). Monitor the GitHub Actions workflows for feedback.

```sh
git push origin your-feature-branch
# Then check the GitHub Actions tab in your repository
```

### 6. Version Management (Automated)

For changes merged into `main`, the version will be automatically bumped by the CI/CD pipeline based on your commit messages. You typically do not need to manually manage the `VERSION` file or create tags.

[↑ Back to top](#developer-guide)

## Code Quality and Best Practices

Maintaining high code quality is paramount for `vglog-filter`. Adhere to the following best practices:

-   **Readability**: Write clear, concise, and well-structured code. Use meaningful variable and function names.
-   **Modularity**: Design components to be modular and loosely coupled, promoting reusability and easier maintenance.
-   **Error Handling**: Implement robust error handling for all potential failure points, providing informative error messages.
-   **Performance**: Be mindful of performance, especially in critical paths. Leverage C++20 features and standard library algorithms where appropriate.
-   **Security**: Write secure code, paying attention to potential vulnerabilities like buffer overflows, uninitialized memory access, and path traversal issues. The sanitizers and CodeQL workflows are there to help.
-   **Consistency**: Follow existing coding style and conventions within the project. Automated tools like Clang-Tidy and ShellCheck help enforce this.
-   **Documentation**: Add comments to explain complex logic or non-obvious design choices. Update relevant documentation files (like this guide) when introducing new features or changing existing behavior.

[↑ Back to top](#developer-guide)

## Troubleshooting for Developers

If you encounter issues during development, here are some common problems and troubleshooting tips:

### Common Build Issues

1.  **CMake version too old**: Ensure you are using CMake 3.16 or newer. Update if necessary.
2.  **Compiler not C++20 compatible**: Verify your compiler (GCC 10+ or Clang 12+) supports C++20. Update your compiler if it's outdated.
3.  **Missing dependencies**: Ensure all build essentials (e.g., `build-essential` on Debian/Ubuntu) and CMake are installed.
4.  **Permission issues**: Check file permissions and ownership in your project directory, especially after cloning or extracting.

### Common Test Failures

1.  **Unit test failures**: Examine the test output for specific assertion failures or error messages. Run the failing test individually for focused debugging.
2.  **Workflow test failures**: These often indicate issues with script logic, environment variables, or unexpected program output. Reproduce the workflow test locally step-by-step.
3.  **Memory sanitizer errors**: If you're running a sanitized build, these indicate memory-related bugs (e.g., use-after-free, uninitialized reads). Use a debugger (like GDB) to pinpoint the exact location.
4.  **Performance test failures**: Could be due to a performance regression in your code, or an unstable test environment. Check system resources and ensure optimization flags are correctly applied.

### Versioning Issues

1.  **Version not detected**: Ensure the `VERSION` file exists in the expected locations and is readable by the `vglog-filter` executable.
2.  **Tag conflicts**: If you're manually managing tags, use `tag-manager cleanup` to remove old or conflicting tags.
3.  **Automated release not created**: Verify that your commit messages adhere to Conventional Commits and that the changes warrant a version bump (e.g., `feat:` or `fix:`).

### Getting Help

-   **Project Documentation**: Always consult the `doc/` directory for comprehensive guides (e.g., [Test Suite Documentation](TEST_SUITE.md), [CI/CD Guide](CI_CD_GUIDE.md), [Versioning Guide](VERSIONING.md), [Build Guide](BUILD.md)).
-   **GitHub Issues**: If you encounter a bug or have a feature request, please [open an issue](https://github.com/eserlxl/vglog-filter/issues) on the GitHub repository.
-   **GitHub Discussions**: For general questions, architectural discussions, or seeking advice, consider using GitHub Discussions.
-   **Contributing Guidelines**: Ensure you review and follow the [Contributing Guidelines](.github/CONTRIBUTING.md) before submitting pull requests.

[↑ Back to top](#developer-guide)
