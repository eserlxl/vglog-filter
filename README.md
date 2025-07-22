# vglog-filter

vglog-filter is a fast and flexible tool designed to process and clean up Valgrind log files. It helps developers and testers focus on the most relevant information by removing noise, deduplicating stack traces, and normalizing logs for easier inspection and comparison. This streamlines the debugging process, especially for large or repetitive Valgrind outputs.

## Why Use vglog-filter?

Valgrind is a powerful tool for detecting memory errors and leaks in C/C++ programs, but its logs can be overwhelming—especially for large projects or repeated test runs. Raw Valgrind logs often contain:
- Repeated or redundant stack traces
- Noisy, irrelevant warnings
- Non-deterministic elements (e.g., memory addresses) that make diffs and comparisons difficult

vglog-filter addresses these issues by:
- **Filtering out noise**: Removes irrelevant or user-specified log lines.
- **Deduplicating stack traces**: Collapses repeated errors and stack traces to a single instance.
- **Normalizing logs**: Replaces non-deterministic elements (like memory addresses) with placeholders for easier diffing and automated analysis.

## Features

- **High performance**: Optimized for speed, suitable for large log files.
- **Flexible filtering**: Customizable rules for what to keep or discard.
- **Stack trace deduplication**: Groups identical errors for concise output.
- **Log normalization**: Makes logs comparable across runs and systems.
- **Easy integration**: Can be used as a standalone tool or in CI pipelines.

## Installation & Prerequisites

- **Dependencies**: Requires a C++17-compatible compiler and CMake (version 3.10 or newer recommended).
- **Supported platforms**: Linux (tested), should work on other POSIX systems with minimal changes.

Clone the repository and ensure you have the necessary build tools installed:
```sh
sudo pacman -S base-devel cmake gcc   # Arch Linux example
# or
sudo apt-get install build-essential cmake   # Debian/Ubuntu example
```

## Build Options

This project supports several build modes via CMake options and the `build.sh` script:

- **PERFORMANCE_BUILD**: Enables performance optimizations (`-O3 -march=native -mtune=native -flto`, defines `NDEBUG`).
- **WARNING_MODE**: Enables extra compiler warnings (`-Wextra` in addition to `-Wall -pedantic`).
- **DEBUG_MODE**: Enables debug flags (`-g -O0`, defines `DEBUG`). Mutually exclusive with PERFORMANCE_BUILD (debug takes precedence).

### Usage with build.sh

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

## Usage Example

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

## Contributing

Contributions, bug reports, and feature requests are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3). See the LICENSE file for details.
