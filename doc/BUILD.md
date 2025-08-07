# Build Guide

This guide provides comprehensive instructions for building `vglog-filter` from source. It covers prerequisites, standard build procedures, and advanced build configurations.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Standard Build](#standard-build)
- [Build Types](#build-types)
  - [Debug Build](#debug-build)
  - [Release Build](#release-build)
  - [Sanitized Builds](#sanitized-builds)
- [Advanced Build Options](#advanced-build-options)
- [Cross-Compilation](#cross-compilation)
- [Troubleshooting Build Issues](#troubleshooting-build-issues)

## Prerequisites

Before you can build `vglog-filter`, ensure you have the following tools installed on your system:

-   **C++20 Compatible Compiler**: A compiler that supports the C++20 standard. Recommended compilers:
    -   GCC (GNU Compiler Collection) version 10 or newer.
    -   Clang (LLVM) version 12 or newer.
    -   MSVC 2019 or newer (Windows).
-   **CMake**: A cross-platform build system generator. Version 3.16 or higher is required.
-   **Make or Ninja**: Build system for compilation.

### Installing Dependencies

**For Debian/Ubuntu-based systems:**

```sh
sudo apt-get update
sudo apt-get install build-essential cmake
```

**For Arch Linux-based systems:**

```sh
sudo pacman -S base-devel cmake gcc
```

**For macOS (using Homebrew):**

```sh
brew install cmake gcc
```

> **Note**: This project is primarily designed for Linux systems. While macOS support is available, some features may have limitations.

**For Windows (using MSYS2 or WSL):**

It is recommended to use Windows Subsystem for Linux (WSL) or MSYS2 to build `vglog-filter` on Windows, as the build process is designed for a Unix-like environment. Follow the Linux instructions within your WSL environment or install `mingw-w64-x86_64-toolchain` and `cmake` in MSYS2.

[↑ Back to top](#build-guide)

## Standard Build

The simplest way to build `vglog-filter` is by using the provided `build.sh` script. This script automates the CMake configuration and compilation process.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/eserlxl/vglog-filter.git
    cd vglog-filter
    ```
2.  **Run the build script:**
    ```sh
    ./build.sh
    ```

Upon successful completion, the `vglog-filter` executable will be located in the `build/bin/` directory.

### `build.sh` Options

The `build.sh` script accepts several arguments to customize the build process:

-   `performance`: Enables performance optimizations (`-O3`, LTO, etc.).
-   `debug`: Creates a debug build with symbols and no optimizations.
-   `warnings`: Enables extra compiler warnings.
-   `tests`: Builds and runs the test suite.
-   `clean`: Removes the build directory before building.
-   `--build-dir <dir>`: Specifies a custom build directory.
-   `-j <N>`: Sets the number of parallel jobs for compilation (default: 20).

**Examples:**

```sh
# Performance build with tests
./build.sh performance tests

# Debug build with extra warnings
./build.sh debug warnings

# Clean build with custom directory
./build.sh clean --build-dir my-build

# Parallel build with 8 jobs
./build.sh -j 8
```

For more details, run `./build.sh --help`.

[↑ Back to top](#build-guide)

## Build Types

The build system supports different build types, each optimized for specific purposes (e.g., debugging, performance). You can specify the build type using the `build.sh` script options.

### Debug Build

A debug build includes debugging symbols and disables optimizations, making it easier to step through code with a debugger and identify issues.

To create a debug build:

```sh
./build.sh debug
```

The executable will be located at `build/bin/vglog-filter`.

**Debug Build Features:**
- Compiler optimizations disabled (`-O0`)
- Debug symbols enabled (`-g`)
- Frame pointer preserved for better stack traces
- `DEBUG` macro defined
- Optional sanitizer support when `ENABLE_SANITIZERS=ON`

[↑ Back to top](#build-guide)

### Release Build

A release build is optimized for performance and size. It typically includes compiler optimizations and excludes debugging symbols.

This is the default build type when using `./build.sh`.

To explicitly create a release build:

```sh
./build.sh performance
```

The executable will be located at `build/bin/vglog-filter`.

**Release Build Features:**
- Maximum optimization (`-O3`)
- Link-time optimization (LTO) when supported
- `NDEBUG` macro defined
- `_FORTIFY_SOURCE=2` for additional security checks
- Optional native CPU optimization with `ENABLE_NATIVE_OPTIMIZATION`

[↑ Back to top](#build-guide)

### Sanitized Builds

`vglog-filter` supports various sanitizers to help detect runtime errors. These are crucial for ensuring code quality and stability.

#### Using build.sh with Sanitizers

The build script supports sanitizers through the `ENABLE_SANITIZERS` CMake option:

```sh
# Debug build with sanitizers
ENABLE_SANITIZERS=ON ./build.sh debug

# Or set the environment variable
export ENABLE_SANITIZERS=ON
./build.sh debug
```

#### Manual Sanitizer Builds

For more control, you can create sanitized builds manually:

-   **AddressSanitizer (ASan)**: Detects memory errors like use-after-free, double-free, and out-of-bounds access.
    ```sh
    mkdir -p build-asan
    cd build-asan
    cmake .. -DDEBUG_MODE=ON -DENABLE_SANITIZERS=ON
    cmake --build . -j20
    ```

-   **MemorySanitizer (MSan)**: Detects uses of uninitialized memory. Requires Clang.
    ```sh
    mkdir -p build-msan
    cd build-msan
    cmake .. -DDEBUG_MODE=ON -DENABLE_SANITIZERS=ON -DCMAKE_CXX_COMPILER=clang++
    cmake --build . -j20
    ```

-   **UndefinedBehaviorSanitizer (UBSan)**: Detects various kinds of undefined behavior.
    ```sh
    mkdir -p build-ubsan
    cd build-ubsan
    cmake .. -DDEBUG_MODE=ON -DENABLE_SANITIZERS=ON
    cmake --build . -j20
    ```

**Note**: Sanitized builds should typically be `Debug` builds to ensure all checks are active and debugging symbols are available. Running tests with sanitized builds is highly recommended to catch issues early. The CI/CD pipeline includes dedicated jobs for sanitized builds.

[↑ Back to top](#build-guide)

## Advanced Build Options

### CMake Configuration Options

The build system supports several advanced configuration options:

-   `DEBUG_MODE`: Enable debug build flags (mutually exclusive with `PERFORMANCE_BUILD`)
-   `PERFORMANCE_BUILD`: Enable performance-optimized flags (default: ON, mutually exclusive with `DEBUG_MODE`)
-   `WARNING_MODE`: Enable extra compiler warnings (default: ON)
-   `BUILD_TESTING`: Enable test suite compilation (default: ON)
-   `ENABLE_NATIVE_OPTIMIZATION`: Use `-march=native` and `-mtune=native` for CPU-specific optimizations
-   `ENABLE_SANITIZERS`: Enable AddressSanitizer and UndefinedBehaviorSanitizer in debug builds

**Example with advanced options:**

```sh
mkdir -p build-advanced
cd build-advanced
cmake .. \
  -DPERFORMANCE_BUILD=ON \
  -DENABLE_NATIVE_OPTIMIZATION=ON \
  -DWARNING_MODE=ON
cmake --build . -j20
```

### Environment Variables

You can control the build process using environment variables:

-   `BUILD_DIR`: Set the build directory (default: `build`)
-   `JOBS`: Set the number of parallel build jobs (default: 20)
-   `CMAKE_GENERATOR`: Specify the CMake generator (e.g., `Ninja`, `Unix Makefiles`)

**Example:**

```sh
export BUILD_DIR=my-custom-build
export JOBS=16
export CMAKE_GENERATOR=Ninja
./build.sh performance
```

[↑ Back to top](#build-guide)

## Cross-Compilation

Cross-compilation allows you to build `vglog-filter` for a different target platform than the one you are building on (e.g., building a Linux executable on macOS). This typically involves using a CMake toolchain file.

**General Steps for Cross-Compilation:**

1.  **Install a cross-compiler toolchain** for your target platform.
2.  **Create a CMake toolchain file** (`toolchain.cmake`) that specifies the cross-compiler, target architecture, and sysroot.

    Example `toolchain.cmake` for ARM Linux:
    ```cmake
    set(CMAKE_SYSTEM_NAME Linux)
    set(CMAKE_SYSTEM_PROCESSOR arm)

    set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)
    set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)

    set(CMAKE_FIND_ROOT_PATH /path/to/arm-linux-gnueabihf-sysroot)
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
    ```

3.  **Configure CMake with the toolchain file:**
    ```sh
    mkdir -p build-cross
    cd build-cross
    cmake .. -DCMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake -DPERFORMANCE_BUILD=ON
    cmake --build . -j20
    ```

Cross-compilation can be complex and depends heavily on your specific target environment. Refer to CMake's official documentation on [toolchain files](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html) for more in-depth information.

[↑ Back to top](#build-guide)

## Troubleshooting Build Issues

If you encounter problems during the build process, consider the following:

-   **Missing Prerequisites**: Double-check that all [prerequisites](#prerequisites) are installed and accessible in your system's PATH.

-   **Compiler Version**: Ensure your C++ compiler supports C++20. You can check your GCC version with `g++ --version` or Clang version with `clang++ --version`.

-   **CMake Version**: Verify your CMake version with `cmake --version`. If it's older than 3.16, you'll need to update it.

-   **Clean Build**: Sometimes, old build artifacts can cause issues. Try cleaning your build directory and recompiling:
    ```sh
    ./build.sh clean
    ```

-   **Parallel Build Issues**: If you encounter issues with parallel builds, try reducing the number of jobs:
    ```sh
    ./build.sh -j 1
    ```

-   **Sanitizer Issues**: If sanitizers cause build failures, ensure you're using a compatible compiler version and that the sanitizer libraries are properly installed.

-   **Error Messages**: Read the error messages carefully. They often provide clues about what went wrong (e.g., missing headers, undefined references).

-   **Consult CI/CD Workflows**: The project's GitHub Actions workflows (`.github/workflows/`) provide working examples of how the project is built on various platforms and configurations. Reviewing these files can help you identify correct build commands and dependencies.

-   **Open an Issue**: If you're still stuck, please [open an issue](https://github.com/eserlxl/vglog-filter/issues) on the GitHub repository with details about your system, compiler, CMake version, and the full error output.

[↑ Back to top](#build-guide)
