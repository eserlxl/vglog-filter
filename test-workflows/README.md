# Test Workflows Organization

This directory contains organized test files and fixtures for the vglog-filter project.

## Directory Structure

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

## Usage

These test files are organized to support various testing scenarios:
- CLI option detection and parsing
- ERE pattern matching
- API breaking change detection
- Whitespace handling
- Debugging and manual verification

Each subdirectory focuses on a specific testing domain to maintain clear organization and facilitate test maintenance. 