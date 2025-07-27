# Building vglog-filter

The `build.sh` script automates the configuration and compilation of the vglog-filter project using CMake and Make.

## Usage

```sh
./build.sh [performance] [warnings] [debug] [clean]
```

You can provide one or more of the following options:

| Option        | Description                                                      |
|---------------|------------------------------------------------------------------|
| `performance` | Enables performance optimizations (disables debug mode if both are set) |
| `warnings`    | Enables extra compiler warnings                                  |
| `debug`       | Enables debug mode (disables performance mode if both are set)   |
| `clean`       | Forces a clean build (removes all build artifacts)               |

- `performance` and `debug` are **mutually exclusive**. If both are specified, `debug` takes precedence and disables `performance`.
- `warnings` and `clean` can be combined with any mode.
- `clean` is useful for configuration changes or debugging build issues.

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

## What the Script Does
- Creates a `build/` directory if it does not exist.
- Runs CMake with the selected options as variables.
- If `clean` is specified, runs `make clean` to remove all build artifacts.
- Builds the project using `make -j20` for fast parallel compilation.

## Output
- The compiled binary and build artifacts will be placed in the `build/` directory.

---
**Note for Arch Linux/AUR users:** The `updpkgsums` tool (used for updating PKGBUILD checksums) is provided by the `pacman-contrib` package. Be sure to install it if you plan to maintain or update the PKGBUILD or use the AUR automation scripts.

For troubleshooting or advanced configuration, see the comments in `build.sh` or the CMakeLists.txt file. 