# vglog-filter

vglog-filter is a fast and flexible tool designed to process and clean up Valgrind log files. It helps developers and testers focus on the most relevant information by removing noise, deduplicating stack traces, and normalizing logs for easier inspection and comparison. This streamlines the debugging process, especially for large or repetitive Valgrind outputs.

## Table of Contents

- [Motivation](#motivation)
- [Features](#features)
- [Installation & Prerequisites](#installation--prerequisites)
- [Usage Example](#usage-example)
- [Documentation](#documentation)
- [Contributing](#contributing)
  - [Development Workflow](#development-workflow)
- [License](#license)

## Motivation

Valgrind is a powerful tool for detecting memory errors and leaks in C/C++ programs, but its logs can be overwhelming—especially for large projects or repeated test runs. Raw Valgrind logs often contain:
- Repeated or redundant stack traces
- Noisy, irrelevant warnings
- Non-deterministic elements (e.g., memory addresses) that make diffs and comparisons difficult

vglog-filter addresses these issues by:
- **Filtering out noise**: Removes irrelevant or user-specified log lines.
- **Deduplicating stack traces**: Collapses repeated errors and stack traces to a single instance.
- **Normalizing logs**: Replaces non-deterministic elements (like memory addresses) with placeholders for easier diffing and automated analysis.

[↑ Back to top](#vglog-filter)

## Features

- **High performance**: Optimized for speed, suitable for large log files.
- **Flexible filtering**: Customizable rules for what to keep or discard.
- **Stack trace deduplication**: Groups identical errors for concise output.
- **Log normalization**: Makes logs comparable across runs and systems.
- **Easy integration**: Can be used as a standalone tool or in CI pipelines.
- **Robust error handling**: Comprehensive error messages and input validation.
- **Automatic large file detection**: Smart processing mode selection for optimal performance.
- **Memory-efficient processing**: Stream processing for large files to prevent OOM errors.
- **Progress reporting**: Real-time progress updates for large file processing.
- **Memory monitoring**: Track memory usage during processing for performance analysis.
- **Modern C++ optimizations**: Uses `std::string_view`, `std::span`, and optimized regex patterns.
- **Automated versioning**: Semantic versioning with automated bumping based on conventional commits.
- **Comprehensive CI/CD**: 12 GitHub Actions workflows testing all build configurations.
- **Quality assurance**: Static analysis, memory sanitizer, security scanning, and cross-platform testing.
- **Comprehensive test suite**: C++ unit tests, integration tests, and automated CI/CD testing (see [Test Suite Documentation](doc/TEST_SUITE.md)).

[↑ Back to top](#vglog-filter)

## Installation & Prerequisites

- **Dependencies**: Requires a C++20-compatible compiler, CMake (version 3.10 or newer recommended).
- **Supported platforms**: Linux (tested), should work on other POSIX systems with minimal changes.
- **Build script**: The project includes a `build.sh` script for easy compilation with various build configurations (see [Developer Guide](doc/DEVELOPER_GUIDE.md#build-options) for details).

Clone the repository and ensure you have the necessary build tools installed:
```sh
sudo pacman -S base-devel cmake gcc   # Arch Linux example
# or
sudo apt-get install build-essential cmake   # Debian/Ubuntu example
```

[↑ Back to top](#vglog-filter)

## Usage Example

After building, you can use vglog-filter as follows:

```sh
valgrind --leak-check=full ./your_program 2> raw.log
vglog-filter raw.log > filtered.log
```

- `raw.log`: The original Valgrind output.
- `filtered.log`: The cleaned, deduplicated, and normalized log.
- **Automatic optimization**: Large files (>5MB) automatically use stream processing.

You can also pipe output directly:
```sh
valgrind --leak-check=full ./your_program 2>&1 | vglog-filter > filtered.log
```

Direct stdin support! You can pipe directly from valgrind:
```sh
valgrind --leak-check=full ./your_program 2>&1 | vglog-filter
```

For large files, you can force stream processing:
```sh
vglog-filter -s very_large.log > filtered.log
```

Monitor progress for large files:
```sh
vglog-filter -p large_file.log > filtered.log
```

Track memory usage during processing:
```sh
vglog-filter -M valgrind.log > filtered.log
```

Combine progress and memory monitoring:
```sh
vglog-filter -p -M very_large_file.log > filtered.log
```

For detailed usage instructions, see the [Usage Guide](doc/USAGE.md).

[↑ Back to top](#vglog-filter)

## Documentation

Comprehensive documentation is available in the [`doc/`](doc/) folder:

- [USAGE.md](doc/USAGE.md): Basic usage, options, and workflow
- [FAQ.md](doc/FAQ.md): Frequently asked questions
- [ADVANCED.md](doc/ADVANCED.md): Advanced filtering, signature depth, marker customization, and deduplication logic
- [BUILD.md](doc/BUILD.md): Build script and configuration options
- [VERSIONING.md](doc/VERSIONING.md): Versioning strategy and automated version management
- [DEVELOPER_GUIDE.md](doc/DEVELOPER_GUIDE.md): Build options, versioning system, and development infrastructure
- [TEST_SUITE.md](doc/TEST_SUITE.md): Comprehensive test suite documentation and testing guidelines
- [CI_CD_GUIDE.md](doc/CI_CD_GUIDE.md): Comprehensive CI/CD and testing infrastructure guide

[↑ Back to top](#vglog-filter)

## Contributing

Contributions, bug reports, and feature requests are welcome! Please open an issue or submit a pull request.

### Development Workflow
1. Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for commit messages
2. Use the provided version bumping tools for releases
3. Run tests with `./run_tests.sh` before submitting pull requests (see [Test Suite Documentation](doc/TEST_SUITE.md))
4. All builds are automatically tested in CI/CD with 12 different configurations
5. Check the [CONTRIBUTING.md](.github/CONTRIBUTING.md) for detailed guidelines

[↑ Back to top](#vglog-filter)

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3). See the LICENSE file for details.

[↑ Back to top](#vglog-filter)