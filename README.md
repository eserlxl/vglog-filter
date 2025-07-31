# vglog-filter

[![Test](https://github.com/eserlxl/vglog-filter/actions/workflows/test.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/test.yml)
[![Comprehensive Test](https://github.com/eserlxl/vglog-filter/actions/workflows/comprehensive-test.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/comprehensive-test.yml)
[![Cross-Platform](https://github.com/eserlxl/vglog-filter/actions/workflows/cross-platform.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/cross-platform.yml)
[![CodeQL](https://github.com/eserlxl/vglog-filter/actions/workflows/codeql.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/codeql.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![C++20](https://img.shields.io/badge/C%2B%2B-20-blue.svg)](https://isocpp.org/std/status)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

**vglog-filter** is a fast and flexible command-line tool designed to process and clean up Valgrind log files. It helps developers focus on relevant information by removing noise, deduplicating stack traces, and normalizing logs for easier inspection and comparison.

## Table of Contents

- [Why vglog-filter?](#why-vglog-filter)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Why vglog-filter?

Valgrind is an indispensable tool for detecting memory errors and leaks in C/C++ programs. However, its raw output can be verbose and challenging to analyze, especially in large projects or during automated testing. Common issues include:
- **Redundant Information**: Repeated stack traces and warnings clutter the logs.
- **Noise**: Irrelevant details obscure critical error messages.
- **Non-Deterministic Output**: Memory addresses and other dynamic elements make log comparisons (e.g., `diff`) unreliable across runs.

`vglog-filter` addresses these challenges by providing a streamlined, normalized, and deduplicated view of your Valgrind logs, enabling quicker debugging and more effective CI/CD integration.

[↑ Back to top](#vglog-filter)

## Features

- **Core Log Processing**:
    - **High-performance filtering**: Fast, customizable rules to remove noise and irrelevant warnings.
    - **Stack trace deduplication**: Automatically collapses identical error reports and stack traces into a single, concise entry.
    - **Log normalization**: Replaces non-deterministic data (e.g., memory addresses, process IDs) with consistent placeholders, making logs easily comparable across different runs.
- **Performance & Efficiency**:
    - **Memory-efficient stream processing**: Designed to handle extremely large log files without excessive memory consumption, preventing Out-Of-Memory (OOM) errors.
    - **Automatic optimization**: Intelligently selects the most efficient processing mode based on input file size.
    - **Modern C++**: Built with C++20, leveraging features like `std::string_view` for optimal performance.
- **User Experience & Integration**:
    - **Easy integration**: Functions seamlessly as a standalone command-line tool or within automated CI/CD pipelines.
    - **Real-time progress reporting**: Provides visual feedback for long-running operations on large files.
    - **Memory monitoring**: Optional reporting of peak memory usage during processing.
- **Development & Quality Assurance**:
    - **Automated semantic versioning**: Version bumps are automatically managed based on [Conventional Commits](https://www.conventionalcommits.org/) guidelines.
    - **Comprehensive CI/CD pipeline**: Features 12 distinct GitHub Actions workflows covering extensive testing, static analysis, memory sanitization, and security scanning.
    - **Extensive Test Suite**: Includes unit, integration, and workflow tests to ensure high reliability and correctness. Refer to the [Test Suite Guide](doc/TEST_SUITE.md) for details.

[↑ Back to top](#vglog-filter)

## Installation

### Prerequisites

To build and run `vglog-filter`, you need:
- A C++20 compatible compiler (e.g., GCC 10+, Clang 12+)
- CMake (version 3.16 or higher)

**Install Dependencies (Example for Linux Distributions):**

```sh
# Arch Linux
sudo pacman -S base-devel cmake gcc

# Debian/Ubuntu
sudo apt-get update
sudo apt-get install build-essential cmake
```

### Building from Source

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/eserlxl/vglog-filter.git
    cd vglog-filter
    ```
2.  **Build the project:**
    ```sh
    ./build.sh
    ```
    This script compiles the project and places the executable at `build/bin/vglog-filter`.

For advanced build configurations and options, please consult the [Build Guide](doc/BUILD.md).

[↑ Back to top](#vglog-filter)

## Usage

`vglog-filter` can process Valgrind logs from a specified file or directly from standard input (stdin).

### Basic Filtering

To filter a Valgrind log file and save the cleaned output:

```sh
# Generate a raw Valgrind log
valgrind --leak-check=full ./your_program 2> raw.log

# Filter the log and save to a new file
./build/bin/vglog-filter raw.log > filtered.log
```

### Piping from Valgrind (Recommended)

For real-time processing, pipe Valgrind's output directly to `vglog-filter`:

```sh
valgrind --leak-check=full --show-leak-kinds=all ./your_program 2>&1 | ./build/bin/vglog-filter
```
> **Note**: `vglog-filter` automatically detects large input streams (exceeding 5MB) and switches to a memory-efficient stream processing mode to prevent performance degradation or OOM errors.

### Command-Line Options

`vglog-filter` provides several options to control its behavior:

-   `-s, --stream`: Force stream processing mode, even for smaller files. Useful for consistent behavior in automated scripts.
-   `-p, --progress`: Display a real-time progress bar during processing. Ideal for large files to track progress.
-   `-M, --monitor-memory`: Monitor and report peak memory usage at the end of processing.

**Example with Options:**

```sh
# Process a very large log file, showing progress and monitoring memory usage
./build/bin/vglog-filter --progress --monitor-memory very_large_file.log > filtered.log
```
For a comprehensive list of all available options and advanced usage patterns, refer to the [Usage Guide](doc/USAGE.md).

[↑ Back to top](#vglog-filter)

## Documentation

All detailed documentation for `vglog-filter` is organized within the [`doc/`](doc/) directory.

**User Guides:**
- [USAGE.md](doc/USAGE.md): In-depth explanation of command-line options and practical usage examples.
- [FAQ.md](doc/FAQ.md): Answers to frequently asked questions about `vglog-filter`.
- [ADVANCED.md](doc/ADVANCED.md): Covers advanced features, configuration, and customization options.

**Developer Guides:**
- [BUILD.md](doc/BUILD.md): Comprehensive instructions for building the project from source, including dependencies and build configurations.
- [DEVELOPER_GUIDE.md](doc/DEVELOPER_GUIDE.md): Essential guide for new contributors, covering core development workflows and best practices.
- [TEST_SUITE.md](doc/TEST_SUITE.md): Detailed overview of the project's testing framework, how to run tests, and how to add new ones.
- [VERSIONING.md](doc/VERSIONING.md): Explains the project's semantic versioning strategy and release numbering.
- [CI_CD_GUIDE.md](doc/CI_CD_GUIDE.md): Provides an overview of the Continuous Integration and Continuous Deployment pipeline.
- [RELEASE_WORKFLOW.md](doc/RELEASE_WORKFLOW.md): Step-by-step guide on how to create and manage new releases.
- [TAG_MANAGEMENT.md](doc/TAG_MANAGEMENT.md): Instructions for managing Git tags within the repository.

[↑ Back to top](#vglog-filter)

## Contributing

We welcome contributions to `vglog-filter`! If you have an idea for a new feature, a bug report, or a suggestion for improvement, please feel free to [open an issue](https://github.com/eserlxl/vglog-filter/issues) to discuss it, or submit a pull request.

Before submitting a Pull Request, please ensure the following:
1.  Your commit messages adhere to the [Conventional Commits](https://www.conventionalcommits.org/) specification.
2.  You have successfully run the entire test suite locally using `./run_tests.sh`.
3.  You have reviewed our comprehensive [Contributing Guidelines](.github/CONTRIBUTING.md).

Our project utilizes an extensive CI/CD pipeline that automatically validates all contributions across 12 different build configurations, ensuring code quality and stability.

[↑ Back to top](#vglog-filter)

## License

This project is licensed under the terms of the [GNU General Public License v3.0 (GPLv3)](LICENSE). See the [LICENSE](LICENSE) file for full details.

[↑ Back to top](#vglog-filter)