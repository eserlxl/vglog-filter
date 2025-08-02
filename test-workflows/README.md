# VGLOG-FILTER Test Workflows

This directory contains comprehensive test workflows for the vglog-filter project. The tests are organized by functionality and cover various aspects of the project including core functionality, file handling, edge cases, and utilities.

## Test Structure

### Core Tests (`core-tests/`)
Tests for the main functionality of the project:
- **`test_bump_version.sh`**: Tests version bumping functionality
- **`test_semantic_version_analyzer.sh`**: Comprehensive tests for semantic version analysis
- **`test_semantic_version_analyzer_fixes.sh`**: Tests for specific fixes and improvements
- **`test_semantic_version_analyzer_simple.sh`**: Basic functionality tests
- **`test_loc_delta_system.sh`**: Basic demonstration of LOC-based delta system
- **`test_loc_delta_system_comprehensive.sh`**: Comprehensive tests for LOC-based delta system
- **`test_bump_version_loc_delta.sh`**: Tests bump-version integration with LOC delta system

### File Handling Tests (`file-handling-tests/`)
Tests for file processing and handling:
- **`test_breaking_case_detection.sh`**: Tests detection of breaking changes
- **`test_header_removal.sh`**: Tests header file removal detection
- **`test_nul_safety.sh`**: Tests null byte safety in file processing
- **`test_rename_handling.sh`**: Tests file rename detection
- **`test_whitespace_ignore.sh`**: Tests whitespace change detection and ignoring

### Edge Case Tests (`edge-case-tests/`)
Tests for edge cases and error conditions:
- **`test_cli_detection_fix.sh`**: Tests CLI change detection fixes
- **`test_env_normalization.sh`**: Tests environment variable normalization
- **`test_ere_fix.sh`**: Tests ERE (Extended Regular Expression) fixes

### Utility Tests (`utility-tests/`)
Tests for utility functions:
- **`test_classify_consolidated.sh`**: Comprehensive path classification tests
- **`test_func.sh`**: Function testing utilities
- **`test_func2.sh`**: Additional function testing
- **`debug_test.sh`**: Debug functionality tests

### CLI Tests (`cli-tests/`)
Tests for command-line interface functionality:
- **`test_extract.sh`**: Tests CLI option extraction
- **`test_fixes.sh`**: Tests CLI-related fixes

### Debug Tests (`debug-tests/`)
Tests for debugging functionality:
- **`test_debug.sh`**: Manual CLI detection tests

### ERE Tests (`ere-tests/`)
Tests for Extended Regular Expression functionality:
- **`test_ere.c`**: Basic ERE functionality
- **`test_ere_fix.c`**: ERE fix testing

### LOC Delta System Tests
Tests for the LOC-based delta versioning system:
- **`test_loc_delta_system.sh`**: Basic demonstration and examples
- **`test_loc_delta_system_comprehensive.sh`**: Comprehensive test suite covering:
  - Basic LOC-based delta calculations
  - Breaking change bonuses
  - Feature addition bonuses
  - Security fix bonuses
  - Combined bonus scenarios
  - Configuration customization
  - Rollover scenarios
  - Edge cases
  - Verbose output
- **`test_bump_version_loc_delta.sh`**: Integration tests for bump-version script
- **`run_loc_delta_tests.sh`**: Dedicated test runner for LOC delta system

## Test Helper Functions

The `test_helper.sh` file provides common utilities for all tests:

### Environment Management
- `create_temp_test_env(test_name)`: Creates a temporary test environment
- `cleanup_temp_test_env(temp_dir)`: Cleans up temporary test environment
- `validate_test_env(temp_dir)`: Validates test environment setup

### File Operations
- `create_test_file(file_path, content)`: Creates test files with content
- `commit_test_files(message, ...files)`: Commits test files to git
- `generate_license_header(file_type, description)`: Generates license headers

### Git Operations
- `is_git_repo()`: Checks if current directory is a git repository
- `safe_git(...args)`: Safely runs git commands

### Test Utilities
- `log_test_result(test_name, status, message)`: Logs test results
- `print_test_summary()`: Prints test summary
- `run_test_in_temp_env(test_name, test_script)`: Runs tests in temporary environment

## Running Tests

### Run All Tests
```bash
bash test-workflows/run_workflow_tests.sh
```

### Run LOC Delta System Tests
```bash
# Run all LOC delta system tests
bash test-workflows/run_loc_delta_tests.sh

# Run specific LOC delta tests
bash test-workflows/core-tests/test_loc_delta_system.sh
bash test-workflows/core-tests/test_loc_delta_system_comprehensive.sh
bash test-workflows/core-tests/test_bump_version_loc_delta.sh
```

### Run Specific Test Categories
```bash
# Run only core tests
bash test-workflows/core-tests/test_semantic_version_analyzer.sh

# Run only file handling tests
bash test-workflows/file-handling-tests/test_whitespace_ignore.sh
```

### Test Configuration
The test runner supports the following environment variables:
- `TEST_TIMEOUT`: Timeout for individual tests (default: 30 seconds)
- `PROJECT_ROOT`: Path to project root (auto-detected if not set)

## Test Output

### Test Results
Tests produce output in the following format:
- **PASSED**: Test completed successfully
- **FAILED**: Test failed
- **SKIPPED**: Test was skipped (e.g., missing dependencies)
- **TIMEOUT**: Test exceeded timeout limit

### Output Files
- `test_results/summary.txt`: Summary of all test results
- `test_results/detailed.log`: Detailed log of all test executions
- `test_results/*.out`: Individual test output files

## Test Best Practices

### Writing New Tests
1. **Use the test helper functions**: Leverage the provided utilities for consistency
2. **Create temporary environments**: Use `create_temp_test_env()` for isolated testing
3. **Clean up resources**: Always call `cleanup_temp_test_env()` after tests
4. **Provide clear descriptions**: Include descriptive test names and messages
5. **Handle errors gracefully**: Use proper error handling and validation

### Test Structure
```bash
#!/bin/bash
set -Eeuo pipefail

# Source test helper
source "$SCRIPT_DIR/../test_helper.sh"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    # Test logic here
    if [[ condition ]]; then
        echo -e "\033[0;32m✓ Test passed\033[0m"
        ((TESTS_PASSED++))
    else
        echo -e "\033[0;31m✗ Test failed\033[0m"
        ((TESTS_FAILED++))
    fi
}

# Run tests
run_test "test_name"

# Print summary
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
exit $((TESTS_FAILED > 0 ? 1 : 0))
```

### Error Handling
- Use `set -Eeuo pipefail` for strict error handling
- Validate inputs and environment setup
- Provide meaningful error messages
- Clean up resources even on failure

## Troubleshooting

### Common Issues
1. **Permission denied**: Ensure test files are executable (`chmod +x test_file.sh`)
2. **Git not found**: Ensure git is installed and accessible
3. **Timeout errors**: Increase `TEST_TIMEOUT` for slow tests
4. **Missing dependencies**: Check that required tools (gcc, git) are installed

### Debug Mode
For debugging test issues:
```bash
# Run with verbose output
bash -x test-workflows/run_workflow_tests.sh

# Run individual test with debug
bash -x test-workflows/utility-tests/test_classify_consolidated.sh
```

## Contributing

When adding new tests:
1. Follow the existing naming conventions
2. Place tests in appropriate directories
3. Use the test helper functions
4. Add documentation for complex tests
5. Ensure tests are idempotent and isolated
6. Update this README if adding new test categories

## License

This test suite is part of vglog-filter and is licensed under the GNU General Public License v3.0 or later. 