# Build Guide

This guide provides comprehensive instructions for building `vglog-filter` from source. It covers prerequisites, standard build procedures, and advanced build configurations.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Standard Build](#standard-build)
- [Build Types](#build-types)
  - [Debug Build](#debug-build)
  - [Release Build](#release-build)
  - [Sanitized Builds](#sanitized-builds)
- [Cross-Compilation](#cross-compilation)
- [Troubleshooting Build Issues](#troubleshooting-build-issues)

## Prerequisites

Before you can build `vglog-filter`, ensure you have the following tools installed on your system:

-   **C++20 Compatible Compiler**: A compiler that supports the C++20 standard. Recommended compilers:
    -   GCC (GNU Compiler Collection) version 10 or newer.
    -   Clang (LLVM) version 12 or newer.
-   **CMake**: A cross-platform build system generator. Version 3.16 or higher is required.

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

**For Windows (using MSYS2 or WSL):**

It is recommended to use Windows Subsystem for Linux (WSL) or MSYS2 to build `vglog-filter` on Windows, as the build process is designed for a Unix-like environment. Follow the Linux instructions within your WSL environment or install `mingw-w64-x86_64-toolchain` and `cmake` in MSYS2.

[↑ Back to top](#build-guide)

## Standard Build

The simplest way to build `vglog-filter` is by using the provided `build.sh` script. This script automates the CMake configuration and compilation process for a standard release build.

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

### What `build.sh` does:

The `build.sh` script performs the following steps:

```sh
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

-   `mkdir -p build`: Creates a `build` directory if it doesn't already exist. This is where all build artifacts will be placed.
-   `cd build`: Changes the current directory to `build`.
-   `cmake .. -DCMAKE_BUILD_TYPE=Release`: Configures the project using CMake. `-DCMAKE_BUILD_TYPE=Release` sets the build type to `Release`, which enables optimizations and disables debugging symbols.
-   `cmake --build .`: Compiles the project using the generated build system (e.g., Makefiles on Unix-like systems, Visual Studio solutions on Windows).

[↑ Back to top](#build-guide)

## Build Types

CMake supports different build types, each optimized for specific purposes (e.g., debugging, performance). You can specify the build type using the `-DCMAKE_BUILD_TYPE` flag during the CMake configuration step.

### Debug Build

A debug build includes debugging symbols and disables optimizations, making it easier to step through code with a debugger and identify issues.

To create a debug build:

```sh
mkdir -p build-debug
cd build-debug
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build .
```

The executable will be located at `build-debug/bin/vglog-filter`.

[↑ Back to top](#build-guide)

### Release Build

A release build is optimized for performance and size. It typically includes compiler optimizations and excludes debugging symbols.

This is the default build type when using `./build.sh`.

To explicitly create a release build:

```sh
mkdir -p build-release
cd build-release
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

The executable will be located at `build-release/bin/vglog-filter`.

[↑ Back to top](#build-guide)

### Sanitized Builds

`vglog-filter` supports various sanitizers (e.g., AddressSanitizer, MemorySanitizer, UndefinedBehaviorSanitizer) to help detect runtime errors. These are crucial for ensuring code quality and stability.

To enable a sanitizer, pass the appropriate CMake option:

-   **AddressSanitizer (ASan)**: Detects memory errors like use-after-free, double-free, and out-of-bounds access.
    ```sh
mkdir -p build-asan
cd build-asan
cmake .. -DCMAKE_BUILD_TYPE=Debug -DENABLE_ASAN=ON
cmake --build .
    ```

-   **MemorySanitizer (MSan)**: Detects uses of uninitialized memory. Requires Clang.
    ```sh
mkdir -p build-msan
cd build-msan
cmake .. -DCMAKE_BUILD_TYPE=Debug -DENABLE_MSAN=ON
cmake --build .
    ```

-   **UndefinedBehaviorSanitizer (UBSan)**: Detects various kinds of undefined behavior.
    ```sh
mkdir -p build-ubsan
cd build-ubsan
cmake .. -DCMAKE_BUILD_TYPE=Debug -DENABLE_UBSAN=ON
cmake --build .
    ```

**Note**: Sanitized builds should typically be `Debug` builds to ensure all checks are active and debugging symbols are available. Running tests with sanitized builds is highly recommended to catch issues early. The CI/CD pipeline includes dedicated jobs for sanitized builds.

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
    cmake .. -DCMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake -DCMAKE_BUILD_TYPE=Release
    cmake --build .
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
    rm -rf build*
    ./build.sh
    ```

-   **Error Messages**: Read the error messages carefully. They often provide clues about what went wrong (e.g., missing headers, undefined references).

-   **Consult CI/CD Workflows**: The project's GitHub Actions workflows (`.github/workflows/`) provide working examples of how the project is built on various platforms and configurations. Reviewing these files can help you identify correct build commands and dependencies.

-   **Open an Issue**: If you're still stuck, please [open an issue](https://github.com/eserlxl/vglog-filter/issues) on the GitHub repository with details about your system, compiler, CMake version, and the full error output.

[↑ Back to top](#build-guide)