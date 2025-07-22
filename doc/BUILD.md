# Building vglog-filter

The `build.sh` script automates the configuration and compilation of the vglog-filter project using CMake and Make.

## Usage

```sh
./build.sh [performance] [warnings] [debug]
```

You can provide one or more of the following options:

| Option        | Description                                                      |
|---------------|------------------------------------------------------------------|
| `performance` | Enables performance optimizations (disables debug mode if both are set) |
| `warnings`    | Enables extra compiler warnings                                  |
| `debug`       | Enables debug mode (disables performance mode if both are set)   |

- `performance` and `debug` are **mutually exclusive**. If both are specified, `debug` takes precedence and disables `performance`.
- `warnings` can be combined with either mode.

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

## What the Script Does
- Creates a `build/` directory if it does not exist.
- Runs CMake with the selected options as variables.
- Builds the project using `make -j20` for fast parallel compilation.

## Output
- The compiled binary and build artifacts will be placed in the `build/` directory.

---
**Note for Arch Linux/AUR users:** The `updpkgsums` tool (used for updating PKGBUILD checksums) is provided by the `pacman-contrib` package. Be sure to install it if you plan to maintain or update the PKGBUILD or use the AUR automation scripts.

For troubleshooting or advanced configuration, see the comments in `build.sh` or the CMakeLists.txt file. 