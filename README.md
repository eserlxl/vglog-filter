# vglog-filter

vglog-filter is a fast and flexible tool designed to process and clean up Valgrind log files. It helps developers and testers focus on the most relevant information by removing noise, deduplicating stack traces, and normalizing logs for easier inspection and comparison. This streamlines the debugging process, especially for large or repetitive Valgrind outputs.

## Table of Contents

- [Why Use vglog-filter?](#why-use-vglog-filter)
- [Features](#features)
- [Installation & Prerequisites](#installation--prerequisites)
- [Build Options](#build-options)
  - [Usage with build.sh](#usage-with-buildsh)
- [Usage Example](#usage-example)
- [Versioning System](#versioning-system)
  - [Current Version](#current-version)
  - [Automated Version Bumping](#automated-version-bumping)
  - [Manual Version Management](#manual-version-management)
- [Testing & CI/CD](#testing--cicd)
  - [GitHub Actions Workflows](#github-actions-workflows)
  - [Local Testing](#local-testing)
  - [Development Tools](#development-tools)
- [Documentation](#documentation)
- [Contributing](#contributing)
  - [Development Workflow](#development-workflow)
- [License](#license)

## Why Use vglog-filter? [↑](#vglog-filter)

Valgrind is a powerful tool for detecting memory errors and leaks in C/C++ programs, but its logs can be overwhelming—especially for large projects or repeated test runs. Raw Valgrind logs often contain:
- Repeated or redundant stack traces
- Noisy, irrelevant warnings
- Non-deterministic elements (e.g., memory addresses) that make diffs and comparisons difficult

vglog-filter addresses these issues by:
- **Filtering out noise**: Removes irrelevant or user-specified log lines.
- **Deduplicating stack traces**: Collapses repeated errors and stack traces to a single instance.
- **Normalizing logs**: Replaces non-deterministic elements (like memory addresses) with placeholders for easier diffing and automated analysis.

## Features [↑](#vglog-filter)

- **High performance**: Optimized for speed, suitable for large log files.
- **Flexible filtering**: Customizable rules for what to keep or discard.
- **Stack trace deduplication**: Groups identical errors for concise output.
- **Log normalization**: Makes logs comparable across runs and systems.
- **Easy integration**: Can be used as a standalone tool or in CI pipelines.
- **Automated versioning**: Semantic versioning with automated bumping based on conventional commits.
- **Comprehensive testing**: Multi-platform CI/CD with multiple build configurations.

## Installation & Prerequisites [↑](#vglog-filter)

- **Dependencies**: Requires a C++17-compatible compiler, CMake (version 3.10 or newer recommended).
- **Supported platforms**: Linux (tested), should work on other POSIX systems with minimal changes.

Clone the repository and ensure you have the necessary build tools installed:
```sh
sudo pacman -S base-devel cmake gcc   # Arch Linux example
# or
sudo apt-get install build-essential cmake   # Debian/Ubuntu example
```

## Build Options [↑](#vglog-filter)

This project supports several build modes via CMake options and the `build.sh` script:

- **PERFORMANCE_BUILD**: Enables performance optimizations (`-O3 -march=native -mtune=native -flto`, defines `NDEBUG`).
- **WARNING_MODE**: Enables extra compiler warnings (`-Wextra` in addition to `-Wall -pedantic`).
- **DEBUG_MODE**: Enables debug flags (`-g -O0`, defines `DEBUG`). Mutually exclusive with PERFORMANCE_BUILD (debug takes precedence).

### Usage with build.sh [↑](#vglog-filter)

You can use the `build.sh` script to configure builds with these options:

- Default build:
  ```sh
  ./build.sh
  ```
- Performance build:
  ```sh
  ./build.sh performance
  ```
- Extra warnings:
  ```sh
  ./build.sh warnings
  ```
- Debug build:
  ```sh
  ./build.sh debug
  ```
- Combine options (e.g., debug + warnings):
  ```sh
  ./build.sh debug warnings
  ```

If both `debug` and `performance` are specified, debug mode takes precedence.

## Usage Example [↑](#vglog-filter)

After building, you can use vglog-filter as follows:

```sh
valgrind --leak-check=full ./your_program 2> raw.log
./vglog-filter raw.log > filtered.log
```

- `raw.log`: The original Valgrind output.
- `filtered.log`: The cleaned, deduplicated, and normalized log.

You can also pipe output directly:
```sh
valgrind --leak-check=full ./your_program 2>&1 | ./vglog-filter > filtered.log
```

For detailed usage instructions, command-line options, and advanced filtering techniques, see the [Usage Guide](doc/USAGE.md).

## Versioning System [↑](#vglog-filter)

vglog-filter uses [Semantic Versioning](https://semver.org/) with automated version management:

### Current Version [↑](#vglog-filter)
The current version is stored in the `VERSION` file and displayed with:
```sh
./vglog-filter --version
```

### Automated Version Bumping [↑](#vglog-filter)
The project uses GitHub Actions to automatically bump versions based on [Conventional Commits](https://www.conventionalcommits.org/):

- **BREAKING CHANGE**: Triggers a **major** version bump
- **feat**: Triggers a **minor** version bump  
- **fix**: Triggers a **patch** version bump
- **docs**, **style**, **refactor**, **perf**, **test**, **chore**: Triggers a **patch** version bump

### Manual Version Management [↑](#vglog-filter)
For manual version bumps, use the provided tools:

```sh
# Command-line version bump
./dev-bin/bump-version [major|minor|patch] [--commit] [--tag]

# Interactive version bump (Cursor IDE)
./dev-bin/cursor-version-bump
```

## Testing & CI/CD [↑](#vglog-filter)

The project includes comprehensive testing infrastructure:

### GitHub Actions Workflows [↑](#vglog-filter)
- **Build and Test**: Multi-platform testing with multiple build configurations
- **Code Security**: Automated security analysis with CodeQL
- **Shell Script Linting**: ShellCheck validation for all scripts
- **Automated Versioning**: Semantic version bumping based on commit messages

### Local Testing [↑](#vglog-filter)
All build configurations are tested locally and in CI:
- Default build
- Performance build (optimized)
- Debug build
- Warnings build (extra compiler warnings)

### Development Tools [↑](#vglog-filter)
The `dev-bin/` directory contains development utilities:
- `bump-version`: Command-line version management
- `cursor-version-bump`: Interactive version bumping for Cursor IDE

## Documentation [↑](#vglog-filter)

Comprehensive documentation is available in the [`doc/`](doc/) folder:

- [USAGE.md](doc/USAGE.md): Basic usage, options, and workflow
- [FAQ.md](doc/FAQ.md): Frequently asked questions
- [ADVANCED.md](doc/ADVANCED.md): Advanced filtering, signature depth, marker customization, and deduplication logic
- [BUILD.md](doc/BUILD.md): Build script and configuration options
- [VERSIONING.md](doc/VERSIONING.md): Versioning strategy and automated version management

## Contributing [↑](#vglog-filter)

Contributions, bug reports, and feature requests are welcome! Please open an issue or submit a pull request.

### Development Workflow [↑](#vglog-filter)
1. Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for commit messages
2. Use the provided version bumping tools for releases
3. Ensure all tests pass before submitting pull requests
4. Check the [CONTRIBUTING.md](.github/CONTRIBUTING.md) for detailed guidelines

## License [↑](#vglog-filter)

This project is licensed under the GNU General Public License v3.0 (GPLv3). See the LICENSE file for details.