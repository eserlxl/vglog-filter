# aur-generator.sh: AUR Packaging Automation Script

`aur-generator.sh` is a utility script for automating the creation and maintenance of Arch Linux AUR packaging files for the vglog-filter project. It streamlines the process of generating tarballs, updating PKGBUILD and .SRCINFO files, and preparing the package for local testing or AUR submission.

## Overview
- **Location:** `aur/aur-generator.sh`
- **Purpose:** Automates tarball creation, PKGBUILD and .SRCINFO updates, and AUR packaging tasks for vglog-filter.
- **License:** GPLv3 or later (see LICENSE)

## Usage

```sh
./aur-generator.sh [local|aur|clean]
```

- `local`: Prepares PKGBUILD and .SRCINFO for local testing/installation.
- `aur`: Updates PKGBUILD and .SRCINFO for AUR submission, sets the source URL to the latest GitHub release tarball, updates checksums, and runs `makepkg`.
- `clean`: Cleans up generated files and directories in the `aur/` folder.

## How It Works
- Always creates a new source tarball from the project root, excluding build and VCS files.
- Copies and updates PKGBUILD and .SRCINFO from template files (`PKGBUILD.0`, `.SRCINFO.0`).
- For `aur` mode, updates the `source` line in PKGBUILD to point to the latest GitHub release and runs `updpkgsums` and `makepkg`.
- For `local` mode, prepares files for local installation/testing.
- For `clean` mode, removes generated files and build artifacts from the `aur/` directory.

## Requirements
- `updpkgsums` (from `pacman-contrib`)
- `makepkg`
- For AUR submission: ensure `.SRCINFO.0` and `PKGBUILD.0` templates are present in `aur/`

## Notes for AUR Maintainers
- Always update `PKGVER` and `PKGNAME` variables in the script as needed for new releases.
- The script expects template files (`PKGBUILD.0`, `.SRCINFO.0`) to exist and be up to date.
- The script will fail if required tools or templates are missing.

---
For more details, see the comments in `aur/aur-generator.sh` or the [BUILD.md](BUILD.md) documentation. 