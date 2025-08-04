# Frequently Asked Questions (FAQ)

This document provides answers to common questions about `vglog-filter`, covering its functionality, usage, build process, and development aspects.

## Table of Contents

- [General Information](#general-information)
- [Usage and Options](#usage-and-options)
- [Performance and Monitoring](#performance-and-monitoring)
- [Building and Testing](#building-and-testing)
- [Versioning and Releases](#versioning-and-releases)
- [Contributing and Support](#contributing-and-support)
- [Troubleshooting](#troubleshooting)

## General Information

### What is `vglog-filter`?
`vglog-filter` is a fast and flexible command-line tool designed to process and clean up Valgrind log files. Its primary purpose is to help developers analyze Valgrind output more efficiently by removing redundant information, deduplicating stack traces, and normalizing dynamic data (like memory addresses) for easier comparison. Currently at version 10.5.0, it features advanced LOC-based versioning and comprehensive testing.

### Why should I use `vglog-filter`?
Valgrind logs can be very verbose, especially in large projects or during automated testing. `vglog-filter` addresses common pain points:
-   **Redundancy**: Eliminates repeated error messages and stack traces.
-   **Noise**: Filters out irrelevant warnings and informational messages.
-   **Non-Determinism**: Normalizes dynamic data, making logs consistent across different runs, which is crucial for `diff`-based analysis and CI/CD integration.

### What is the default marker and why is it used?
The default marker is the string `Successfully downloaded debug`. By default, `vglog-filter` processes only the log entries that appear *after* the last occurrence of this marker. This behavior is useful for focusing on the most recent Valgrind run in a concatenated log file, ignoring previous runs or setup information.

### Can `vglog-filter` be used with logs from tools other than Valgrind?
`vglog-filter` is specifically designed and optimized for Valgrind log formats. While it might process other similar text-based log formats to some extent, its filtering and deduplication logic is tailored to Valgrind's output patterns. For optimal results, it's recommended for Valgrind logs.

### What are the system requirements for running `vglog-filter`?
-   **Operating System**: Linux and other POSIX-compliant systems (primarily tested on Linux)
-   **Dependencies**: No external runtime dependencies - it's a statically linked binary
-   **Memory**: Minimal memory footprint, with automatic stream processing for large files
-   **Disk Space**: Only requires space for the executable (~1-2MB)

[↑ Back to top](#frequently-asked-questions-faq)

## Usage and Options

### How do I process an entire log file without considering the marker?
Use the `-k` or `--keep-debug-info` option. This tells `vglog-filter` to process the entire input log from start to finish, ignoring the presence of the default or custom marker.

```sh
vglog-filter --keep-debug-info your_full_log.log > filtered_output.log
```

### What does the depth option (`-d N`) do?
The `-d N` or `--depth N` option controls how many lines are used to generate the unique signature for each Valgrind error block during deduplication. A higher `N` means more context lines are considered, leading to more precise (but potentially fewer) deduplications. A value of `0` signifies unlimited depth, meaning the entire error block is used for the signature.

```sh
# Deduplicate considering only the first 5 lines of each error block
vglog-filter --depth 5 raw.log > filtered.log

# Deduplicate considering the entire error block
vglog-filter --depth 0 raw.log > filtered.log
```

### How can I see the raw, unscrubbed log blocks?
Use the `-v` or `--verbose` option. This disables the scrubbing of non-deterministic elements like memory addresses and `at:` line numbers, allowing you to see the Valgrind output exactly as it was generated.

```sh
vglog-filter --verbose raw.log > unscrubbed.log
```

### What if my log uses a different marker string?
If your Valgrind logs use a different marker string to delineate relevant sections, you can specify it using the `-m S` or `--marker S` option, where `S` is your custom marker string.

```sh
vglog-filter --marker "--- START OF TEST RUN ---" my_custom_log.log
```

### What happens if the input file cannot be opened or is empty?
-   **Cannot be opened**: If `vglog-filter` cannot open the specified input file (e.g., due to incorrect path, permissions, or non-existence), it will print a descriptive error message with helpful suggestions (e.g., checking file existence and permissions) and exit with a non-zero status code.
-   **Empty file**: If the input file is empty, the tool will display a warning message (e.g., "Warning: Input file is empty.") and exit successfully (status 0) without processing anything.

### What if I provide an invalid depth value?
If you provide a non-numeric, negative value, or a value greater than 1000 for the depth option (`-d`), `vglog-filter` will display a clear error message indicating the invalid value and the expected format (a non-negative integer between 0 and 1000).

### Can I process input from stdin?
Yes! `vglog-filter` can read from stdin in several ways:

```sh
# Process from stdin (implicit)
cat valgrind.log | ./vglog-filter

# Process from stdin (explicit)
./vglog-filter - < valgrind.log

# Direct pipe from Valgrind
valgrind ./your_program 2>&1 | ./vglog-filter
```

### What are some common usage patterns?
Here are some typical usage scenarios:

```sh
# Basic file processing
./vglog-filter valgrind.log > filtered.log

# Process with custom marker and depth
./vglog-filter --marker "TEST START" --depth 10 valgrind.log

# Process large file with progress monitoring
./vglog-filter --progress --memory large_valgrind.log

# Force stream processing for consistent behavior
./vglog-filter --stream small_log.log

# Combine multiple options for comprehensive processing
./vglog-filter --keep-debug-info --verbose --progress valgrind.log
```

[↑ Back to top](#frequently-asked-questions-faq)

## Performance and Monitoring

### How does `vglog-filter` handle large files?
`vglog-filter` is designed for efficiency. It automatically detects input files larger than 5MB and switches to a memory-efficient stream processing mode. This prevents Out-Of-Memory (OOM) errors and ensures smooth processing of very large Valgrind logs. You will see an informational message like "Info: Large file detected, using stream processing mode" when this occurs.

### Can I force stream processing mode for any file size?
Yes, you can force `vglog-filter` to use stream processing mode regardless of the input file size by using the `-s` or `--stream` option. This can be useful for consistent behavior in automated scripts or when dealing with continuous input streams.

```sh
vglog-filter --stream small_log.log > filtered.log
```

### How can I monitor progress when processing large files?
Use the `-p` or `--progress` option. When enabled, `vglog-filter` will display real-time progress updates, showing the percentage completion and the number of lines processed. Updates are typically shown every 1000 lines.

```sh
vglog-filter --progress very_large_valgrind.log > filtered.log
```

### How can I monitor memory usage during processing?
Use the `-M` or `--monitor-memory` option. This will enable tracking and reporting of peak memory usage at different stages of the processing (e.g., during file reading, processing, and deduplication phases). This is invaluable for performance analysis and debugging memory-related issues.

```sh
vglog-filter --monitor-memory valgrind.log > filtered.log
```

### Can I combine progress and memory monitoring?
Absolutely! You can use both the `--progress` and `--monitor-memory` options simultaneously for comprehensive real-time monitoring of large file processing.

```sh
vglog-filter --progress --monitor-memory extremely_large_valgrind.log > filtered.log
```

### What performance optimizations have been implemented?
`vglog-filter` incorporates several modern C++ and algorithmic optimizations:
-   **`std::string_view`**: Extensively used for string operations to avoid unnecessary memory allocations and copies.
-   **Optimized Regex Patterns**: Regular expression matching is optimized with appropriate flags (e.g., ECMAScript) for faster pattern recognition.
-   **Efficient File Size Checking**: Uses `stat()` for quick and efficient detection of large files.
-   **`std::span`**: Utilized for memory-efficient handling of array-like data structures.
-   **Stream Processing**: Automatic and forced stream processing modes ensure efficient memory usage for large inputs.
-   **Memory Monitoring**: Built-in memory usage tracking helps identify and address performance bottlenecks.

### What's the typical performance I can expect?
Performance depends on file size and complexity:
-   **Small files (< 1MB)**: Typically processed in milliseconds
-   **Medium files (1-50MB)**: Usually processed in seconds
-   **Large files (50MB+)**: May take several minutes, but with progress monitoring
-   **Memory usage**: Generally stays under 100MB even for very large files due to stream processing

[↑ Back to top](#frequently-asked-questions-faq)

## Building and Testing

### How do I install `vglog-filter`?
Currently, `vglog-filter` is primarily distributed as source code. You need to build it from source. The general steps are:

1.  **Clone the repository:** `git clone https://github.com/eserlxl/vglog-filter.git && cd vglog-filter`
2.  **Build the project:** `./build.sh` (for a default release build) or `./build.sh performance` (for an optimized build).
3.  **Install (optional):** Manually copy the executable: `sudo cp build/bin/vglog-filter /usr/local/bin/` (or another directory in your PATH).

For detailed prerequisites and build instructions, refer to the [Build Guide](BUILD.md).

### What are the system requirements to build and run `vglog-filter`?
-   **Operating System**: Linux or other POSIX-compliant systems are primarily supported and tested.
-   **Compiler**: A C++20 compatible compiler (GCC 10+ or Clang 12+).
-   **Build System**: CMake 3.16 or newer.
-   **Standard Build Tools**: `make` or `ninja` (typically included with `build-essential` on Debian/Ubuntu or `base-devel` on Arch Linux).

### How do I run tests for `vglog-filter`?
The project has a comprehensive test suite. You can run all tests using the main build script:

```sh
./build.sh tests
```

This command will build the project (if necessary) and then execute all C++ unit tests and shell-based workflow tests. You can combine `tests` with other build options:

```sh
# Build in debug mode and run tests
./build.sh tests debug

# Build with performance optimizations and warnings, then run tests
./build.sh tests performance warnings
```

For more specific testing, you can run individual test suites:
-   C++ unit tests only: `./test/run_unit_tests.sh`
-   Workflow tests only: `./test-workflows/run_workflow_tests.sh`

Refer to the [Test Suite Guide](TEST_SUITE.md) for an in-depth overview of the testing framework.

### What build configurations are available?
`vglog-filter` supports several build configurations, each tailored for different needs:
-   **Default**: Standard build with `-O2` optimizations.
-   **Performance**: Highly optimized with `-O3`, LTO, and native architecture tuning.
-   **Debug**: Includes debug symbols (`-g`) and no optimizations (`-O0`), ideal for debugging.
-   **Warnings**: Enables extensive compiler warnings (`-Wall -pedantic -Wextra`) for strict code quality.
-   **Tests**: A special configuration that builds and then runs the entire test suite.

These can be combined (e.g., `performance warnings tests`). The [Build Guide](BUILD.md) provides full details.

### How is the project tested in CI/CD?
The project utilizes a comprehensive set of 12 GitHub Actions workflows to ensure continuous quality. These workflows cover:
-   **Extensive Build Matrix**: Testing all 12 possible combinations of build configurations.
-   **Cross-Platform Compatibility**: Verifying functionality on multiple Linux distributions (Ubuntu, Arch Linux, Fedora, Debian).
-   **Debug Build Validation**: Ensuring debug builds are correctly configured and debuggable with GDB.
-   **Performance Verification**: Benchmarking and confirming the effectiveness of optimizations and LTO.
-   **Memory Safety**: Running tests with Memory Sanitizer to detect runtime memory errors.
-   **Static Analysis**: Using Clang-Tidy for code quality and style checks.
-   **Security Analysis**: Employing CodeQL for deep security vulnerability detection.
-   **Script Validation**: Linting shell scripts with ShellCheck.

For a complete overview, see the [CI/CD Guide](CI_CD_GUIDE.md).

[↑ Back to top](#frequently-asked-questions-faq)

## Versioning and Releases

### What version is currently available?
The current stable version of `vglog-filter` is **10.5.0**. You can check the exact version by running `vglog-filter --version`.

### How does the versioning system work?
`vglog-filter` follows [Semantic Versioning (SemVer)](https://semver.org/) with an advanced LOC-based delta system. Version bumps are automated based on [Conventional Commits](https://www.conventionalcommits.org/) and the magnitude of code changes:

-   **MAJOR**: Triggered by `BREAKING CHANGE` in commit footers, API changes, or large-scale changes with high bonus values.
-   **MINOR**: Triggered by `feat:` (new features), CLI additions, or medium-scale changes.
-   **PATCH**: Triggered by `fix:` (bug fixes) or any other changes that don't qualify for major/minor.

**Key Features of the LOC-Based Delta System**:
- Always increases only the patch version (the last number)
- Calculates increment amount based on Lines of Code (LOC) changed plus bonus additions
- Uses intelligent rollover logic (mod 100) for patch and minor versions
- Every change results in at least a patch bump

**Example**: A 500 LOC change with CLI additions might result in `10.5.0` → `10.5.6` (patch bump with calculated delta).

For more details, see the [Versioning Guide](VERSIONING.md) and [LOC Delta System Documentation](LOC_DELTA_SYSTEM.md).

### How are releases created?
Releases are primarily automated through GitHub Actions:

1. **Automatic Releases**: Push changes to `main` branch → GitHub Actions workflow analyzes changes → automatically creates release if warranted
2. **Manual Releases**: Use GitHub Actions interface to manually trigger releases with specific parameters
3. **Prereleases**: Create beta/alpha releases for major changes (e.g., `v11.0.0-beta.1`)

The system uses the `semantic-version-analyzer` tool to determine appropriate version bumps based on:
- Conventional commit messages
- Lines of code changed
- Type of changes (breaking, features, fixes)
- Bonus calculations for specific impact types

For detailed release workflow information, see the [Release Workflow Guide](RELEASE_WORKFLOW.md).

### How do I check what changes are in a release?
You can examine release changes in several ways:

```bash
# Check the current version
vglog-filter --version

# List recent tags
git tag --sort=-version:refname | head -5

# Compare two versions
git diff v10.4.0..v10.5.0 --stat

# Analyze changes since a specific version
./dev-bin/semantic-version-analyzer --since v10.4.0 --verbose
```

GitHub Releases also provide automatically generated release notes with detailed change information.

### What's the difference between the old and new versioning system?
The project has evolved from traditional semantic versioning to an advanced LOC-based delta system:

**Traditional System**:
- Fixed increments (1.0.0 → 1.0.1 → 1.1.0)
- Restrictive thresholds that could miss meaningful changes
- Version number inflation over time

**Current LOC-Based Delta System**:
- Always increases only the patch version with calculated deltas
- Universal patch detection (every change gets a bump)
- Proportional versioning based on change magnitude
- Intelligent rollover logic (mod 100)
- Enhanced configuration through YAML files

This system prevents version number inflation while maintaining semantic meaning and ensuring no meaningful changes are missed.

[↑ Back to top](#frequently-asked-questions-faq)

## Contributing and Support

### How do I contribute to the project?
We welcome contributions! To contribute to `vglog-filter`, please follow these guidelines:
1.  **Conventional Commits**: Ensure your commit messages adhere to the [Conventional Commits](https://www.conventionalcommits.org/) specification.
2.  **Local Testing**: Run the full test suite locally (`./build.sh tests`) before submitting your changes.
3.  **CI/CD Checks**: Verify that all GitHub Actions CI/CD tests pass for your pull request.
4.  **Open an Issue/PR**: Discuss new features or bug fixes by [opening an issue](https://github.com/eserlxl/vglog-filter/issues) first, or directly submit a pull request.

For a detailed guide, please read our [Contributing Guidelines](.github/CONTRIBUTING.md).

### How do I report bugs or request features?
Please use the GitHub Issues tracker to report bugs or request new features. When opening an issue, provide:
-   A clear and concise description of the problem or feature request.
-   Steps to reproduce the bug (if applicable).
-   Expected versus actual behavior.
-   Relevant system information (Operating System, compiler version, `vglog-filter` version).

### Where can I get more help with development?
-   **Project Documentation**: The `doc/` directory contains comprehensive guides on various aspects of the project, including the [Developer Guide](DEVELOPER_GUIDE.md), [Build Guide](BUILD.md), [Test Suite Guide](TEST_SUITE.md), and [CI/CD Guide](CI_CD_GUIDE.md).
-   **GitHub Issues/Discussions**: For specific questions or broader discussions, utilize the GitHub Issues or Discussions sections of the repository.

### What license is used for `vglog-filter`?
`vglog-filter` is licensed under the [GNU General Public License v3.0 (GPLv3)](LICENSE). This is a free, copyleft license that guarantees users the freedom to run, study, share, and modify the software. See the [LICENSE](LICENSE) file for full details.

[↑ Back to top](#frequently-asked-questions-faq)

## Troubleshooting

### The tool exits with "Permission denied" when trying to read a file
This usually indicates a file permissions issue. Check that:
- The file exists and is readable by your user
- You have the necessary permissions to access the file
- The file path is correct (use absolute paths if unsure)

```sh
# Check file permissions
ls -la your_valgrind.log

# Try with explicit permissions
chmod 644 your_valgrind.log
```

### Processing seems to hang on large files
This might indicate memory issues. Try:
- Using the `--stream` option to force stream processing
- Using the `--progress` option to monitor processing
- Checking available system memory

```sh
# Force stream processing
./vglog-filter --stream --progress large_file.log
```

### The output doesn't match what I expected
Common causes and solutions:
- **No output**: Check if your marker string is correct or use `--keep-debug-info`
- **Missing errors**: Verify the depth setting isn't too restrictive
- **Different deduplication**: Try adjusting the `--depth` parameter

```sh
# Process entire file to see all content
./vglog-filter --keep-debug-info --verbose input.log
```

### Build fails with compiler errors
Ensure you have:
- A C++20 compatible compiler (GCC 10+ or Clang 12+)
- CMake 3.16 or newer
- Required build tools installed

```sh
# Check compiler version
g++ --version

# Check CMake version
cmake --version
```

### Tests fail locally but pass in CI
This might indicate:
- Different compiler versions or flags
- Missing dependencies
- Environment-specific issues

Try running with debug builds and check the test output for specific error messages.

[↑ Back to top](#frequently-asked-questions-faq)