# vglog-filter

[![Test](https://github.com/eserlxl/vglog-filter/actions/workflows/test.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/test.yml)
[![Comprehensive Test](https://github.com/eserlxl/vglog-filter/actions/workflows/comprehensive-test.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/comprehensive-test.yml)
[![Cross-Platform](https://github.com/eserlxl/vglog-filter/actions/workflows/cross-platform.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/cross-platform.yml)
[![CodeQL](https://github.com/eserlxl/vglog-filter/actions/workflows/codeql.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/codeql.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![C++20](https://img.shields.io/badge/C%2B%2B-20-blue.svg)](https://isocpp.org/std/status)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

**vglog-filter** is a fast and flexible tool designed to process and clean up Valgrind log files. It helps developers focus on relevant information by removing noise, deduplicating stack traces, and normalizing logs for easier inspection and comparison.

## Table of Contents

- [Motivation](#motivation)
- [Features](#features)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Motivation

Valgrind is a powerful tool for detecting memory errors and leaks in C/C++ programs, but its logs can be overwhelming—especially for large projects or repeated test runs. Raw Valgrind logs often contain:
- Repeated or redundant stack traces
- Noisy, irrelevant warnings
- Non-deterministic elements (e.g., memory addresses) that make diffs and comparisons difficult

`vglog-filter` addresses these issues by filtering noise, deduplicating stack traces, and normalizing logs for easier analysis.

[↑ Back to top](#vglog-filter)

## Features

- **Core Functionality**:
    - **High-performance filtering**: Fast, customizable rules to remove noise.
    - **Stack trace deduplication**: Collapses identical errors into a single report.
    - **Log normalization**: Replaces non-deterministic data (e.g., memory addresses) for easy diffing.
- **Performance & Efficiency**:
    - **Memory-efficient**: Uses stream processing for large files to prevent OOM errors.
    - **Automatic optimization**: Smart processing mode selection based on file size.
    - **Modern C++**: Leverages C++20 features like `std::string_view` for speed.
- **User Experience**:
    - **Easy integration**: Works as a standalone tool or in CI pipelines.
    - **Progress reporting**: Real-time progress updates for large files.
    - **Memory monitoring**: Track memory usage during processing.
- **Development & Quality**:
    - **Automated versioning**: Semantic versioning based on Conventional Commits.
    - **Comprehensive CI/CD**: 12 GitHub Actions workflows for testing, static analysis, memory sanitization, and security scanning.
    - **Extensive Test Suite**: Unit, integration, and workflow tests ensure reliability. See the [Test Suite Guide](doc/TEST_SUITE.md).

[↑ Back to top](#vglog-filter)

## Getting Started

### 1. Prerequisites
- C++20 compatible compiler (e.g., GCC 10+, Clang 12+)
- CMake (>= 3.16)

Install dependencies:
```sh
# Arch Linux
sudo pacman -S base-devel cmake gcc

# Debian/Ubuntu
sudo apt-get install build-essential cmake
```

### 2. Build
Clone the repository and run the build script:
```sh
git clone https://github.com/eserlxl/vglog-filter.git
cd vglog-filter
./build.sh
```
The executable will be located at `build/bin/vglog-filter`. For advanced build options, see the [Build Guide](doc/BUILD.md).

[↑ Back to top](#vglog-filter)

## Usage

`vglog-filter` can process Valgrind logs from a file or standard input.

### Basic Usage
Filter a log file and save the output:
```sh
valgrind --leak-check=full ./your_program 2> raw.log
./build/bin/vglog-filter raw.log > filtered.log
```

### Piping from Valgrind
Pipe Valgrind's output directly to `vglog-filter`:
```sh
valgrind --leak-check=full --show-leak-kinds=all ./your_program 2>&1 | ./build/bin/vglog-filter
```
> **Note**: `vglog-filter` automatically detects large files (>5MB) and switches to a memory-efficient stream processing mode.

### Command-Line Options
- `-s`: Force stream processing, even for small files.
- `-p`: Show a progress bar, useful for large files.
- `-M`: Monitor and report peak memory usage.

Example with options:
```sh
# Monitor progress and memory usage on a large file
./build/bin/vglog-filter -p -M very_large_file.log > filtered.log
```
For a complete list of options and advanced usage, see the [Usage Guide](doc/USAGE.md).

[↑ Back to top](#vglog-filter)

## Documentation

All documentation is located in the [`doc/`](doc/) directory.

**User Guides**
- [USAGE.md](doc/USAGE.md): Command-line options and examples.
- [FAQ.md](doc/FAQ.md): Frequently Asked Questions.
- [ADVANCED.md](doc/ADVANCED.md): Advanced features and customization.

**Developer Guides**
- [BUILD.md](doc/BUILD.md): Detailed build instructions.
- [DEVELOPER_GUIDE.md](doc/DEVELOPER_GUIDE.md): Core development workflows.
- [TEST_SUITE.md](doc/TEST_SUITE.md): Guide to the testing framework.
- [VERSIONING.md](doc/VERSIONING.md): Our versioning and release strategy.
- [CI_CD_GUIDE.md](doc/CI_CD_GUIDE.md): Overview of the CI/CD pipeline.
- [RELEASE_WORKFLOW.md](doc/RELEASE_WORKFLOW.md): How to create a new release.
- [TAG_MANAGEMENT.md](doc/TAG_MANAGEMENT.md): Managing git tags.

[↑ Back to top](#vglog-filter)

## Contributing

Contributions are welcome! Please open an issue to discuss your ideas or submit a pull request.

Before submitting a PR, please ensure:
1.  Your commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
2.  You have run the test suite locally with `./run_tests.sh`.
3.  You have read our [Contributing Guidelines](.github/CONTRIBUTING.md).

Our project uses an extensive CI/CD pipeline that automatically tests all contributions in 12 different build configurations.

[↑ Back to top](#vglog-filter)

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3). See the LICENSE file for details.

[↑ Back to top](#vglog-filter)
