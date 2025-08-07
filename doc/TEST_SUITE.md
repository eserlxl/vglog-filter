# Test Suite Guide

This guide provides a comprehensive overview of the `vglog-filter` test suite, including its structure, how to run tests, and how to contribute new tests. A robust test suite is crucial for ensuring the reliability, correctness, and performance of the application.

## Table of Contents

- [Overview of the Test Suite](#overview-of-the-test-suite)
- [Running Tests](#running-tests)
  - [Running All Tests](#running-all-tests)
  - [Running C++ Unit Tests Only](#running-c-unit-tests-only)
  - [Running Workflow Tests Only](#running-workflow-tests-only)
  - [Running Individual Tests](#running-individual-tests)
  - [Building with Tests](#building-with-tests)
- [Test Suite Structure](#test-suite-structure)
  - [C++ Unit and Integration Tests (`test/`)](#c-unit-and-integration-tests-test)
  - [Workflow Tests (`test-workflows/`)](#workflow-tests-test-workflows)
  - [Test Fixtures (`test-workflows/fixture-tests/`, `test-workflows/source-fixtures/`)](#test-fixtures-test-workflowsfixture-tests-test-workflowssource-fixtures)
- [Writing New Tests](#writing-new-tests)
  - [Writing C++ Unit Tests](#writing-c-unit-tests)
  - [Writing Workflow Tests](#writing-workflow-tests)
- [Continuous Integration (CI) Testing](#continuous-integration-ci-testing)
- [Troubleshooting Test Failures](#troubleshooting-test-failures)

## Overview of the Test Suite

The `vglog-filter` project employs a multi-layered testing strategy to ensure high quality and stability. The test suite is designed to cover various aspects of the application, from low-level unit functionality to end-to-end behavior and performance.

Key characteristics of our test suite:
-   **Comprehensive Coverage**: Includes unit tests for individual components, integration tests for module interactions, and workflow tests for end-to-end scenarios.
-   **Automated Execution**: All tests are integrated into the CI/CD pipeline and run automatically on every code change.
-   **Cross-Platform**: Tests are executed across multiple Linux distributions to ensure broad compatibility.
-   **Performance and Memory Safety**: Dedicated tests and sanitizers (AddressSanitizer, MemorySanitizer) are used to monitor performance and detect memory-related issues.
-   **Readability and Maintainability**: Tests are structured to be easy to understand, write, and maintain.
-   **Advanced Versioning Tests**: Comprehensive testing of the LOC-based delta versioning system with rollover logic.
-   **Memory Safety Testing**: Dedicated MemorySanitizer tests and suppressions for detecting undefined behavior.

[↑ Back to top](#test-suite-guide)

## Running Tests

This section details how to execute the `vglog-filter` test suite locally.

### Running All Tests

The simplest way to run all C++ unit tests and shell-based workflow tests is using the main test runner script:

```bash
./run_tests.sh
```

This script will automatically build the project (if necessary) and then execute all tests. It also handles cleanup of temporary test files.

### Running C++ Unit Tests Only

If you only want to run the C++ unit and integration tests, use their dedicated runner script:

```bash
./test/run_unit_tests.sh
```

This script uses CMake and CTest to build and run all C++ tests with sanitizers enabled by default.

### Running Workflow Tests Only

To execute only the shell-based workflow tests, use their dedicated runner script:

```bash
./test-workflows/run_workflow_tests.sh
```

This script executes all workflow tests with timeout protection and detailed logging.

### Running Individual Tests

For focused debugging or development, you can run individual test executables or scripts:

-   **Individual C++ Test Executable**: After building the project, the C++ test executables are located in the `build-test/bin/` directory. You can run them directly:
    ```bash
    # Example: Run the basic C++ tests
    ./build-test/bin/test_basic

    # Example: Run the CLI options tests
    ./build-test/bin/test_cli_options

    # Example: Run canonicalization tests
    ./build-test/bin/test_canonicalization

    # Example: Run integration tests
    ./build-test/bin/test_integration

    # Example: Run comprehensive tests
    ./build-test/bin/test_comprehensive

    # Example: Run edge cases tests
    ./build-test/bin/test_edge_cases

    # Example: Run memory leak tests
    ./build-test/bin/test_memory_leaks

    # Example: Run path validation tests
    ./build-test/bin/test_path_validation

    # Example: Run regex pattern tests
    ./build-test/bin/test_regex_patterns

    # Example: Run UTF-8 permutation tests
    ./build-test/bin/test_edge_utf8_perm

    # Example: Run integration tests
    ./build-test/bin/test_integration

    # Example: Run comprehensive tests
    ./build-test/bin/test_comprehensive

    # Example: Run edge cases tests
    ./build-test/bin/test_edge_cases

    # Example: Run memory leak tests
    ./build-test/bin/test_memory_leaks

    # Example: Run path validation tests
    ./build-test/bin/test_path_validation

    # Example: Run regex pattern tests
    ./build-test/bin/test_regex_patterns

    # Example: Run UTF-8 permutation tests
    ./build-test/bin/test_edge_utf8_perm
    ```

-   **Individual Workflow Test Script**: Navigate to the `test-workflows/` directory and execute the specific shell script:
    ```bash
    # Example: Run a specific CLI test
    ./test-workflows/cli-tests/test_extract.sh

    # Example: Run a specific core test
    ./test-workflows/core-tests/test_bump_version.sh

    # Example: Run MemorySanitizer tests
    ./test-workflows/test_msan_fix.sh

    # Example: Run LOC delta system tests
    ./test-workflows/core-tests/test_loc_delta_system.sh

    # Example: Run semantic version analyzer tests
    ./test-workflows/core-tests/test_semantic_version_analyzer.sh

    # Example: Run LOC delta system tests
    ./test-workflows/core-tests/test_loc_delta_system.sh

    # Example: Run semantic version analyzer tests
    ./test-workflows/core-tests/test_semantic_version_analyzer.sh
    ```

### Building with Tests

The `build.sh` script provides a convenient way to build the project with specific configurations and then run the entire test suite. This is often the preferred method during development.

```bash
# Build in default (Release) mode and run all tests
./build.sh tests

# Build in Debug mode and run all tests
./build.sh tests debug

# Build with performance optimizations, extra warnings, and run all tests
./build.sh tests performance warnings
```

[↑ Back to top](#test-suite-guide)

## Test Suite Structure

The `vglog-filter` test suite is organized into distinct directories, each serving a specific purpose.

```
vglog-filter/
├── test/
│   ├── README.md
│   ├── run_unit_tests.sh
│   ├── smoke_test.sh
│   ├── test_basic.cpp
│   ├── test_canonicalization.cpp
│   ├── test_cli_options.cpp
│   ├── test_comprehensive.cpp
│   ├── test_edge_cases.cpp
│   ├── test_edge_utf8_perm.cpp
│   ├── test_helpers.h
│   ├── test_integration.cpp
│   ├── test_memory_leaks.cpp
│   ├── test_path_validation.cpp
│   └── test_regex_patterns.cpp
└── test-workflows/
    ├── README.md
    ├── run_workflow_tests.sh
    ├── run_loc_delta_tests.sh
    ├── test_helper.sh
    ├── test_semantic_version_analyzer_comprehensive.sh
    ├── test_msan_fix.sh
    ├── test_msan_simulation.sh
    ├── simple_msan_test.sh
    ├── test-modular-components.sh
    ├── msan_suppressions.txt
    ├── test-msan-fix.txt
    ├── cli-tests/
    │   ├── test_extract.sh
    │   └── test_fixes.sh
    ├── core-tests/
    │   ├── test_bump_version.sh
    │   ├── test_bump_version_loc_delta.sh
    │   ├── test_loc_delta_system.sh
    │   ├── test_loc_delta_system_comprehensive.sh
    │   ├── test_minimal_repo_test_mode.sh
    │   ├── test_pure_mathematical_bonus.sh
    │   ├── test_realistic_repositories.sh
    │   ├── test_rollover_logic.sh
    │   ├── test_semantic_analyzer_realistic_repos.sh
    │   ├── test_semantic_version_analyzer.sh
    │   ├── test_semantic_version_analyzer_fixes.sh
    │   ├── test_semantic_version_analyzer_simple.sh
    │   ├── test_version_calculation.sh
    │   ├── test_version_logic.sh
    │   ├── test_versioning_rules.sh
    │   └── test_versioning_system_integration.sh
    ├── debug-tests/
    │   └── test_debug.sh
    ├── edge-case-tests/
    │   ├── test_cli_detection_fix.sh
    │   ├── test_env_normalization.sh
    │   └── test_ere_fix.sh
    ├── ere-tests/
    │   ├── test_ere_fix.c
    │   └── test_ere.c
    ├── file-handling-tests/
    │   ├── test_breaking_case_detection.sh
    │   ├── test_header_removal.sh
    │   ├── test_nul_safety.sh
    │   ├── test_rename_handling.sh
    │   └── test_whitespace_ignore.sh
    ├── fixture-tests/
    │   └── test_whitespace.txt
    ├── source-fixtures/
    │   ├── cli/
    │   │   ├── main.c
    │   │   └── simple_cli_test.c
    │   ├── debug_log_with_marker.txt
    │   ├── internal/
    │   │   └── header.hh
    │   ├── test_content_renamed.txt
    │   ├── test_content_simple.txt
    │   └── test_header.h
    └── utility-tests/
        ├── debug_test.sh
        ├── test_case.sh
        ├── test_classify.sh
        ├── test_classify_consolidated.sh
        ├── test_classify_debug.sh
        ├── test_classify_fixed.sh
        ├── test_classify_inline.sh
        ├── test_classify_inline2.sh
        ├── test_classify_simple.sh
        ├── test_func.sh
        └── test_func2.sh
```
    ├── README.md
    ├── run_workflow_tests.sh
    ├── run_loc_delta_tests.sh
    ├── test_helper.sh
    ├── test_semantic_version_analyzer_comprehensive.sh
    ├── test_msan_fix.sh
    ├── test_msan_simulation.sh
    ├── simple_msan_test.sh
    ├── test-modular-components.sh
    ├── msan_suppressions.txt
    ├── test-msan-fix.txt
    ├── cli-tests/
    │   ├── test_extract.sh
    │   └── test_fixes.sh
    ├── core-tests/
    │   ├── test_bump_version.sh
    │   ├── test_bump_version_loc_delta.sh
    │   ├── test_loc_delta_system.sh
    │   ├── test_loc_delta_system_comprehensive.sh
    │   ├── test_minimal_repo_test_mode.sh
    │   ├── test_pure_mathematical_bonus.sh
    │   ├── test_realistic_repositories.sh
    │   ├── test_rollover_logic.sh
    │   ├── test_semantic_analyzer_realistic_repos.sh
    │   ├── test_semantic_version_analyzer.sh
    │   ├── test_semantic_version_analyzer_fixes.sh
    │   ├── test_semantic_version_analyzer_simple.sh
    │   ├── test_version_calculation.sh
    │   ├── test_version_logic.sh
    │   ├── test_versioning_rules.sh
    │   └── test_versioning_system_integration.sh
    ├── debug-tests/
    │   └── test_debug.sh
    ├── edge-case-tests/
    │   ├── test_cli_detection_fix.sh
    │   ├── test_env_normalization.sh
    │   └── test_ere_fix.sh
    ├── ere-tests/
    │   ├── test_ere.c
    │   └── test_ere_fix.c
    ├── file-handling-tests/
    │   ├── test_breaking_case_detection.sh
    │   ├── test_header_removal.sh
    │   ├── test_nul_safety.sh
    │   ├── test_rename_handling.sh
    │   └── test_whitespace_ignore.sh
    ├── fixture-tests/
    │   └── test_whitespace.txt
    ├── source-fixtures/
    │   ├── cli/
    │   │   ├── main.c
    │   │   └── simple_cli_test.c
    │   ├── debug_log_with_marker.txt
    │   ├── internal/
    │   │   └── header.hh
    │   ├── test_content_renamed.txt
    │   ├── test_content_simple.txt
    │   └── test_header.h
    └── utility-tests/
        ├── debug_test.sh
        ├── test_case.sh
        ├── test_classify.sh
        ├── test_classify_consolidated.sh
        ├── test_classify_debug.sh
        ├── test_classify_fixed.sh
        ├── test_classify_inline.sh
        ├── test_classify_inline2.sh
        ├── test_classify_simple.sh
        ├── test_func.sh
        └── test_func2.sh
```

### C++ Unit and Integration Tests (`test/`)

This directory contains C++ source files for unit and integration tests. These tests are compiled into separate executables and use a lightweight testing framework with custom assertion macros.

-   **`test_basic.cpp`**: Covers fundamental functionalities and core logic of `vglog-filter`.
-   **`test_canonicalization.cpp`**: Tests path canonicalization and normalization logic, ensuring proper handling of relative paths, symbolic links, and path resolution.
-   **`test_cli_options.cpp`**: Validates the parsing and correct behavior of all command-line arguments.
-   **`test_comprehensive.cpp`**: Provides extensive feature testing, covering various scenarios and combinations of inputs.
-   **`test_edge_cases.cpp`**: Focuses on boundary conditions, invalid inputs, and other tricky scenarios to ensure robustness.
-   **`test_edge_utf8_perm.cpp`**: Specifically tests edge cases related to UTF-8 character handling and permutations, including invalid UTF-8 sequences, control characters, and mixed line endings.
-   **`test_helpers.h`**: Contains common helper functions and macros used across multiple C++ test files, including assertion macros and temporary file utilities.
-   **`test_integration.cpp`**: Verifies the correct interaction and data flow between different modules and components of `vglog-filter`, including Valgrind log processing, deduplication logic, and marker trimming.
-   **`test_memory_leaks.cpp`**: Designed to detect memory leaks and other memory-related issues, often run with Valgrind or sanitizers.
-   **`test_path_validation.cpp`**: Ensures the security and correctness of file path handling and validation logic.
-   **`test_regex_patterns.cpp`**: Tests the accuracy and performance of regular expression matching and replacement operations.
-   **`smoke_test.sh`**: Quick smoke test script for basic functionality verification.
-   **`run_unit_tests.sh`**: Main script for building and running all C++ unit tests with CMake and CTest.

### Workflow Tests (`test-workflows/`)

This directory contains shell scripts that perform end-to-end testing of the `vglog-filter` executable and related utility scripts. These tests simulate real-world usage scenarios, often involving piping output, file I/O, and checking exit codes.

-   **`cli-tests/`**: Tests the command-line interface, including various option combinations and input/output redirection.
  - `test_extract.sh`: Tests log extraction functionality
  - `test_fixes.sh`: Tests bug fixes and improvements
-   **`core-tests/`**: Tests core functionalities and the behavior of utility scripts like version management and semantic analysis.
  - `test_bump_version.sh`: Tests version bumping functionality
  - `test_bump_version_loc_delta.sh`: Tests LOC-based delta versioning
  - `test_loc_delta_system.sh`: Tests the LOC delta system
  - `test_loc_delta_system_comprehensive.sh`: Comprehensive LOC delta testing
  - `test_minimal_repo_test_mode.sh`: Tests minimal repository scenarios
  - `test_pure_mathematical_bonus.sh`: Tests mathematical bonus calculations
  - `test_realistic_repositories.sh`: Tests with realistic repository data
  - `test_rollover_logic.sh`: Tests version rollover logic
  - `test_semantic_analyzer_realistic_repos.sh`: Tests semantic analysis with realistic data
  - `test_semantic_version_analyzer.sh`: Tests semantic version analysis
  - `test_semantic_version_analyzer_fixes.sh`: Tests semantic version analyzer fixes
  - `test_semantic_version_analyzer_simple.sh`: Simple semantic version analyzer tests
  - `test_version_calculation.sh`: Tests version calculation logic
  - `test_version_logic.sh`: Tests version logic and rules
  - `test_versioning_rules.sh`: Tests versioning rule implementation
  - `test_versioning_system_integration.sh`: Tests versioning system integration
-   **`debug-tests/`**: Scripts used for debugging and manual verification of debug builds.
  - `test_debug.sh`: Debug-specific tests
-   **`edge-case-tests/`**: Workflow-level tests for specific tricky scenarios that might not be fully covered by unit tests.
  - `test_cli_detection_fix.sh`: Tests CLI detection fixes
  - `test_env_normalization.sh`: Tests environment normalization
  - `test_ere_fix.sh`: Tests extended regular expression fixes
-   **`ere-tests/`**: Tests related to extended regular expression (ERE) functionality.
  - `test_ere.c`: Basic ERE tests
  - `test_ere_fix.c`: ERE fix tests
-   **`file-handling-tests/`**: Tests how `vglog-filter` interacts with files, including reading, writing, and handling different file properties.
  - `test_breaking_case_detection.sh`: Tests breaking case detection
  - `test_header_removal.sh`: Tests header removal functionality
  - `test_nul_safety.sh`: Tests null byte safety
  - `test_rename_handling.sh`: Tests file rename handling
  - `test_whitespace_ignore.sh`: Tests whitespace handling
-   **`utility-tests/`**: Tests various utility scripts and helper functions used within the project.
  - `debug_test.sh`: Debug utility tests
  - `test_case.sh`: Case testing utilities
  - `test_classify.sh`: Classification utility tests
  - `test_classify_consolidated.sh`: Consolidated classification tests
  - `test_classify_debug.sh`: Debug classification tests
  - `test_classify_fixed.sh`: Fixed classification tests
  - `test_classify_inline.sh`: Inline classification tests
  - `test_classify_inline2.sh`: Additional inline classification tests
  - `test_classify_simple.sh`: Simple classification tests
  - `test_func.sh`: Function testing utilities
  - `test_func2.sh`: Additional function testing utilities
-   **`test_semantic_version_analyzer_comprehensive.sh`**: Comprehensive testing of the semantic versioning system.
-   **`test_msan_fix.sh`**: MemorySanitizer-specific tests for detecting undefined behavior.
-   **`test_msan_simulation.sh`**: Simulates MemorySanitizer conditions for testing.
-   **`simple_msan_test.sh`**: Basic MemorySanitizer test setup and execution.
-   **`test-modular-components.sh`**: Tests for modular component architecture.
-   **`run_loc_delta_tests.sh`**: Tests for the LOC-based delta versioning system.
-   **`msan_suppressions.txt`**: MemorySanitizer suppressions for known false positives.

### Test Fixtures (`test-workflows/fixture-tests/`, `test-workflows/source-fixtures/`)

These directories contain sample input files, expected output files, and other data used by the workflow tests. They provide consistent and reproducible test environments.

-   **`fixture-tests/`**: Contains general test data, such as sample log files with specific patterns or expected filtered outputs.
  - `test_whitespace.txt`: Test data for whitespace handling
-   **`source-fixtures/`**: Contains sample source code files or snippets used to generate Valgrind logs for testing specific scenarios.
  - `cli/`: Command-line interface test fixtures
    - `main.c`: Main CLI test fixture
    - `simple_cli_test.c`: Simple CLI test fixture
  - `debug_log_with_marker.txt`: Debug log with marker test data
  - `internal/`: Internal component test fixtures
    - `header.hh`: Header file test fixture
  - `test_content_renamed.txt`: Renamed content test fixture
  - `test_content_simple.txt`: Simple content test fixture
  - `test_header.h`: Header file test fixture

[↑ Back to top](#test-suite-guide)

## Writing New Tests

Contributions of new tests are highly encouraged! When adding new features or fixing bugs, always consider writing corresponding tests to ensure correctness and prevent regressions.

### Writing C++ Unit Tests

1.  **Choose the Right File**: If your test relates to an existing module, add it to the corresponding `test_*.cpp` file. Otherwise, create a new `test_your_feature.cpp` file.
2.  **Include `test_helpers.h`**: This header provides common assertion macros and utility functions.
3.  **Structure Your Test**: Use the existing test patterns. Typically, tests are functions that perform operations and use assertion macros (e.g., `TEST_ASSERT`, `TEST_PASS`) to verify results.
    ```cpp
    #include "test_helpers.h"
    #include "path_to_your_module.h"

    // Example test function
    bool test_new_feature_scenario_1() {
        // Arrange: Set up test data
        std::string input = "...";
        std::string expected_output = "...";

        // Act: Call the function/module under test
        std::string actual_output = your_module::process(input);

        // Assert: Verify the results
        TEST_ASSERT(actual_output == expected_output, "Test scenario 1 failed");
        TEST_PASS("New feature scenario 1 works correctly");
        return true;
    }

    // Main test runner function
    int main() {
        bool all_passed = true;
        all_passed &= test_new_feature_scenario_1();
        // Add more test functions here
        
        return all_passed ? 0 : 1;
    }
    ```
4.  **Add to `CMakeLists.txt`**: Ensure your new `.cpp` file is added to the `add_test_exe` function calls in the main `CMakeLists.txt` so it gets compiled.
5.  **Run Locally**: Execute `./test/run_unit_tests.sh` to verify your new test passes.

### Writing Workflow Tests

1.  **Choose the Right Directory**: Place your new shell script in the most relevant subdirectory under `test-workflows/` (e.g., `cli-tests/` for CLI-related tests).
2.  **Use `test_helper.sh`**: This script provides common functions for setting up test environments, comparing files, and reporting results.
3.  **Structure Your Test**: Workflow tests typically involve:
    -   Setting up input files (often from `fixture-tests/` or `source-fixtures/`).
    -   Running `vglog-filter` with specific options.
    -   Comparing the actual output with expected output files.
    -   Checking exit codes.
    ```bash
    #!/bin/bash
    source "$(dirname "$0")"/../test_helper.sh

    # Define test name
    TEST_NAME="test_my_new_cli_feature"

    # Setup: Create input file
    echo "Valgrind log line 1" > input.log
    echo "Valgrind log line 2" >> input.log

    # Run vglog-filter
    ./build/bin/vglog-filter input.log > actual_output.log

    # Expected output
    echo "Expected line 1" > expected_output.log
    echo "Expected line 2" >> expected_output.log

    # Assert: Compare actual vs expected output
    assert_files_equal "actual_output.log" "expected_output.log"

    # Cleanup
    cleanup_test_files

    # Report result
    report_test_result
    ```
4.  **Run Locally**: Execute `./test-workflows/run_workflow_tests.sh` or the specific script directly to verify your new test.

[↑ Back to top](#test-suite-guide)

## Continuous Integration (CI) Testing

All tests are automatically executed as part of the project's comprehensive CI/CD pipeline on GitHub Actions. When you push code to a branch or open a pull request, the relevant workflows will run, providing immediate feedback on your changes.

Key CI workflows related to testing include:
-   **`test.yml`**: Basic build and test verification.
-   **`comprehensive-test.yml`**: Runs the full test suite across all build configurations.
-   **`debug-build-test.yml`**: Specifically validates debug builds and GDB integration.
-   **`memory-sanitizer.yml`**: Runs tests with MemorySanitizer enabled to detect memory errors.
-   **`cross-platform.yml`**: Ensures tests pass on various Linux distributions.
-   **`performance-benchmark.yml`**: Executes performance tests and tracks metrics.

Refer to the [CI/CD Guide](CI_CD_GUIDE.md) for a detailed explanation of all CI workflows.

[↑ Back to top](#test-suite-guide)

## Troubleshooting Test Failures

If your tests fail, follow these steps to diagnose and resolve the issue:

1.  **Examine Test Output**: The first step is always to carefully read the output of the failing test. It often provides specific error messages, assertion failures, or diffs that pinpoint the problem.

2.  **Reproduce Locally**: If a test fails in CI, try to reproduce the failure on your local machine. Use the exact build configuration (e.g., `debug`, `performance`) and test command that failed in CI.

    ```bash
    # Example: If 'test_cli_options' failed in debug mode
    ./build.sh debug
    ./build-debug/bin/test_cli_options
    ```

3.  **Use a Debugger**: For C++ test failures, attach a debugger (like GDB) to the failing test executable. Step through the code to understand its execution flow and variable states.

    ```bash
    gdb ./build-debug/bin/test_cli_options
    # (gdb) run
    # (gdb) break <function_name> or <file:line_number>
    ```

4.  **Inspect Test Fixtures**: For workflow tests, compare the `actual_output.log` with the `expected_output.log` (or similar files) to see the exact differences. Ensure your test fixtures are correct and up-to-date.

5.  **Check Environment Differences**: Be aware of potential differences between your local environment and the CI environment (e.g., compiler versions, installed libraries, shell versions). The CI logs provide details about the environment.

6.  **Clean Build**: Sometimes, stale build artifacts can cause issues. Perform a clean build and re-run tests:
    ```bash
    ./build.sh clean
    ./build.sh tests
    ```

7.  **MemorySanitizer Issues**: If MemorySanitizer tests fail, check the `msan_suppressions.txt` file and consider adding new suppressions for known false positives.

8.  **Consult Documentation**: Review the [Developer Guide](DEVELOPER_GUIDE.md) and [CI/CD Guide](CI_CD_GUIDE.md) for more context on build configurations and CI processes.

9.  **Open an Issue**: If you're unable to resolve the issue, please [open an issue](https://github.com/eserlxl/vglog-filter/issues) on GitHub, providing detailed information about the failure, steps to reproduce, and your environment.

[↑ Back to top](#test-suite-guide)