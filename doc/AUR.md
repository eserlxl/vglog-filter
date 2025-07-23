# aur-generator.sh: AUR Packaging Automation Script

`aur-generator.sh` is a utility script for automating the creation and maintenance of Arch Linux AUR packaging files for the vglog-filter project. It streamlines the process of generating tarballs, updating PKGBUILD and .SRCINFO files, and preparing the package for local testing or AUR submission.

## Overview
- **Location:** `aur/aur-generator.sh`
- **Purpose:** Automates tarball creation, PKGBUILD and .SRCINFO updates, and AUR packaging tasks for vglog-filter.
- **License:** GPLv3 or later (see LICENSE)
- **Platform:** The script is designed for GNU/Linux environments and does not aim to support macOS/BSD. It requires GNU getopt (util-linux) and will not work with BSD/macOS getopt implementations.
- **Bash Version:** The script requires **Bash version 4 or newer**. It will exit with an error if run on an older version.
- **Tool Hints:** If a required tool is missing, the script will print a hint with an installation suggestion (e.g., pacman -S pacman-contrib for updpkgsums).

## Usage

```sh
./aur-generator.sh [OPTIONS] MODE
```

- To print a minimal usage line (for scripts/AUR helpers):
  ```sh
  ./aur-generator.sh --help
  # or
  ./aur-generator.sh -h
  ```
  This prints:
  ```
  Usage: aur-generator.sh [OPTIONS] MODE
  Modes: local | aur | aur-git | clean | test | lint
  ```

> **Note:** All flags/options must appear before the mode. For example: `./aur-generator.sh -n --dry-run aur`. Flags after the mode are not supported.
> 
> **Options are now parsed using getopt for unified short and long option support, improving robustness and maintainability.**

### Modes

- **`local`**: Build and install the package from a local tarball (for testing). Creates a tarball from the current git repository, updates PKGBUILD and .SRCINFO, and runs `makepkg -si`.
- **`aur`**: Prepare a release tarball, sign it with GPG, and update PKGBUILD for AUR upload. Sets the source URL to the latest GitHub release tarball, updates checksums, and optionally runs `makepkg -si`. Can automatically upload missing assets to GitHub releases if GitHub CLI is installed.
- **`aur-git`**: Generate a PKGBUILD for the -git (VCS) AUR package. Sets the source to the git repository, sets `sha256sums=('SKIP')`, adds `validpgpkeys`, and optionally runs `makepkg -si`. No tarball is created or signed.
- **`clean`**: Remove all generated files and directories in the `aur/` folder, including tarballs, signatures, PKGBUILD, .SRCINFO, and build artifacts.
- **`test`**: Run all modes (local, aur, aur-git) in dry-run mode to check for errors and report results. Useful for verifying all modes work correctly without performing actual operations.
- **`lint`**: Run `shellcheck` and `bash -n` on `aur-generator.sh` itself. This is a quick self-test/linting mode for CI or local development. Exits with nonzero status if any check fails. Example:
  ```sh
  ./aur-generator.sh lint
  ```
  This will run both tools and print a summary. If `shellcheck` is not installed, it will be skipped with a warning.

### Options

- **`--no-color`, `-n`**: Disable colored output (for accessibility or when redirecting output). You can also set the `NO_COLOR` environment variable to any value to disable color.
- **`--ascii-armor`, `-a`**: Use ASCII-armored signatures (.asc) instead of binary signatures (.sig) for GPG signing. Some AUR helpers (like aurutils) prefer ASCII-armored signatures.
- **`--dry-run`, `-d`**: Run all steps except the final `makepkg -si` (useful for CI/testing). Can also be enabled by setting the `DRY_RUN=1` environment variable.
- **`--help`, `-h`**: Print a minimal usage line and exit (no color, no extra text; suitable for scripts/AUR helpers).

