# aur-generator.sh: AUR Packaging Automation Script

`aur-generator.sh` is a utility script for automating the creation and maintenance of Arch Linux AUR packaging files for the vglog-filter project. It streamlines the process of generating tarballs, updating PKGBUILD and .SRCINFO files, and preparing the package for local testing or AUR submission.

## Overview
- **Location:** `aur/aur-generator.sh`
- **Purpose:** Automates tarball creation, PKGBUILD and .SRCINFO updates, and AUR packaging tasks for vglog-filter.
- **License:** GPLv3 or later (see LICENSE)

## Usage

```sh
./aur-generator.sh [--no-color|-n] [local|aur|aur-git|clean|test] [--dry-run|-d]
```

- `local`: Prepares PKGBUILD and .SRCINFO for local testing/installation.
- `aur`: Updates PKGBUILD and .SRCINFO for AUR submission, sets the source URL to the latest GitHub release tarball, updates checksums, and runs `makepkg`. Signs the tarball with GPG (see GPG automation below). Can automatically upload missing assets to GitHub releases if GitHub CLI is installed.
- `aur-git`: Prepares PKGBUILD and .SRCINFO for a VCS (git tag) build, sets the source to the specified git tag, sets `sha256sums=('SKIP')`, adds `validpgpkeys`, and runs `makepkg`. Useful for testing or maintaining a `-git` AUR package.
- `clean`: Cleans up generated files and directories in the `aur/` folder.
- `test`: Runs all modes (local, aur, aur-git) in dry-run mode to check for errors and report results. Useful for verifying all modes work correctly without performing actual operations.
- `--no-color`, `-n`: Disables colored output (for accessibility or when redirecting output). You can also set the `NO_COLOR` environment variable to any value to disable color.
- `--dry-run`, `-d`: Runs all steps except the final `makepkg -si` (useful for CI/testing).

### Disabling Colored Output

You can disable colored output in two ways:

- By passing the `--no-color` or `-n` option:
  ```sh
  ./aur-generator.sh --no-color aur
  ```
- By setting the `NO_COLOR` environment variable to any value (including empty):
  ```sh
  NO_COLOR= ./aur-generator.sh aur
  ```
  This is useful for CI, automation, or when redirecting output to files.

### GPG Key Automation
- For `aur` mode, a GPG secret key is required to sign the release tarball.
- By default, the script will prompt you to select a GPG key from your available secret keys.
- **To skip the interactive menu and use a specific key, set the `GPG_KEY_ID` environment variable:**

  ```sh
  GPG_KEY_ID=ABCDEF ./aur-generator.sh aur
  ```
  Replace `ABCDEF` with your GPG key's ID or fingerprint. This is useful for automation or CI workflows.

### Test Mode
- The `test` mode runs all other modes (local, aur, aur-git) in dry-run mode to verify they work correctly.
- Each test runs in isolation with a clean environment (automatically runs clean before each test).
- Test mode handles GPG prompts by creating dummy signature files for testing purposes.
- Provides comprehensive error reporting and shows which tests passed or failed.
- Useful for CI/CD pipelines or verifying script functionality before actual use.

  ```sh
  ./aur-generator.sh test
  ```

### GitHub CLI Integration
- If GitHub CLI (`gh`) is installed, the script can automatically upload missing release assets to GitHub releases.
- When a release asset is not found, the script will offer to upload the tarball and signature automatically.
- **To skip the automatic upload prompt, set the `AUTO` environment variable:**

  ```sh
  AUTO=y ./aur-generator.sh aur
  ```
  This is useful for automation or CI workflows where you want to skip interactive prompts.
- If GitHub CLI is not installed, the script will provide clear instructions for manual upload.

## How It Works
- Always creates a new source tarball from the project root, excluding build and VCS files (except in `aur-git` mode).
- Copies and updates PKGBUILD from the template file (`PKGBUILD.0`).
- For `aur` mode, updates the `source` line in PKGBUILD to point to the latest GitHub release tarball and runs `updpkgsums` and `makepkg`. If the release asset is not found, tries a fallback URL with a 'v' prefix. If GitHub CLI is available, offers to automatically upload missing assets.
- For `aur-git` mode, updates the `source` line in PKGBUILD to use the git tag as the source, sets `sha256sums=('SKIP')`, and adds/updates `validpgpkeys`.
- For `test` mode, runs all other modes in dry-run mode with isolated environments, providing comprehensive error reporting and validation.
- For all modes except `clean`, generates `.SRCINFO` from the current PKGBUILD using `makepkg --printsrcinfo > .SRCINFO` (or `mksrcinfo`).
- For `clean` mode, removes generated files and build artifacts from the `aur/` directory.
- The `validpgpkeys` array is always present in `PKGBUILD.0` to ensure correct signature verification.

## Requirements
- `updpkgsums` (from `pacman-contrib`)
- `makepkg`
- For AUR submission: ensure `PKGBUILD.0` template is present in `aur/`
- For signing: a GPG secret key (see above for automation)
- For automatic asset upload: GitHub CLI (`gh`) - optional but recommended

## Notes for AUR Maintainers
- Always update `PKGVER` and `PKGNAME` variables in the script as needed for new releases.
- The script expects the template file (`PKGBUILD.0`) to exist and be up to date.
- The script will fail if required tools or the template are missing.
- For CI or automation, set `GPG_KEY_ID` to avoid interactive prompts.
- For CI or automation with automatic asset upload, set `AUTO=y` to skip upload prompts.
- Use `./aur-generator.sh test` to verify all modes work correctly before making changes or releases.

---
For more details, see the comments in `aur/aur-generator.sh` or the [BUILD.md](BUILD.md) documentation. 