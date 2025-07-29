# Test Workflows Organization

This directory contains organized test files and fixtures for the vglog-filter project.

## Directory Structure

### `core-tests/`
Contains the main semantic version analyzer functionality tests:
- `test_semantic_version_analyzer.sh` - Comprehensive semantic version analyzer tests
- `test_semantic_version_analyzer_simple.sh` - Simple semantic version analyzer tests
- `test_semantic_version_analyzer_fixes.sh` - Tests for semantic version analyzer fixes
- `test_bump_version.sh` - Version bump detection and handling tests

### `file-handling-tests/`
Contains tests for file operations and handling:
- `test_nul_safety.sh` - NUL-safe file handling tests
- `test_whitespace_ignore.sh` - Whitespace handling and ignore functionality tests
- `test_header_removal.sh` - Header file prototype removal detection tests
- `test_rename_handling.sh` - File rename operation tests
- `test_breaking_case_detection.sh` - Breaking case detection in switch statements

### `edge-case-tests/`
Contains tests for edge cases and special scenarios:
- `test_ere_fix.sh` - Extended Regular Expression (ERE) edge case tests
- `test_env_normalization.sh` - Environment variable normalization tests
- `test_cli_detection_fix.sh` - CLI detection edge case fixes

### `utility-tests/`
Contains utility function and helper tests:
- `test_classify.sh` - File classification utility tests
- `test_classify_fixed.sh` - Fixed file classification tests
- `test_classify_inline.sh` - Inline file classification tests
- `test_classify_inline2.sh` - Additional inline classification tests
- `test_func.sh` - Function utility tests
- `test_func2.sh` - Additional function utility tests
- `test_case.sh` - Case handling utility tests
- `debug_test.sh` - Debug utility tests

### `cli-tests/`
Contains tests related to command-line interface functionality:
- `test_extract.sh` - Tests for CLI option extraction
- `test_fixes.sh` - Tests for CLI-related fixes and improvements
- `test_manual_cli_nested.c` - Sample C file with CLI options for testing

### `debug-tests/`
Contains debugging and manual testing scripts:
- `test_debug.sh` - Manual CLI detection testing script

### `ere-tests/`
Contains tests for Extended Regular Expression (ERE) functionality:
- `test_ere.c` - ERE test file with CLI options
- `test_ere_fix.c` - ERE test file with additional options

### `fixture-tests/`
Contains test fixtures and sample data:
- `test_whitespace.txt` - Whitespace-only test file

### `source-fixtures/`
Contains copies of source files used for testing:
- `internal/header.hh` - Internal header file for API testing
- `cli/main.c` - CLI main file for testing
- `cli/simple_cli_test.c` - Simple CLI test program with basic argument handling
- `test_content_simple.txt` - Simple test content file for basic file processing tests
- `test_content_renamed.txt` - Test content file for rename handling tests
- `debug_log_with_marker.txt` - Debug log content with markers for log filtering tests
- `file with space.cpp` - Test file with space in filename
- `test_header.h` - Test header file
- `test_whitespace.cpp` - Test file for whitespace handling

## Usage

These test files are organized to support various testing scenarios:
- Core semantic version analyzer functionality
- File handling and operations
- Edge cases and special scenarios
- Utility functions and helpers
- CLI option detection and parsing
- ERE pattern matching
- API breaking change detection
- Whitespace handling
- Debugging and manual verification

Each subdirectory focuses on a specific testing domain to maintain clear organization and facilitate test maintenance.

## Test Execution

Use the `run_all_tests.sh` script to execute all tests in the organized structure:

```bash
./test-workflows/run_all_tests.sh
```

This will run tests from all categories and provide a comprehensive summary of results. 