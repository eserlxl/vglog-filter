# Frequently Asked Questions (FAQ)

This document provides answers to common questions about `vglog-filter`, covering its functionality, usage, build process, and development aspects.

## Table of Contents

- [General Information](#general-information)
- [Usage and Options](#usage-and-options)
- [Performance and Monitoring](#performance-and-monitoring)
- [Building and Testing](#building-and-testing)
- [Versioning and Releases](#versioning-and-releases)
- [Contributing and Support](#contributing-and-support)

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
The current stable version of `vglog-filter` is dynamically managed. You can check the exact version by running `vglog-filter --version`.

### How does the versioning system work?
`vglog-filter` follows [Semantic Versioning (SemVer)](https://semver.org/). Version bumps (MAJOR.MINOR.PATCH) are largely automated based on [Conventional Commits](https://www.conventionalcommits.org/) in the Git history:
-   **MAJOR**: Triggered by `BREAKING CHANGE` in commit footers.
-   **MINOR**: Triggered by `feat:` (new features).
-   **PATCH**: Triggered by `fix:` (bug fixes).

Other commit types (e.g., `docs:`, `chore:`) do not trigger version bumps. This system ensures that the version number accurately reflects the nature of changes. For more details, see the [Versioning Guide](VERSIONING.md).

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