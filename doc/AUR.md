# aur-generator.sh: AUR Packaging Automation Script

`aur-generator.sh` is a utility script for automating the creation and maintenance of Arch Linux AUR packaging files for the vglog-filter project. It streamlines the process of generating tarballs, updating PKGBUILD and .SRCINFO files, and preparing the package for local testing or AUR submission.

## Overview
- **Location:** `aur/aur-generator.sh`
- **Purpose:** Automates tarball creation, PKGBUILD and .SRCINFO updates, and AUR packaging tasks for vglog-filter.
- **License:** GPLv3 or later (see LICENSE)

## Usage

```sh
./aur-generator.sh [local|aur|aur-git|clean]
```

- `local`: Prepares PKGBUILD and .SRCINFO for local testing/installation.
- `aur`: Updates PKGBUILD and .SRCINFO for AUR submission, sets the source URL to the latest GitHub release tarball, updates checksums, and runs `makepkg`. Signs the tarball with GPG (see GPG automation below).
- `aur-git`: Prepares PKGBUILD and .SRCINFO for a VCS (git tag) build, sets the source to the specified git tag, sets `sha256sums=('SKIP')`, adds `validpgpkeys`, and runs `makepkg`. Useful for testing or maintaining a `-git` AUR package.
- `clean`: Cleans up generated files and directories in the `aur/` folder.

### GPG Key Automation
- For `aur` mode, a GPG secret key is required to sign the release tarball.
- By default, the script will prompt you to select a GPG key from your available secret keys.
- **To skip the interactive menu and use a specific key, set the `GPG_KEY_ID` environment variable:**

  ```sh
  GPG_KEY_ID=ABCDEF ./aur-generator.sh aur
  ```
  Replace `ABCDEF` with your GPG key's ID or fingerprint. This is useful for automation or CI workflows.

## How It Works
- Always creates a new source tarball from the project root, excluding build and VCS files (except in `aur-git` mode).
- Copies and updates PKGBUILD from the template file (`PKGBUILD.0`).
- For `aur` mode, updates the `source` line in PKGBUILD to point to the latest GitHub release tarball and runs `updpkgsums` and `makepkg`. If the release asset is not found, tries a fallback URL with a 'v' prefix.
- For `aur-git` mode, updates the `source` line in PKGBUILD to use the git tag as the source, sets `sha256sums=('SKIP')`, and adds/updates `validpgpkeys`.
- For all modes except `clean`, generates `.SRCINFO` from the current PKGBUILD using `makepkg --printsrcinfo > .SRCINFO` (or `mksrcinfo`).
- For `clean` mode, removes generated files and build artifacts from the `aur/` directory.
- The `validpgpkeys` array is always present in `PKGBUILD.0` to ensure correct signature verification.

## Requirements
- `updpkgsums` (from `pacman-contrib`)
- `makepkg`
- For AUR submission: ensure `PKGBUILD.0` template is present in `aur/`
- For signing: a GPG secret key (see above for automation)

## Notes for AUR Maintainers
- Always update `PKGVER` and `PKGNAME` variables in the script as needed for new releases.
- The script expects the template file (`PKGBUILD.0`) to exist and be up to date.
- The script will fail if required tools or the template are missing.
- For CI or automation, set `GPG_KEY_ID` to avoid interactive prompts.

---
For more details, see the comments in `aur/aur-generator.sh` or the [BUILD.md](BUILD.md) documentation. 