> **Important:** All options/flags must be specified before the mode. For example:
> ```sh
> ./aur-generator.sh --no-color --ascii-armor --dry-run aur
> ./aur-generator.sh -n -a -d aur
> DRY_RUN=1 ./aur-generator.sh aur
> ```
> The following is **not** supported:
> ```sh
> ./aur-generator.sh aur --dry-run   # Not supported
> ```
> 
> **Options are parsed using getopt for unified short and long option support.**

### Disabling Colored Output

You can disable colored output in two ways:

- By passing the `--no-color` or `-n` option **before the mode**:
  ```sh
  ./aur-generator.sh --no-color aur
  ```
- By setting the `NO_COLOR` environment variable to any value (including empty):
  ```sh
  NO_COLOR= ./aur-generator.sh aur
  ```
  This is useful for CI, automation, or when redirecting output to files.

### ASCII-Armored Signatures

By default, the script creates binary GPG signatures (.sig files). Some AUR helpers and maintainers prefer ASCII-armored signatures (.asc files) for better compatibility and readability.

To use ASCII-armored signatures, add the `--ascii-armor` or `-a` option **before the mode**:

```sh
./aur-generator.sh --ascii-armor aur
```

This will:
- Use `gpg --armor --detach-sign` instead of `gpg --detach-sign`
- Create `.asc` files instead of `.sig` files
- Update all references to signature files in logs and messages
- Clean up both `.sig` and `.asc` files when using the `clean` mode

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

### CI/Automation Support

- Set `CI=1` to skip interactive prompts in `aur` mode (automatically skips `makepkg -si` prompt).
- Set `AUTO=y` to skip the GitHub asset upload prompt.
- Set `GPG_KEY_ID` to avoid GPG key selection prompts.
- Use `--dry-run` to test without installing packages (must be before the mode).

> **Prompt Skipping in CI:**
> When `CI=1` is set, all interactive prompts are skipped. If a prompt has a default value, it is automatically selected. If no default is provided, the prompt is skipped and the function returns a non-zero exit code (1), which may be checked by the script to determine how to proceed. This shortcut is relied upon in some automation code paths.

### Environment Variables

The script supports several environment variables for automation:

- **`NO_COLOR`**: Set to any value to disable colored output (alternative to `--no-color` option)
- **`GPG_KEY_ID`**: Set to your GPG key ID to skip the interactive key selection menu
- **`AUTO`**: Skip the GitHub asset upload prompt in `aur` mode
- **`CI`**: Skip interactive prompts in `aur` mode (useful for CI/CD pipelines)
- **`DRY_RUN`**: Set to `1` to enable dry-run mode (alternative to `--dry-run`/`-d` flag)

## Variable Naming Conventions

- Local, mutable variables use lowercase (e.g., `dry_run`, `ascii_armor`, `color_enabled`).
- ALL-CAPS is reserved for readonly constants and exported variables (e.g., `PKGNAME`, `PROJECT_ROOT`).
- This helps quickly distinguish between constants/globals and local, mutable state.

## How It Works

