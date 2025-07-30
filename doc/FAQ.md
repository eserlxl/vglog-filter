# vglog-filter FAQ

## What does vglog-filter do?
It deduplicates and filters Valgrind log files, making it easier to spot unique memory errors and issues by removing redundant or repeated blocks.

## What is the default marker and why is it used?
The default marker is `Successfully downloaded debug`. By default, only log entries after the last occurrence of this marker are processed. This helps focus on the most recent run or relevant section of the log.

## How do I keep all log entries?
Use the `-k` or `--keep-debug-info` option to process the entire log file, ignoring the marker.

## What does the depth option do?
The `-d N` or `--depth N` option controls how many lines are used to generate the signature for deduplication. A higher depth means more context is considered. `0` means unlimited depth.

## How do I see the raw, unscrubbed log blocks?
Use the `-v` or `--verbose` option to disable address and `at:` scrubbing.

## What if my log uses a different marker?
Use the `-m S` or `--marker S` option to specify a custom marker string.

## What happens if the input file cannot be opened?
The tool will print a descriptive error message with helpful suggestions and exit with a non-zero status. It will also check if the file exists and is readable.

## What happens if the input file is empty?
The tool will display a warning message and exit successfully (status 0) without processing anything.

## What if I provide an invalid depth value?
The tool will display a clear error message showing the invalid value and the expected format (non-negative integer).

## How do I run tests for vglog-filter?
Use the build script with the `tests` option:
```sh
./build.sh tests
```
This will build and run the test suite, automatically cleaning up any temporary files.

You can also combine tests with other build options:
```sh
# Tests with debug mode
./build.sh tests debug

# Tests with performance optimizations and warnings
./build.sh tests performance warnings
```

## How does vglog-filter handle large files?
vglog-filter automatically detects files larger than 5MB and switches to stream processing mode for memory efficiency. You'll see a message "Info: Large file detected, using stream processing mode" when this happens. You can also force stream processing with the `-s` flag regardless of file size.

## How can I monitor progress when processing large files?
Use the `-p` or `--progress` option to see real-time progress updates. The tool will display percentage completion and line counts every 1000 lines processed:
```sh
vglog-filter -p large_valgrind.log > filtered.log
```

## How can I monitor memory usage during processing?
Use the `-M` or `--memory` option to track memory usage at key processing stages:
```sh
vglog-filter -M valgrind.log > filtered.log
```
This will show memory usage during file reading, processing, and deduplication phases.

## Can I combine progress and memory monitoring?
Yes! You can use both options together for comprehensive monitoring:
```sh
vglog-filter -p -M very_large_valgrind.log > filtered.log
```

## How do I check the version of vglog-filter?
Use the `-V` or `--version` option to display the current version:
```sh
vglog-filter --version
```

**Note**: The version is read from multiple locations in order of preference (local development, build directory, system installation). If no version file is found, it will display "unknown".

## Can I pipe output directly from valgrind to vglog-filter?
Yes! You can now pipe directly from valgrind:
```sh
valgrind --leak-check=full ./your_program 2>&1 | vglog-filter
```
This is much more convenient than saving to a file first.

## Can I use vglog-filter with logs from tools other than Valgrind?
It is designed for Valgrind logs, but may work with similar formats if the error blocks match the expected patterns.

## What build configurations are available?
The project supports several build configurations:
- **Default**: Standard build with O2 optimizations
- **Performance**: O3 optimizations with LTO and native architecture tuning
- **Debug**: Debug symbols with O0 optimization for debugging
- **Warnings**: Extra compiler warnings for code quality
- **Tests**: Builds and runs the test suite

You can combine these options: `./build.sh performance warnings tests`

## How is the project tested in CI/CD?
The project uses comprehensive GitHub Actions workflows that test:
- All 12 build configuration combinations
- Cross-platform compatibility (Ubuntu, Arch, Fedora, Debian)
- Debug builds with GDB integration
- Performance optimizations and LTO verification
- Memory sanitizer testing
- Static analysis with Clang-Tidy
- Security analysis with CodeQL
- Shell script validation with ShellCheck

## What performance optimizations have been implemented?
Recent optimizations include:
- **String operations**: Uses `std::string_view` for better performance
- **Regex patterns**: Optimized with ECMAScript flags for faster matching
- **Large file detection**: Efficient file size checking using `stat()`
- **Array operations**: Uses `std::span` for memory-efficient array handling
- **Stream processing**: Automatic detection and efficient processing of large files
- **Memory monitoring**: Real-time memory usage tracking for performance analysis

## What version is currently available?
The current version is **4.1.4**. The project uses semantic versioning with automated version management based on code changes.

## How does the versioning system work?
The project uses semantic versioning with automated version bumping:
- **MAJOR**: Breaking changes (incompatible API changes)
- **MINOR**: New features (backward-compatible additions)
- **PATCH**: Bug fixes and minor improvements

The system analyzes actual code changes and uses conservative thresholds to prevent rapid version increases.

## What development tools are available?
The project includes several development tools in the `dev-bin/` directory:
- **semantic-version-analyzer**: Analyzes code changes and suggests version bumps
- **bump-version**: Handles version bumping and release creation
- **tag-manager**: Manages git tags and cleanup
- **cursor-version-bump**: Cursor IDE integration for version bumping

## How do I contribute to the project?
Contributions are welcome! Please:
1. Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification
2. Run tests with `./build.sh tests` before submitting
3. Check that all CI/CD tests pass
4. Open an issue or submit a pull request

## What platforms are supported?
The project is primarily tested on Linux (Arch Linux, Ubuntu, Fedora, Debian) but should work on other POSIX systems with minimal changes. The CI/CD pipeline tests across multiple Linux distributions.

## How do I report bugs or request features?
Please open an issue on GitHub with:
- A clear description of the problem or feature request
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- System information (OS, compiler version, etc.)

## What license is used?
The project is licensed under the GNU General Public License v3.0 (GPLv3). See the LICENSE file for details.

## How do I install vglog-filter?
Currently, you need to build from source:
```sh
git clone <repository-url>
cd vglog-filter
./build.sh performance
sudo cp build/bin/vglog-filter /usr/local/bin/
```

## What are the system requirements?
- C++20-compatible compiler (GCC 10+ or Clang 10+)
- CMake 3.16 or newer
- Linux or other POSIX system
- Standard build tools (make, etc.)

## How do I get help with development?
- Check the comprehensive documentation in the `doc/` directory
- Review the [Developer Guide](DEVELOPER_GUIDE.md) for build options and development workflow
- Check the [Test Suite Documentation](TEST_SUITE.md) for testing guidelines
- Open an issue on GitHub for specific questions or problems 