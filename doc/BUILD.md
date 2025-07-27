# Building vglog-filter

The `build.sh` script automates the configuration and compilation of the vglog-filter project using CMake and Make.

## Usage

```sh
./build.sh [performance] [warnings] [debug] [clean] [tests]
```

You can provide one or more of the following options:

| Option        | Description                                                      |
|---------------|------------------------------------------------------------------|
| `performance` | Enables performance optimizations (disables debug mode if both are set) |
| `warnings`    | Enables extra compiler warnings                                  |
| `debug`       | Enables debug mode (disables performance mode if both are set)   |
| `clean`       | Forces a clean build (removes all build artifacts)               |
| `tests`       | Builds and runs the test suite                                   |

- `performance` and `debug` are **mutually exclusive**. If both are specified, `debug` takes precedence and disables `performance`.
- `warnings`, `clean`, and `tests` can be combined with any mode.
- `clean` is useful for configuration changes or debugging build issues.
- `tests` will automatically clean up any leftover test files before and after execution.

## Examples

- **Performance build with warnings:**
  ```sh
  ./build.sh performance warnings
  ```
- **Debug build:**
  ```sh
  ./build.sh debug
  ```
- **Debug build with extra warnings:**
  ```sh
  ./build.sh debug warnings
  ```
- **Clean build (removes all artifacts before building):**
  ```sh
  ./build.sh clean
  ```
- **Performance build with warnings and clean:**
  ```sh
  ./build.sh performance warnings clean
  ```
- **Build and run tests:**
  ```sh
  ./build.sh tests
  ```
- **Build and run tests with warnings:**
  ```sh
  ./build.sh tests warnings
  ```
- **Build and run tests in debug mode:**
  ```sh
  ./build.sh tests debug
  ```

## What the Script Does
- Creates a `build/` directory if it does not exist.
- Runs CMake with the selected options as variables.
- If `clean` is specified, runs `make clean` to remove all build artifacts.
- Builds the project using `make -j20` for fast parallel compilation.
- If `tests` is specified, builds and runs the test suite with automatic cleanup.
- Validates command-line arguments and provides helpful warnings for unknown options.
- Supports all build configuration combinations for comprehensive testing.

## Performance Features
The built executable includes several performance optimizations:
- **Automatic large file detection**: Files >5MB automatically use stream processing
- **Memory optimization**: Vector capacity reservation and efficient string operations
- **Regex optimization**: All patterns use `std::regex::optimize` for better performance
- **Smart processing**: Optimal mode selection based on file size

## Output
- The compiled binary and build artifacts will be placed in the `build/` directory.

## Continuous Integration

The project includes comprehensive GitHub Actions workflows that automatically test all build configurations:

### Automated Testing Workflows
- **Build and Test**: Tests default, performance, debug, and warnings builds
- **Comprehensive Test**: Tests all 12 build configuration combinations
- **Debug Build Test**: Dedicated testing for debug builds with GDB integration
- **Cross-Platform Test**: Tests builds across Ubuntu, Arch Linux, Fedora, and Debian
- **Performance Benchmark**: Automated performance testing and optimization verification
- **Memory Sanitizer**: Memory error detection using Clang's MemorySanitizer
- **Clang-Tidy**: Static analysis and code quality checks
- **CodeQL**: Security analysis and vulnerability detection
- **ShellCheck**: Shell script linting and validation

### Build Configurations Tested
The CI/CD pipeline automatically tests these combinations:
- Default build
- Performance build (O3 optimizations + LTO)
- Debug build (debug symbols + O0)
- Warnings build (extra compiler warnings)
- Performance + Warnings
- Debug + Warnings
- Tests build (with test suite)
- Performance + Tests
- Debug + Tests
- Warnings + Tests
- Performance + Warnings + Tests
- Debug + Warnings + Tests

### Quality Assurance
- All builds are tested for functionality and binary characteristics
- Debug builds are verified to contain debug symbols
- Performance builds are verified to use O3 optimizations and LTO
- Test suites are automatically executed when built
- Cross-platform compatibility is verified across multiple distributions

---
**Note for Arch Linux/AUR users:** The `updpkgsums` tool (used for updating PKGBUILD checksums) is provided by the `pacman-contrib` package. Be sure to install it if you plan to maintain or update the PKGBUILD or use the AUR automation scripts.

For troubleshooting or advanced configuration, see the comments in `build.sh` or the CMakeLists.txt file. 