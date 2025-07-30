# Building vglog-filter

The `build.sh` script automates the configuration and compilation of the vglog-filter project using CMake and Make.

## Usage

```sh
./build.sh [performance] [warnings] [debug] [clean] [tests] [-j N] [--build-dir DIR]
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
- If `clean` is specified, removes the build directory for a truly clean build.
- Builds the project using parallel compilation for fast builds.
- If `tests` is specified, builds and runs the test suite with automatic cleanup.
- Validates command-line arguments and provides helpful warnings for unknown options.
- Supports all build configuration combinations for comprehensive testing.

## Performance Features
The built executable includes several performance optimizations:
- **Automatic large file detection**: Files >5MB automatically use stream processing
- **Memory optimization**: Vector capacity reservation and efficient string operations
- **Regex optimization**: All patterns use `std::regex::optimize` for better performance
- **Smart processing**: Optimal mode selection based on file size
- **Modern C++ optimizations**: Uses `std::string_view`, `std::span`, and optimized patterns

## Output
- The compiled binary and build artifacts will be placed in the `build/` directory.
- Binary location: `build/bin/vglog-filter` (or `build/bin/Debug/vglog-filter` for debug builds)

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

## System Requirements

### Prerequisites
- **CMake**: Version 3.16 or newer
- **C++ Compiler**: C++20-compatible compiler (GCC 10+ or Clang 10+)
- **Build Tools**: Standard build tools (make, etc.)

### Installation (Arch Linux)
```sh
sudo pacman -S base-devel cmake gcc
```

### Installation (Ubuntu/Debian)
```sh
sudo apt-get install build-essential cmake
```

### Installation (Fedora)
```sh
sudo dnf install gcc-c++ cmake make
```

## Build Options

### CMake Options
The build script configures these CMake options:

| Option | Description | Default |
|--------|-------------|---------|
| `PERFORMANCE_BUILD` | Enable performance optimizations | OFF |
| `WARNING_MODE` | Enable extra compiler warnings | OFF |
| `DEBUG_MODE` | Enable debug mode | OFF |
| `BUILD_TESTING` | Build and enable tests | OFF (unless `tests` specified) |
| `ENABLE_NATIVE_OPTIMIZATION` | Use -march=native/-mtune=native | OFF |
| `ENABLE_SANITIZERS` | Enable Address/Undefined sanitizers | OFF |

### Compiler Flags
Different build modes use different compiler flags:

#### Performance Build
- `-O3`: Maximum optimization
- `-march=native -mtune=native`: Architecture-specific optimizations (if enabled)
- `-flto`: Link-time optimization
- `-DNDEBUG`: Disable debug assertions

#### Debug Build
- `-O0`: No optimization
- `-g`: Debug symbols
- `-fno-omit-frame-pointer`: Better stack traces
- `-DDEBUG`: Enable debug assertions
- `-fsanitize=address,undefined`: Memory and undefined behavior sanitizers (if enabled)

#### Warnings Build
- `-Wall -Wextra -Wpedantic`: Extra warnings
- `-Wconversion -Wshadow`: Additional warning flags
- `-Wnon-virtual-dtor -Wold-style-cast`: C++ specific warnings

## Troubleshooting

### Common Issues

#### CMake Version Too Old
```
Error: CMake 3.16 or newer is required
```
**Solution**: Update CMake to version 3.16 or newer.

#### Compiler Not C++20 Compatible
```
Error: C++20 standard not supported
```
**Solution**: Update to GCC 10+ or Clang 10+.

#### Missing Dependencies
```
Error: Required package not found
```
**Solution**: Install build essentials and CMake for your distribution.

#### Permission Issues
```
Error: Permission denied
```
**Solution**: Check file permissions and ownership.

### Build Debugging

#### Verbose Build Output
```sh
# Enable verbose output
./build.sh debug 2>&1 | tee build.log
```

#### Clean Build
```sh
# Force clean build
./build.sh clean debug
```

#### Manual CMake Configuration
```sh
# Manual configuration for debugging
mkdir build-debug
cd build-debug
cmake .. -DDEBUG_MODE=ON -DWARNING_MODE=ON
make VERBOSE=1
```

## Performance Considerations

### Build Performance
- **Parallel builds**: Uses `make -j20` for fast compilation
- **Incremental builds**: Only rebuilds changed files
- **Clean builds**: Use `clean` option when configuration changes

### Runtime Performance
- **Optimized builds**: Performance builds use maximum optimizations
- **LTO**: Link-time optimization for better performance
- **Native optimization**: Architecture-specific optimizations when enabled

## Development Workflow

### Typical Development Cycle
```sh
# Initial build
./build.sh debug warnings

# Make changes to source code

# Rebuild and test
./build.sh tests debug warnings

# Performance build for testing
./build.sh performance tests
```

### Testing Before Committing
```sh
# Run all tests
./build.sh tests

# Run with different configurations
./build.sh tests debug warnings
./build.sh tests performance warnings
```

---
**Note for Arch Linux/AUR users:** The `updpkgsums` tool (used for updating PKGBUILD checksums) is provided by the `pacman-contrib` package. Be sure to install it if you plan to maintain or update the PKGBUILD or use the AUR automation scripts.

For troubleshooting or advanced configuration, see the comments in `build.sh` or the CMakeLists.txt file. 