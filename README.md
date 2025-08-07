# vglog-filter

[![Test](https://github.com/eserlxl/vglog-filter/actions/workflows/test.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/test.yml)
[![Comprehensive Test](https://github.com/eserlxl/vglog-filter/actions/workflows/comprehensive-test.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/comprehensive-test.yml)
[![Cross-Platform](https://github.com/eserlxl/vglog-filter/actions/workflows/cross-platform.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/cross-platform.yml)
[![CodeQL](https://github.com/eserlxl/vglog-filter/actions/workflows/codeql.yml/badge.svg)](https://github.com/eserlxl/vglog-filter/actions/workflows/codeql.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![C++20](https://img.shields.io/badge/C%2B%2B-20-blue.svg)](https://isocpp.org/std/status)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

**vglog-filter** is a fast, secure, and flexible command-line tool designed to process and clean up Valgrind log files. It helps developers focus on relevant information by removing noise, deduplicating stack traces, and normalizing logs for easier inspection and comparison. It features advanced LOC-based versioning and comprehensive testing.

## Table of Contents

- [Why vglog-filter?](#why-vglog-filter)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Security](#security)
- [Performance](#performance)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Why vglog-filter?

Valgrind is an indispensable tool for detecting memory errors and leaks in C/C++ programs. However, its raw output can be verbose and challenging to analyze, especially in large projects or during automated testing. Common issues include:

- **Redundant Information**: Repeated stack traces and warnings clutter the logs
- **Noise**: Irrelevant details obscure critical error messages
- **Non-Deterministic Output**: Memory addresses and other dynamic elements make log comparisons unreliable across runs
- **Large File Handling**: Processing massive log files can cause memory issues
- **Security Concerns**: Path traversal and other vulnerabilities in log processing

`vglog-filter` addresses these challenges by providing a streamlined, normalized, and deduplicated view of your Valgrind logs, enabling quicker debugging and more effective CI/CD integration.

[↑ Back to top](#vglog-filter)

## Features

### Core Log Processing
- **High-performance filtering**: Fast, customizable rules to remove noise and irrelevant warnings
- **Stack trace deduplication**: Automatically collapses identical error reports and stack traces into a single, concise entry
- **Log normalization**: Replaces non-deterministic data (e.g., memory addresses, process IDs) with consistent placeholders, making logs easily comparable across different runs
- **Intelligent trimming**: Optionally removes content above the last debug marker to focus on relevant sections

### Performance & Efficiency
- **Memory-efficient stream processing**: Designed to handle extremely large log files without excessive memory consumption, preventing Out-Of-Memory (OOM) errors
- **Automatic optimization**: Intelligently selects the most efficient processing mode based on input file size
- **Modern C++**: Built with C++20, leveraging features like `std::string_view` for optimal performance
- **Progress reporting**: Real-time progress indicators for large file processing

### Security & Reliability
- **Path validation**: Secure file path handling with protection against directory traversal attacks
- **Input validation**: Comprehensive validation of command-line arguments and input data
- **Bounds checking**: Protection against buffer overflows and memory corruption
- **Error handling**: Robust error handling with informative error messages

### User Experience & Integration
- **Easy integration**: Functions seamlessly as a standalone command-line tool or within automated CI/CD pipelines
- **Real-time progress reporting**: Provides visual feedback for long-running operations on large files
- **Memory monitoring**: Optional reporting of peak memory usage during processing
- **Flexible input**: Supports both file input and stdin streaming

### Development & Quality Assurance
- **Automated semantic versioning**: Version bumps are automatically managed with universal patch detection (every change gets a version bump) and LOC-based delta increments
- **Comprehensive CI/CD pipeline**: Features 12 distinct GitHub Actions workflows covering extensive testing, static analysis, memory sanitization, and security scanning
- **Extensive Test Suite**: Includes unit, integration, and workflow tests to ensure high reliability and correctness

[↑ Back to top](#vglog-filter)

## Quick Start

### Prerequisites
- C++20 compatible compiler (GCC 10+, Clang 12+, or MSVC 2019+)
- CMake 3.16 or later
- Make or Ninja build system

### Build and Install

```bash
# Clone the repository
git clone https://github.com/eserlxl/vglog-filter.git
cd vglog-filter

# Build the project
./build.sh

# The binary is now available at build/bin/vglog-filter
```

### Basic Usage

```bash
# Process a Valgrind log file
./build/bin/vglog-filter valgrind.log > filtered.log

# Pipe directly from Valgrind (recommended)
valgrind --leak-check=full ./your_program 2>&1 | ./build/bin/vglog-filter

# Show progress for large files
./build/bin/vglog-filter --progress large_log.log > filtered.log
```

[↑ Back to top](#vglog-filter)

## Installation

### From Source (Recommended)

For detailed instructions on building from source, please consult the [Build Guide](doc/BUILD.md).

```bash
# Clone and build
git clone https://github.com/eserlxl/vglog-filter.git
cd vglog-filter
./build.sh

# Optional: Install system-wide
sudo cp build/bin/vglog-filter /usr/local/bin/
```

### Build Options

The project supports multiple build configurations:

```bash
# Default build
./build.sh

# Performance-optimized build
./build.sh performance

# Debug build with sanitizers
./build.sh debug

# Build with extra warnings
./build.sh warnings
```

[↑ Back to top](#vglog-filter)

## Usage

`vglog-filter` can process Valgrind logs from a specified file or directly from standard input (stdin).

### Basic Filtering

To filter a Valgrind log file and save the cleaned output:

```bash
# Generate a raw Valgrind log
valgrind --leak-check=full ./your_program 2> raw.log

# Filter the log and save to a new file
./build/bin/vglog-filter raw.log > filtered.log
```

### Piping from Valgrind (Recommended)

For real-time processing, pipe Valgrind's output directly to `vglog-filter`:

```bash
valgrind --leak-check=full --show-leak-kinds=all ./your_program 2>&1 | ./build/bin/vglog-filter
```

> **Note**: `vglog-filter` automatically detects large input streams (exceeding 5MB) and switches to a memory-efficient stream processing mode to prevent performance degradation or OOM errors.

### Advanced Usage Examples

```bash
# Process with custom depth for signature matching
./build/bin/vglog-filter -d 3 valgrind.log > filtered.log

# Keep debug information and show progress
./build/bin/vglog-filter -k -p large_log.log > filtered.log

# Use custom marker for trimming
./build/bin/vglog-filter -m "Test completed" valgrind.log > filtered.log

# Monitor memory usage during processing
./build/bin/vglog-filter -M --progress huge_log.log > filtered.log

# Force stream mode for consistent behavior
./build/bin/vglog-filter -s valgrind.log > filtered.log
```

### Command-Line Options

| Option | Long Option | Description |
|--------|-------------|-------------|
| `-k` | `--keep-debug-info` | Keep everything; do not trim above last debug marker |
| `-v` | `--verbose` | Show completely raw blocks (no address / "at:" scrub) |
| `-d N` | `--depth N` | Signature depth (default: 1, 0 = unlimited) |
| `-m S` | `--marker S` | Marker string for trimming (default: "Successfully downloaded debug") |
| `-s` | `--stream` | Force stream processing mode |
| `-p` | `--progress` | Show progress for large files |
| `-M` | `--memory` | Monitor memory usage during processing |
| `-V` | `--version` | Show version information |
| `-h` | `--help` | Show help message |

For a comprehensive list of all available options and advanced usage patterns, refer to the [Usage Guide](doc/USAGE.md).

[↑ Back to top](#vglog-filter)

## Security

`vglog-filter` implements several security measures to protect against common vulnerabilities:

- **Path Validation**: All file paths are validated and canonicalized to prevent directory traversal attacks
- **Input Sanitization**: Command-line arguments and input data are thoroughly validated
- **Bounds Checking**: Comprehensive bounds checking prevents buffer overflows
- **Memory Limits**: Configurable limits prevent resource exhaustion attacks
- **Error Handling**: Secure error handling prevents information disclosure

For detailed security information, see the [Security Guide](.github/SECURITY.md).

[↑ Back to top](#vglog-filter)

## Performance

`vglog-filter` is designed for high performance and efficiency:

- **Stream Processing**: Large files are processed in streaming mode to minimize memory usage
- **Optimized Algorithms**: Efficient regex patterns and data structures for fast processing
- **Memory Management**: Smart memory allocation and deallocation strategies
- **Parallel Processing**: Where applicable, operations are optimized for modern hardware

### Performance Benchmarks

Typical performance characteristics:
- **Small files (< 1MB)**: < 100ms processing time
- **Medium files (1-100MB)**: Linear scaling with file size
- **Large files (> 100MB)**: Stream processing with constant memory usage
- **Memory usage**: Automatic stream mode for files >5MB to prevent OOM errors

[↑ Back to top](#vglog-filter)

## Documentation

Comprehensive documentation is available in the `doc/` directory:

- [Build Guide](doc/BUILD.md) - Detailed build instructions and configuration options
- [Usage Guide](doc/USAGE.md) - Complete usage documentation with examples
- [Developer Guide](doc/DEVELOPER_GUIDE.md) - Information for contributors
- [Test Suite Guide](doc/TEST_SUITE.md) - Testing framework and test execution
- [CI/CD Guide](doc/CI_CD_GUIDE.md) - Continuous integration and deployment
- [FAQ](doc/FAQ.md) - Frequently asked questions and troubleshooting

[↑ Back to top](#vglog-filter)

## Contributing

We welcome contributions! Please see our [Contributing Guide](.github/CONTRIBUTING.md) for details on:

- Code style and standards
- Testing requirements
- Pull request process
- Issue reporting

### Development Setup

```bash
# Clone with submodules
git clone --recursive https://github.com/eserlxl/vglog-filter.git
cd vglog-filter

# Build with tests
./build.sh debug

# Run tests
./run_tests.sh
```

[↑ Back to top](#vglog-filter)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

[↑ Back to top](#vglog-filter)
# BREAKING: This is a breaking change