### Tarball Creation
- Creates a new source tarball from the project root using `git archive`, excluding build and VCS files (except in `aur-git` mode).
- Uses `git archive` to respect `.gitignore` and only include tracked files.
- **Reproducibility:** Sets the tarball modification time (mtime) to a fixed date (2020-01-01) for reproducible builds. This ensures that repeated builds produce identical tarballs, regardless of when the script is run. (See [reproducible-builds.org](https://reproducible-builds.org/docs/source-date-epoch/))
- **Note:** `git archive` does _not_ include the contents of git submodules. If you ever add submodules to this project, the generated tarball will _not_ contain their files—only the main repository's files. You will need to update the packaging process to include submodule contents if submodules are introduced. See the [git-archive documentation](https://git-scm.com/docs/git-archive#_limitations) for details.

### PKGBUILD Generation
- Copies and updates PKGBUILD from the template file (`PKGBUILD.0`).
- Extracts `pkgver` from `PKGBUILD.0` using `awk` without sourcing the file.
- For `aur` mode: Updates the `source` line to point to the GitHub release tarball, tries both with and without 'v' prefix.
- For `aur-git` mode: Updates the `source` line to use the git repository, sets `sha256sums=('SKIP')`, and adds `validpgpkeys`.

### Checksums and .SRCINFO
- For `aur` and `local` modes: Runs `updpkgsums` to update checksums and generates `.SRCINFO`.
- For `aur-git` mode: Skips `updpkgsums` and sets `sha256sums=('SKIP')` (required for VCS packages).
- Uses `makepkg --printsrcinfo` (or `mksrcinfo` as fallback) to generate `.SRCINFO`.

> **Note for maintainers:**
> If you ever split sources by architecture (e.g., x86_64, aarch64), you must update the corresponding `b2sums_x86_64=()`, `b2sums_aarch64=()`, etc., arrays in addition to the generic `b2sums=()`. This script uses `b2sums` (BLAKE2) for checksums, not `sha256sums`. Adjust accordingly if you change the checksum type.

### GPG Signing (aur mode only)
- Checks for available GPG secret keys.
- Prompts for key selection or uses `GPG_KEY_ID` environment variable.
- Creates detached signature for the tarball (binary .sig by default, ASCII-armored .asc with `--ascii-armor`).
- In test mode, creates dummy signature files.

### GitHub Asset Upload
- Checks if release assets exist on GitHub.
- If not found and GitHub CLI is available, offers automatic upload.
- Uploads both tarball and signature files.
- Verifies upload success before proceeding.

### Installation
- For `aur` mode: Prompts before running `makepkg -si` (unless `CI=1` or `AUTO=y`).
- For other modes: Automatically runs `makepkg -si`.
- Respects `--dry-run` flag to skip installation (must be before the mode).

## Requirements

### Required Tools
- `bash` **version 4 or newer** (the script will exit with an error if run on Bash 3 or earlier)
- `makepkg` (from `pacman`)
- `updpkgsums` (from `pacman-contrib`)
- `curl` (for checking GitHub assets)
- `getopt` (GNU version from util-linux; the script will not work with BSD/macOS getopt)
- **Tool Hints:** If a required tool is missing, the script will print a hint with an installation suggestion (e.g., pacman -S pacman-contrib for updpkgsums).

> **Warning:** `pacman-contrib` is not included in the `base-devel` group on Arch Linux. You must install it separately, or you will get a `updpkgsums: command not found` error when building or packaging.

### Optional Tools
- `gpg` (required for `aur` mode signing)
- `gh` (GitHub CLI, for automatic asset upload)

### Files
- `PKGBUILD.0` template file in `aur/` directory

## Notes for AUR Maintainers

- Always update `PKGVER` in `PKGBUILD.0` for new releases.
- The script expects `PKGBUILD.0` to exist and be up to date.
- The script will fail if required tools or the template are missing.
- For CI or automation, set `GPG_KEY_ID` to avoid interactive prompts.
- For CI or automation with automatic asset upload, set `AUTO=y` to skip upload prompts.
- For CI environments, set `CI=1` to skip all interactive prompts.
- Use `./aur-generator.sh test` to verify all modes work correctly before making changes or releases.
- The script automatically handles both 'v' and non-'v' prefixed GitHub release URLs.
- VCS packages (`aur-git` mode) automatically set `sha256sums=('SKIP')` and add `validpgpkeys`.
- All environment variables are documented in the script's usage function (`./aur-generator.sh` without arguments).
- Use `--ascii-armor` or `-a` to create ASCII-armored signatures (.asc) instead of binary signatures (.sig) for better compatibility with some AUR helpers (must be before the mode).

## Error Handling

- Comprehensive error checking for missing tools, files, and GPG keys.
- Graceful fallback for GitHub asset URLs (tries both with and without 'v' prefix).
- Clear error messages with actionable instructions.
- Test mode provides detailed error reporting for all modes.

---
For more details, see the comments in `aur/aur-generator.sh` or the [BUILD.md](BUILD.md) documentation.