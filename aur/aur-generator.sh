#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Modes summary:
#   local     - Build and install from a local tarball (for testing).
#   aur       - Prepare a signed release tarball and PKGBUILD for AUR upload.
#   aur-git   - Generate a PKGBUILD for the -git (VCS) AUR package.
#   clean     - Remove generated files and directories.
#   test      - Run all modes in dry-run mode and check for errors.
#   lint      - Run shellcheck and bash -n on this script for quick CI linting.
#   golden    - Regenerate golden PKGBUILD files for test fixtures.
# See 'doc/AUR.md' or run with --help for full details on each mode and workflow.
# NOTE: This script requires GNU getopt (util-linux) and is not compatible with macOS/BSD systems.
# The script is designed for GNU/Linux environments and does not aim to support macOS/BSD.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r PKGBUILD0="$SCRIPT_DIR/PKGBUILD.0"
declare -r OUTDIR="$SCRIPT_DIR"
declare -r PKGBUILD="$OUTDIR/PKGBUILD"
declare -r SRCINFO="$OUTDIR/.SRCINFO"
export PKGBUILD0 PKGBUILD SRCINFO OUTDIR

# --- Tiny Helper Functions (moved to top for trap consistency) ---
err() {
    (( color_enabled )) && printf '%b%s%b\n' "$RED" "$*" "$RESET" || printf '%s\n' "$*" >&2
    exit 1
}
warn() {
    (( color_enabled )) && printf '%b%s%b\n' "$YELLOW" "$*" "$RESET" || printf '%s\n' "$*"
}
log() {
    (( color_enabled )) && printf '%b%s%b\n' "$GREEN" "$*" "$RESET" || printf '%s\n' "$*"
}
gh_upload_or_exit() {
    local file="$1"
    local repo="$2"
    local tag="$3"
    if ! gh release upload "$tag" "$file" --repo "$repo" --clobber; then
        err "[aur] Failed to upload \"$file\" to GitHub release \"$tag\""
    fi
}
require() {
    local missing=()
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    if (( ${#missing[@]} )); then
        for tool in "${missing[@]}"; do
            hint "$tool"
        done
        err "Missing required tool(s): ${missing[*]}"
    fi
}
hint() {
    local tool="$1"
    local pkg="${PKG_HINT[$tool]:-}"
    if [[ -n "$pkg" ]]; then
        warn "[aur-generator] Hint: Install '$tool' with: sudo pacman -S $pkg"
    else
        warn "[aur-generator] Hint: Install '$tool' (no package hint available)"
    fi
}
prompt() {
    local msg="$1"; local __resultvar="$2"; local default="$3"
    if have_tty; then
        read -r -p "$msg" input
        if [[ -z "$input" && -n "$default" ]]; then
            input="$default"
        fi
        eval "$__resultvar=\"\$input\""
    else
        eval "$__resultvar=\"$default\""
    fi
}
asset_exists() {
    local url="$1"
    curl -I -L -f --silent "$url" > /dev/null
}
update_checksums() {
    if ! updpkgsums; then
        err "[aur-generator] updpkgsums failed."
    fi
}
generate_srcinfo() {
    if ! makepkg --printsrcinfo > "$SRCINFO"; then
        err "[aur-generator] makepkg --printsrcinfo failed."
    fi
}
install_pkg() {
    local mode="$1"
    if (( dry_run )); then
        log "[install_pkg] Dry run: skipping install for mode $mode."
        return
    fi
    case "$mode" in
        local)
            log "[install_pkg] Running makepkg -si for local install."
            makepkg -si
            ;;
        aur|aur-git)
            log "[install_pkg] PKGBUILD and .SRCINFO are ready for AUR upload."
            ;;
        *)
            warn "[install_pkg] Unknown mode: $mode"
            ;;
    esac
}
# Tool-to-package mapping for Arch Linux hints
# shellcheck disable=SC2034
# Associative array: tool name -> package name
# This is more maintainable than a case statement
#
declare -Ar PKG_HINT=(
    [updpkgsums]=pacman-contrib
    [makepkg]=base-devel
    [curl]=curl
    [gpg]=gnupg
    [gh]=github-cli
    [flock]=util-linux
    [awk]=gawk
    [git]=git
    [jq]=jq
)
# Trap errors and print a helpful message with line number and command
# set -E: Ensure ERR trap is inherited by functions and subshells (Bash >=4.4). For older Bash, enable errtrace explicitly.
set -E
set -o errtrace  # Ensure ERR trap is inherited by functions and subshells (for maximum compatibility)
trap 'err "[FATAL] ${BASH_SOURCE[0]}:$LINENO: $BASH_COMMAND"' ERR

# --- Constants (grouped at top, all readonly) ---
declare -r PKGNAME="vglog-filter"
SCRIPT_NAME="$(basename "$0")"
declare -r SCRIPT_NAME
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
declare -r PROJECT_ROOT
# Determine GH_USER: environment > PKGBUILD.0 url > fallback
if [[ -z "${GH_USER:-}" ]]; then
    PKGBUILD0_URL=$(awk -F/ '/^url="https:\/\/github.com\// {print $4}' "$SCRIPT_DIR/PKGBUILD.0")
    if [[ -n "$PKGBUILD0_URL" ]]; then
        GH_USER="${PKGBUILD0_URL%\"}"
    else
        GH_USER="eserlxl"
        # warn is not available yet, so use printf
        printf "[aur-generator] Could not parse GitHub user/org from PKGBUILD.0 url field, defaulting to 'eserlxl'.\n" >&2
    fi
fi
# Robustness: Detect if GH_USER is the same as PKGNAME (likely a mistake)
if [[ "$GH_USER" == "$PKGNAME" ]]; then
    echo "[aur-generator] ERROR: Detected GH_USER='$GH_USER' (same as PKGNAME). This usually means the url field in PKGBUILD.0 is wrong." >&2
    echo "[aur-generator] Please set the url field in PKGBUILD.0 to your real GitHub repo, e.g.:" >&2
    echo "[aur-generator]     url=\"https://github.com/<yourusername>/$PKGNAME\"" >&2
    echo "[aur-generator] Detected url line:" >&2
    grep '^url=' "$SCRIPT_DIR/PKGBUILD.0" >&2
    err "[aur-generator] Aborting due to invalid GH_USER configuration."
fi
declare -r GH_USER
declare -ar VALID_MODES=(local aur aur-git clean test lint golden)

# Require Bash >= 4 early, before using any Bash 4+ features
if ((BASH_VERSINFO[0] < 4)); then
    err "Bash ≥ 4 required" >&2
fi

# --- Color Setup ---
# Group color variable definitions and helpers at the top
init_colors() {
    # Color variables are initialized once here and memoized for all color_echo calls
    HAVE_TPUT=0
    if command -v tput >/dev/null 2>&1; then
        HAVE_TPUT=1
    fi
    if (( color_enabled )); then
        if (( HAVE_TPUT )) && [[ -t 1 ]]; then
            RED="$(tput setaf 1)$(tput bold)"
            GREEN="$(tput setaf 2)$(tput bold)"
            YELLOW="$(tput setaf 3)$(tput bold)"
            RESET="$(tput sgr0)"
        else
            if [[ -n "${BASH_VERSION:-}" ]]; then
                RED='\e[1;31m'
                GREEN='\e[1;32m'
                YELLOW='\e[1;33m'
                RESET='\e[0m'
            else
                RED='\033[1;31m'
                GREEN='\033[1;32m'
                YELLOW='\033[1;33m'
                RESET='\033[0m'
            fi
        fi
    else
        RED=''
        GREEN=''
        YELLOW=''
        RESET=''
    fi
}

# --- Cleanup lingering lock and generated files at script start or before modes ---
cleanup() {
    # Remove lock file
    rm -f "$SCRIPT_DIR/.aur-generator.lock"
    # Remove generated PKGBUILD files
    rm -f "$SCRIPT_DIR/PKGBUILD" "$SCRIPT_DIR/PKGBUILD.git"
    # Remove generated SRCINFO
    rm -f "$SCRIPT_DIR/.SRCINFO"
    # Remove any test or diff logs
    rm -f "$SCRIPT_DIR"/test-*.log
    rm -f "$SCRIPT_DIR"/diff-*.log
    # Remove any generated tarballs and signatures
    rm -f "$SCRIPT_DIR/${PKGNAME}-"*.tar.gz
    rm -f "$SCRIPT_DIR/${PKGNAME}-"*.tar.gz.sig
    rm -f "$SCRIPT_DIR/${PKGNAME}-"*.tar.gz.asc
    # Remove any generated package files
    rm -f "$SCRIPT_DIR"/*.pkg.tar.*
}

# Enable debug tracing if DEBUG=1
if [[ "${DEBUG:-0}" == 1 ]]; then
    set -x
fi

# Ensure GPG pinentry works in CI/sudo/non-interactive shells
GPG_TTY=$(tty)  # Needed for GPG signing to work reliably (pinentry) in CI/sudo
export GPG_TTY

# color_enabled is set from env or default, but will be overridden by CLI options below
set -euo pipefail
color_enabled=${COLOR:-1}  # safe default, must be set before any error handling
set -o noclobber  # Prevent accidental file overwrite with > redirection

# --- Functions ---
# Minimal help for scripts/AUR helpers
usage() {
    printf 'Usage: %s [OPTIONS] MODE\n' "$SCRIPT_NAME"
    printf 'Modes: local | aur | aur-git | clean | test | lint | golden\n'
    printf 'Options: --no-wait (skip post-upload wait, for CI/advanced users)\n'
}

# Helper to check for interactive terminal
have_tty() {
    [[ -t 0 ]]
}

# Function to check if a mode is valid
is_valid_mode() {
    local mode="$1"
    for valid_mode_name in "${VALID_MODES[@]}"; do
        if [[ "$mode" == "$valid_mode_name" ]]; then
            return 0
        fi
    done
    return 1
}

# Full usage (detailed help)
help() {
    usage
    printf '\n'
    printf 'Options:\n'
    printf '  -n, --no-color      Disable color output\n'
    printf '  -a, --ascii-armor   Use ASCII-armored GPG signatures (.asc)\n'
    printf '  -d, --dry-run       Dry run (no changes, for testing)\n'
    printf '  --no-wait           Skip post-upload wait for asset availability (for CI/advanced users, or set NO_WAIT=1)\n'
    printf '  -h, --help          Show detailed help and exit\n'
    printf '  --usage             Show minimal usage and exit\n'
    printf '\n'
    printf 'All options must appear before the mode.\n'
    printf 'For full documentation, see doc/AUR.md.\n'
    printf '\n'
    printf 'If a required tool is missing, a hint will be printed with an installation suggestion (e.g., pacman -S pacman-contrib for updpkgsums).\n'
    printf '\n'
    printf 'The lint mode runs shellcheck and bash -n on this script for quick CI/self-test.\n'
    printf '\n'
    printf 'The golden mode regenerates golden PKGBUILD files for test/fixtures/.\n'
}

# Helper to set signature extension and GPG armor option
set_signature_ext() {
    # Sets SIGNATURE_EXT and GPG_ARMOR_OPT globals based on ascii_armor
    if [[ ${ascii_armor:-0} -eq 1 ]]; then
        SIGNATURE_EXT=".asc"
        GPG_ARMOR_OPT="--armor"
    else
        SIGNATURE_EXT=".sig"
        GPG_ARMOR_OPT=""
    fi
}

# Helper to update the source array in PKGBUILD with a new tarball URL, preserving extra sources
update_source_array_in_pkgbuild() {
    local pkgbuild_file="$1"
    local tarball_url="$2"
    # Replace the entire source array with just the tarball URL
    awk -v newurl="$tarball_url" '
        BEGIN { in_source=0 }
        /^source=\(/ {
            in_source=1; print "source=(\"" newurl "\")"; next
        }
        in_source && /\)/ {
            in_source=0; next
        }
        in_source { next }
        { print $0 }
    ' "$pkgbuild_file" > "$pkgbuild_file.tmp" && mv "$pkgbuild_file.tmp" "$pkgbuild_file"
}

# --- Main Logic ---
# Initialize variables from environment or defaults before flag parsing
dry_run=${DRY_RUN:-0}
ascii_armor=${ASCII_ARMOR_DEFAULT:-0}
no_wait=0
# color_enabled=${COLOR:-1}  # <-- Remove this line, already set at top

# Use getopt for unified short and long option parsing
# This allows for robust handling of both short (-n) and long (--no-color) options
# IMPORTANT: Always check the exit code of getopt before using its output.
# If getopt fails (e.g., due to an unknown flag), set -e does not abort inside $(),
# so we must check the status explicitly to avoid silent bad-option handling.
# Temporarily disable ERR trap and set -e for getopt
# --- GNU getopt check (fail gracefully if not present) ---
if ! command -v getopt >/dev/null 2>&1; then
    err "GNU getopt required (util-linux)."
fi
# Check for GNU-style long option support
if ! output=$(getopt -o nadh --long test -- "Test" 2>/dev/null) || [[ "$output" != *"Test"* ]]; then
    err "GNU getopt required (util-linux)."
fi
# --- End GNU getopt check ---
# WARNING: The ERR trap is disabled below for getopt parsing. If you add code after getopt_output=... and before the trap is restored,
# errors will not trigger the custom ERR trap (though set -e is still active). If you add more code here, consider re-enabling the trap earlier.
trap - ERR
set +e
getopt_output=$(getopt --shell bash -o nadh --long no-color,ascii-armor,dry-run,help,usage,no-wait -- "$@")
getopt_status=$?
set -e
trap 'err "[FATAL] ${BASH_SOURCE[0]}:$LINENO: $BASH_COMMAND"' ERR
if (( getopt_status != 0 )); then
    printf 'Error: Failed to parse options.\n' >&2
    help
    exit 1
fi
# Use eval set -- for proper argument parsing from getopt output
# This handles quoted arguments correctly and avoids issues with array splitting
# See: https://mywiki.wooledge.org/BashFAQ/035
# shellcheck disable=SC2086
# (No longer using read/array idiom)
eval set -- "$getopt_output"
# Set color_enabled default from environment, will be overridden by CLI flags
# color_enabled=$([[ ${NO_COLOR:-0} == 1 ]] && echo 0 || echo "${COLOR:-1}")
while true; do
    case "$1" in
        -n|--no-color)
            color_enabled=0; shift ;;
        -a|--ascii-armor)
            ascii_armor=1; shift ;;
        -d|--dry-run)
            dry_run=1; shift ;;
        --no-wait)
            no_wait=1; shift ;;
        -h|--help)
            help; exit 0 ;;
        --usage)
            usage; exit 0 ;;
        --)
            shift; break ;;
        *)
            # shellcheck disable=SC2317
            err "Unknown option: $1"; 
            # shellcheck disable=SC2317
            help; 
            # shellcheck disable=SC2317
            exit 1 ;;
    esac
    # No need to call init_colors here
    # We'll call it once after all flags are parsed
    # This ensures color_enabled is set correctly
    # and color variables are initialized accordingly
    # (see below)
done
# Initialize color variables after color_enabled is set and CLI flags are parsed
init_colors  # Ensure color variables are initialized after all flags are parsed

MODE=${1:-}
if [[ -z $MODE ]]; then
    # shellcheck disable=SC2317
    usage
    # shellcheck disable=SC2317
    exit 1
fi

# Validate mode using is_valid_mode function
if ! is_valid_mode "$MODE"; then
    err "Unknown mode: $MODE"
    # shellcheck disable=SC2317
    usage
    # shellcheck disable=SC2317
    exit 1
fi

# --- Early dependency checks: fail fast if required tools are missing ---
case "$MODE" in
    local)
        # local mode requires: makepkg, updpkgsums, curl
        require makepkg updpkgsums curl || exit 1
        cleanup
        ;;
    aur)
        # aur mode requires: makepkg, updpkgsums, curl, gpg, jq
        require makepkg updpkgsums curl gpg jq || exit 1
        cleanup
        ;;
    aur-git)
        # aur-git mode requires: makepkg
        require makepkg || exit 1
        cleanup
        ;;
    lint)
        # lint mode requires: shellcheck, bash
        require shellcheck bash || exit 1
        ;;
    golden)
        # golden mode requires: makepkg, updpkgsums, curl, gpg, jq
        require makepkg updpkgsums curl gpg jq || exit 1
        ;;
    # clean and test modes do not require special tools
esac

log "Running in \"$MODE\" mode"
case "$MODE" in
    local)
        log "[local] Build and install from local tarball."
        cp -f "$PKGBUILD0" "$PKGBUILD"
        # require call moved above
        ;;
    aur)
        log "[aur] Prepare for AUR upload: creates tarball, GPG signature, and PKGBUILD for release."
        # require call moved above
        # Fail early in CI if AUTO=y but gh is not installed
        if [[ "${AUTO:-}" == "y" ]] && ! command -v gh >/dev/null 2>&1; then
            err "[aur] ERROR: AUTO=y is set but GitHub CLI (gh) is not installed. Cannot upload assets automatically in CI. Please install gh or unset AUTO."
            # shellcheck disable=SC2317
            exit 1
        fi
        # Check for optional GitHub CLI
        if ! command -v gh >/dev/null 2>&1; then
            warn "[aur] Note: GitHub CLI (gh) not found. Automatic asset upload will not be available."
        fi
        ;;
    aur-git)
        log "[aur-git] Prepare PKGBUILD for VCS (git) package. No tarball is created."
        # require call moved above
        ;;
    clean)
        log "[clean] Remove generated files and directories."
        # Clean mode does not require PKGVER or PKGBUILD0
        shopt -s nullglob
        # Create separate arrays for tarballs and signatures to avoid duplicate glob expansion
        TARBALLS=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz)
        SIGNATURES=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz.sig)
        ASC_SIGNATURES=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz.asc)
        # Combine arrays for removal
        files=("${TARBALLS[@]}" "${SIGNATURES[@]}" "${ASC_SIGNATURES[@]}")
        log "Cleaning AUR directory..."
        # rm -f -- "${files[@]}" is safe even if files is empty due to nullglob and the check above
        if (( ${#files[@]} )); then
            rm -f -- "${files[@]}"
        fi
        rm -f "$PKGBUILD" "$SRCINFO"
        # Remove all build directories matching ${PKGNAME}-* (for split package support)
        find "$SCRIPT_DIR" -maxdepth 1 -type d -name "${PKGNAME}-*" -exec rm -r {} +
        rm -f "$SCRIPT_DIR"/*.pkg.tar.*
        shopt -u nullglob
        log "Clean complete."
        exit 0
        ;;
    test)
        log "[test] Running all modes in dry-run mode to check for errors."
        log "[test] Cleaning up old test logs..."
        # cleanup_test_logs  # Removed: now called at script start
        log "[test] Old test logs removed."
        TEST_ERRORS=0
        # Run the test mode (rely only on --dry-run flag, do not export DRY_RUN)
        for test_mode in local aur aur-git; do
            log "--- Testing \"$test_mode\" mode ---"
            log "[test] Running clean before \"$test_mode\" test..."
            if ! bash "$SCRIPT_DIR/$SCRIPT_NAME" clean > /dev/null 2>&1; then
                warn "[test] Warning: Clean failed for \"$test_mode\" test, but continuing..."
            fi
            # Use a persistent log file in SCRIPT_DIR
            TEST_LOG_FILE="$SCRIPT_DIR/test-$test_mode-$(date +%s).log"
            # Save and restore CI to avoid leaking into nested calls
            _old_ci=${CI:-}
            export CI=1  # Skip prompts
            if [[ "$test_mode" == "aur" ]]; then
                export GPG_KEY_ID="TEST_KEY_FOR_DRY_RUN"
            fi
            if bash "$SCRIPT_DIR/$SCRIPT_NAME" --dry-run "$test_mode" >| "$TEST_LOG_FILE" 2>&1; then
                log "[test] ✓ $test_mode mode passed"
                # --- Begin golden PKGBUILD diff ---
                GOLDEN_FILE="$PROJECT_ROOT/test/fixtures/PKGBUILD.$test_mode.golden"
                GENERATED_PKG="$SCRIPT_DIR/PKGBUILD"
                if [[ -f "$GOLDEN_FILE" ]]; then
                    if ! diff -u <(tail -n +2 "$GOLDEN_FILE") "$GENERATED_PKG" > "$SCRIPT_DIR/diff-$test_mode.log"; then
                        err "[test] ✗ $test_mode PKGBUILD does not match golden file! See \"$SCRIPT_DIR/diff-$test_mode.log\""
                        # shellcheck disable=SC2317
                        cat "$SCRIPT_DIR/diff-$test_mode.log" >&2
                        # shellcheck disable=SC2317
                        TEST_ERRORS=$((TEST_ERRORS + 1))
                    else
                        log "[test] ✓ $test_mode PKGBUILD matches golden file."
                    fi
                else
                    warn "[test] Golden file \"$GOLDEN_FILE\" not found. Skipping PKGBUILD diff for \"$test_mode\"."
                fi
                # --- End golden PKGBUILD diff ---
            else
                err "[test] ✗ $test_mode mode failed"
                # shellcheck disable=SC2317
                TEST_ERRORS=$((TEST_ERRORS + 1))
                # shellcheck disable=SC2317
                warn "Error output for $test_mode is in: \"$TEST_LOG_FILE\""
                # shellcheck disable=SC2317
                cat "$TEST_LOG_FILE" >&2
            fi
            # Restore previous CI value
            if [[ -n $_old_ci ]]; then
                export CI="$_old_ci"
            else
                unset CI
            fi
            log "[test] Log for $test_mode: $TEST_LOG_FILE"
        done
        # Additional: Test invalid/nonsense command-line arguments
        log "[test] Running invalid argument tests..."
        INVALID_ARGS_LIST=(
            "-0"
            "-1"
            "--usagex"
            "-X"
            "-0 local"
            "-1 aur"
            "--usagex aur-git"
            "-X lint"
            "-n -0 local"
            "-a --usagex aur"
            "-d -X test"
            "-n -a -1"
            "--no-color --usagex"
            "-n -a -X lint"
            "-d --usagex test"
        )
        for invalid_args_str in "${INVALID_ARGS_LIST[@]}"; do
            # Convert the string to an array for safe argument passing
            read -r -a invalid_args <<< "$invalid_args_str"
            TEST_LOG_FILE="$SCRIPT_DIR/test-invalid-$(echo "$invalid_args_str" | tr ' /' '__').log"
            log "[test] Testing invalid args: $invalid_args_str"
            if bash "$SCRIPT_DIR/$SCRIPT_NAME" "${invalid_args[@]}" >"$TEST_LOG_FILE" 2>&1; then
                err "[test] ✗ Invalid args '$invalid_args_str' did NOT fail as expected!"
                # shellcheck disable=SC2317
                TEST_ERRORS=$((TEST_ERRORS + 1))
                # shellcheck disable=SC2317
                cat "$TEST_LOG_FILE" >&2
            else
                log "[test] ✓ Invalid args '$invalid_args_str' failed as expected."
            fi
            log "[test] Log for invalid args '$invalid_args_str': $TEST_LOG_FILE"
        done
        # Report results
        if [[ $TEST_ERRORS -eq 0 ]]; then
            log "[test] ✓ All test modes passed successfully!"
        else
            err "[test] ✗ $TEST_ERRORS test mode(s) failed"
            # shellcheck disable=SC2317
            exit 1
        fi
        exit 0
        ;;
    lint)
        log "[lint] Running shellcheck and bash -n on $SCRIPT_NAME."
        SHELLCHECK_OK=0
        BASHN_OK=0
        if command -v shellcheck >/dev/null 2>&1; then
            shellcheck "$SCRIPT_DIR/$SCRIPT_NAME" && SHELLCHECK_OK=1 || SHELLCHECK_OK=0
        else
            warn "[lint] shellcheck not found; skipping shellcheck."
            SHELLCHECK_OK=1
        fi
        bash -n "$SCRIPT_DIR/$SCRIPT_NAME" && BASHN_OK=1 || BASHN_OK=0
        if (( SHELLCHECK_OK && BASHN_OK )); then
            log "[lint] ✓ Lint checks passed."
            exit 0
        else
            err "[lint] ✗ Lint checks failed."
            # shellcheck disable=SC2317
            exit 1
        fi
        ;;
    golden)
        log "[golden] Regenerating golden PKGBUILD files in test/fixtures/."
        GOLDEN_MODES=(local aur aur-git)
        GOLDEN_DIR="$PROJECT_ROOT/test/fixtures"
        mkdir -p "$GOLDEN_DIR"
        for mode in "${GOLDEN_MODES[@]}"; do
            log "[golden] Generating PKGBUILD for $mode..."
            # Clean before each mode
            bash "$SCRIPT_DIR/$SCRIPT_NAME" clean > /dev/null 2>&1 || warn "[golden] Clean failed for $mode, continuing..."
            # Generate PKGBUILD (not dry-run, but skip install)
            # Save and restore CI to avoid leaking into nested calls
            _old_ci=${CI:-}
            export CI=1
            export GPG_KEY_ID="TEST_KEY_FOR_DRY_RUN"
            if bash "$SCRIPT_DIR/$SCRIPT_NAME" --dry-run "$mode" > /dev/null 2>&1; then
                GOLDEN_FILE="$GOLDEN_DIR/PKGBUILD.$mode.golden"
                cp -f "$SCRIPT_DIR/PKGBUILD" "$GOLDEN_FILE"
                echo "# This is a golden file for test comparison only. Do not use for actual builds or releases." > "$GOLDEN_FILE.tmp"
                cat "$GOLDEN_FILE" >> "$GOLDEN_FILE.tmp"
                mv "$GOLDEN_FILE.tmp" "$GOLDEN_FILE"
                log "[golden] Updated $GOLDEN_FILE"
            else
                err "[golden] Failed to generate PKGBUILD for $mode. Golden file not updated."
            fi
            # Restore previous CI value
            if [[ -n $_old_ci ]]; then
                export CI="$_old_ci"
            else
                unset CI
            fi
        done
        log "[golden] All golden files updated."
        exit 0
        ;;
esac

# PKGBUILD0, PKGBUILD, SRCINFO, OUTDIR, etc.
# (Find and move from below the case block to above it)
# Extract pkgver from PKGBUILD.0 without sourcing
# NOTE: PKGBUILD.0 is always a static template with a simple pkgver=... assignment.
# Dynamic or function-based pkgver is not supported or needed for this workflow.
if [[ ! -f "$PKGBUILD0" ]]; then
    err "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    # shellcheck disable=SC2317
    exit 1
fi
PKGVER_LINE=$(awk -F= '/^[[:space:]]*pkgver[[:space:]]*=/ {print $2}' "$PKGBUILD0")
if [[ "$PKGVER_LINE" =~ [\$\`\(\)] ]]; then
    err "Dynamic pkgver assignment detected in $PKGBUILD0. Only static assignments are supported."
    # shellcheck disable=SC2317
    exit 1
fi
PKGVER=$(echo "$PKGVER_LINE" | tr -d "\"'[:space:]")
if [[ -z "$PKGVER" ]]; then
    err "Error: Could not extract static pkgver from $PKGBUILD0"
    # shellcheck disable=SC2317
    exit 1
fi
declare -r PKGVER
TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
declare -r TARBALL

# Only create the tarball for aur and local modes
if [[ "$MODE" == "aur" || "$MODE" == "local" ]]; then
    cd "$PROJECT_ROOT" || exit 1
    # Determine the git reference to use for archiving
    # Try to use the tag that matches pkgver first, fall back to HEAD if tag doesn't exist
    GIT_REF="HEAD"
    if git -C "$PROJECT_ROOT" rev-parse "v${PKGVER}" >/dev/null 2>&1; then
        GIT_REF="v${PKGVER}"
        log "[aur] Using tag v${PKGVER} for archiving"
    elif git -C "$PROJECT_ROOT" rev-parse "${PKGVER}" >/dev/null 2>&1; then
        GIT_REF="${PKGVER}"
        log "[aur] Using tag ${PKGVER} for archiving"
    else
        warn "[aur] Warning: No tag found for version ${PKGVER}, using HEAD (this may cause checksum mismatches)"
    fi
    
    # Use git archive to create the release tarball, including only tracked files
    # This avoids hand-maintaining exclude lists by respecting .gitignore
    # For reproducibility: set mtime using SOURCE_DATE_EPOCH if available, else use a fixed date
    if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
        ARCHIVE_MTIME="--mtime=@$SOURCE_DATE_EPOCH"
        log "[aur] Using SOURCE_DATE_EPOCH=\"$SOURCE_DATE_EPOCH\" for tarball mtime."
    else
        # Use the commit date of GIT_REF for reproducible, traceable mtime
        COMMIT_EPOCH=$(git show -s --format=%ct "$GIT_REF")
        ARCHIVE_MTIME="--mtime=@$COMMIT_EPOCH"
        log "[aur] Using commit date (epoch \"$COMMIT_EPOCH\") of \"$GIT_REF\" for tarball mtime."
    fi
    # Check if git archive supports --mtime (Git >= 2.32)
    GIT_VERSION=$(git --version | awk '{print $3}')
    GIT_VERSION_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
    GIT_VERSION_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)
    GIT_MTIME_SUPPORTED=0
    if (( GIT_VERSION_MAJOR > 2 )) || { (( GIT_VERSION_MAJOR == 2 )) && (( GIT_VERSION_MINOR > 31 )); }; then
        GIT_MTIME_SUPPORTED=1
    fi
    if git archive --help | grep -q -- '--mtime'; then
        GIT_MTIME_SUPPORTED=1
    fi
    if (( ! GIT_MTIME_SUPPORTED )); then
        warn "[aur-generator] Your git version ($GIT_VERSION) does not support 'git archive --mtime'. For fully reproducible tarballs, upgrade to git ≥ 2.32.0. Falling back to tar --mtime for reproducibility."
    fi
    if (( GIT_MTIME_SUPPORTED )); then
        (
            set -euo pipefail
            unset CI
            trap '' ERR
            git -C "$PROJECT_ROOT" archive --format=tar --prefix="${PKGNAME}-${PKGVER}/" "$ARCHIVE_MTIME" "$GIT_REF" | \
                gzip -n >| "$OUTDIR/$TARBALL"
        )
        log "Created $OUTDIR/$TARBALL using $GIT_REF with reproducible mtime."
    else
        (
            set -euo pipefail
            unset CI
            trap '' ERR
            # Use tar --mtime for reproducible tarballs on old git
            git -C "$PROJECT_ROOT" archive --format=tar --prefix="${PKGNAME}-${PKGVER}/" "$GIT_REF" >| "$OUTDIR/$TARBALL.tmp.tar"
            TAR_MTIME=""
            if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
                TAR_MTIME="--mtime=@${SOURCE_DATE_EPOCH}"
            else
                TAR_MTIME="--mtime=@${COMMIT_EPOCH}"
            fi
            tar "$TAR_MTIME" -cf - -C "$OUTDIR" "${PKGNAME}-${PKGVER}" | gzip -n >| "$OUTDIR/$TARBALL"
            rm -rf "$OUTDIR/${PKGNAME}-${PKGVER}" "$OUTDIR/$TARBALL.tmp.tar"
        )
        log "Created $OUTDIR/$TARBALL using $GIT_REF (tar --mtime fallback for reproducibility)."
    fi

    # Create GPG signature for aur mode only
    if [[ "$MODE" == "aur" ]]; then
        # Check for GPG secret key before signing
        if ! gpg --list-secret-keys --with-colons | grep -q '^sec:'; then
            err "Error: No GPG secret key found. Please generate or import a GPG key before signing."
            # shellcheck disable=SC2317
            exit 1
        fi
        # Set signature file extension and armor option
        set_signature_ext
        log "[aur] Using $( [[ $ascii_armor -eq 1 ]] && printf '%s' 'ASCII-armored signatures (.asc)' || printf '%s' 'binary signatures (.sig)' )"
        # GPG key selection logic
        GPG_KEY=""
        if [[ -n "${GPG_KEY_ID:-}" ]]; then
            if [[ "${GPG_KEY_ID:-}" == "TEST_KEY_FOR_DRY_RUN" ]]; then
                # In test mode, skip GPG signing
                log "[aur] Test mode: Skipping GPG signing"
                GPG_KEY=""
            else
                GPG_KEY="$GPG_KEY_ID"
            fi
        else
            # List available secret keys and prompt user
            mapfile -t KEYS < <(gpg --list-secret-keys --with-colons | awk -F: '/^sec/ {print $5}')
            if [[ ${#KEYS[@]} -eq 0 ]]; then
                err "No GPG secret keys found."
                # shellcheck disable=SC2317
                exit 1
            fi
            warn "Available GPG secret keys:" >&2
            for i in "${!KEYS[@]}"; do
                USER=$(gpg --list-secret-keys "${KEYS[$i]}" | grep uid | head -n1 | sed 's/.*] //')
                warn "$((i+1)). ${KEYS[$i]} ($USER)" >&2
            done
            if ! have_tty; then
                err "No interactive terminal: please set GPG_KEY_ID in headless mode."
                # shellcheck disable=SC2317
                exit 1
            fi
            # Default is always supplied to prompt; variable will always be set, even in CI/headless mode.
            prompt "Select a key [1-${#KEYS[@]}]: " choice 1
            # Ensure choice is set to a default if empty
            # shellcheck disable=SC2154
            if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#KEYS[@]} )); then
                err "Invalid selection."
                # shellcheck disable=SC2317
                exit 1
            fi
            GPG_KEY="${KEYS[$((choice-1))]}"
        fi
        if [[ -n "$GPG_KEY" ]]; then
            gpg --detach-sign $GPG_ARMOR_OPT -u "$GPG_KEY" --output "$OUTDIR/$TARBALL$SIGNATURE_EXT" "$OUTDIR/$TARBALL"
            log "[aur] Created GPG signature: $OUTDIR/$TARBALL$SIGNATURE_EXT"
        elif [[ "${GPG_KEY_ID:-}" == "TEST_KEY_FOR_DRY_RUN" ]]; then
            # In test mode, always create a dummy signature file (.asc or .sig) to satisfy CI expectations
            touch "$OUTDIR/$TARBALL$SIGNATURE_EXT"
            log "[aur] Test mode: Created dummy signature file: $OUTDIR/$TARBALL$SIGNATURE_EXT"
            GPG_KEY=""
        else
            gpg --detach-sign $GPG_ARMOR_OPT --output "$OUTDIR/$TARBALL$SIGNATURE_EXT" "$OUTDIR/$TARBALL"
            log "[aur] Created GPG signature: $OUTDIR/$TARBALL$SIGNATURE_EXT"
        fi
    fi
fi

cd "$SCRIPT_DIR" || exit 1

if [[ "$MODE" == "local" || "$MODE" == "aur" ]]; then
    if [[ "$MODE" == "aur" ]]; then
        # --- Begin flock-protected critical section for pkgrel bump ---
        LOCKFILE="$SCRIPT_DIR/.aur-generator.lock"
        (
            set -euo pipefail  # Ensure require and all commands fail early in flock-protected critical section
            exec 200>"$LOCKFILE"
            flock -n 200 || err "[aur] Another process is already updating PKGBUILD. Aborting."
            OLD_PKGVER=""
            OLD_PKGREL=""
            cp -f "$PKGBUILD0" "$PKGBUILD"
            log "[aur] PKGBUILD.0 copied to PKGBUILD. (locked)"
            if [[ -s "$PKGBUILD" ]]; then
                cp "$PKGBUILD" "$PKGBUILD.bak"
                trap 'rm -f "$PKGBUILD.bak"' RETURN INT TERM
                OLD_PKGVER=$(awk -F= '/^[[:space:]]*pkgver[[:space:]]*=/ {print $2}' "$PKGBUILD.bak" | tr -d "\"'[:space:]")
                OLD_PKGREL=$(awk -F= '/^[[:space:]]*pkgrel[[:space:]]*=/ {print $2}' "$PKGBUILD.bak" | tr -d "\"'[:space:]")
            fi
            NEW_PKGREL=1
            if [[ -n "$OLD_PKGVER" && -n "$OLD_PKGREL" ]]; then
                if [[ "$OLD_PKGVER" == "$PKGVER" ]]; then
                    # Same version, bump pkgrel
                    NEW_PKGREL=$((OLD_PKGREL + 1))
                    log "[aur] pkgver unchanged ($PKGVER), bumping pkgrel to $NEW_PKGREL. (locked)"
                else
                    # New version, reset pkgrel
                    NEW_PKGREL=1
                    log "[aur] pkgver changed ($OLD_PKGVER -> $PKGVER), setting pkgrel to 1. (locked)"
                fi
            else
                log "[aur] No previous PKGBUILD found, setting pkgrel to 1. (locked)"
            fi
            # Update pkgrel in the new PKGBUILD
            awk -v new_pkgrel="$NEW_PKGREL" 'BEGIN{done=0} /^[[:space:]]*pkgrel[[:space:]]*=/ && !done {print "pkgrel=" new_pkgrel; done=1; next} {print}' "$PKGBUILD" >| "$PKGBUILD.tmp" && mv "$PKGBUILD.tmp" "$PKGBUILD"
            trap - RETURN INT TERM
        )
        # --- End flock-protected critical section ---
    fi
    if [[ "$MODE" == "aur" ]]; then
        # Fix: Append tarball URL to source=(), robustly handling multiline arrays and preserving extra sources
        set_signature_ext
        TARBALL_URL="https://github.com/${GH_USER}/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}"
        TARBALL_URL="${TARBALL_URL//\"/}"
        # Helper: Check if a release asset exists on GitHub (by URL or via gh CLI)
        if asset_exists "$TARBALL_URL" "$PKGVER" "$TARBALL"; then
            asset_exists=1
        else
            asset_exists=0
        fi
        if (( asset_exists == 0 )); then
            warn "[aur] WARNING: Release asset not found at $TARBALL_URL. Trying fallback with 'v' prefix."
            TARBALL_URL="https://github.com/${GH_USER}/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
            if asset_exists "$TARBALL_URL" "$PKGVER" "$TARBALL"; then
                asset_exists=1
            else
                asset_exists=0
            fi
            if (( asset_exists == 0 )); then
                # Asset not found - offer to upload automatically if gh CLI is available
                if command -v gh >/dev/null 2>&1; then
                    warn "[aur] Release asset not found. GitHub CLI (gh) detected."
                    if [[ "${AUTO:-}" == "y" ]]; then
                        upload_choice="y"
                    else
                        # Default is always supplied to prompt; variable will always be set, even in CI/headless mode.
                        prompt "Do you want to upload the tarball and signature to GitHub releases automatically? [y/N] " upload_choice n
                    fi
                    if [[ "$upload_choice" =~ ^[Yy]$ ]]; then
                        set_signature_ext
                        log "[aur] Uploading ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to GitHub release ${PKGVER}..."
                        # Upload tarball
                        gh_upload_or_exit "$OUTDIR/$TARBALL" "${GH_USER}/${PKGNAME}" "${PKGVER}"
                        # Upload signature
                        gh_upload_or_exit "$OUTDIR/$TARBALL$SIGNATURE_EXT" "${GH_USER}/${PKGNAME}" "${PKGVER}"
                        if (( no_wait )); then
                            printf '[aur] --no-wait flag set: Skipping post-upload wait for asset availability. (CI/advanced mode)\n' >&2
                        else
                            printf '[aur] Waiting for GitHub to propagate the uploaded asset (this may take some time due to CDN delay)...\n' >&2
                            RETRIES=6
                            DELAYS=(10 20 30 40 50 60)
                            total_wait=0
                            for ((i=1; i<=RETRIES; i++)); do
                                DELAY=${DELAYS[$((i-1))]}
                                if curl -I -L -f --silent "$TARBALL_URL" > /dev/null; then
                                    log "[aur] Asset is now available on GitHub (after $i attempt(s))."
                                    if (( total_wait > 0 )); then
                                        printf '[aur] Total wait time: %s seconds.\n' "$total_wait" >&2
                                    fi
                                    break
                                else
                                    if (( i < RETRIES )); then
                                        printf '[aur] Asset not available yet (attempt %s/%s). Waiting %s seconds...\n' "$i" "$RETRIES" "$DELAY" >&2
                                        sleep "$DELAY"
                                        total_wait=$((total_wait + DELAY))
                                    else
                                        warn "[aur] Asset still not available after $RETRIES attempts. This is normal if GitHub CDN is slow."
                                        printf '[aur] Please check the asset URL in your browser: %s\n' "$TARBALL_URL" >&2
                                        printf 'If the asset is available, you can continue. If not, wait a bit longer and refresh the page.\n' >&2
                                        prompt "Press Enter to continue when the asset is available (or Ctrl+C to abort)..." _
                                    fi
                                fi
                            done
                        fi
                        printf '[aur] Note: After upload, makepkg will attempt to download the asset to generate checksums. If you see a download error, wait a few seconds and retry. This is normal due to GitHub CDN propagation.\n' >&2
                    else
                        err "[aur] Release asset not found and automatic upload declined. Aborting."
                        # shellcheck disable=SC2317
                        printf 'After uploading the tarball manually, run: makepkg -g >> PKGBUILD to update checksums.\n'
                        # shellcheck disable=SC2317
                        exit 1
                    fi
                else
                    err "[aur] ERROR: Release asset not found at either location. GitHub CLI (gh) not available for automatic upload."
                    # shellcheck disable=SC2317
                    printf 'Please install GitHub CLI (gh) or manually upload %q and %q to the GitHub release page.\n' "$OUTDIR/$TARBALL" "$OUTDIR/$TARBALL$SIGNATURE_EXT"
                    # shellcheck disable=SC2317
                    printf 'After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums.\n'
                    # shellcheck disable=SC2317
                    exit 1
                fi
            fi
        fi
        # Only update the source array once, after the final TARBALL_URL is determined
        update_source_array_in_pkgbuild "$PKGBUILD" "$TARBALL_URL"
        log "[aur] Set tarball URL in source array in PKGBUILD (single authoritative update)."
        # Ensure b2sums array is present (prevents updpkgsums from defaulting to sha256sums)
        if ! grep -q '^b2sums=' "$PKGBUILD"; then
            printf "b2sums=('SKIP')\n" >> "$PKGBUILD"
            log "[aur] Added missing b2sums=('SKIP') to PKGBUILD."
        fi
        # Check if the tarball exists on GitHub before running updpkgsums
        # Helper: Check if a release asset exists on GitHub (by URL or via gh CLI)
        if asset_exists "$TARBALL_URL" "$PKGVER" "$TARBALL"; then
            asset_exists=1
        else
            asset_exists=0
        fi
        if (( asset_exists == 0 )); then
            warn "[aur] WARNING: Release asset not found at $TARBALL_URL. Trying fallback with 'v' prefix."
            sed -i "s|source=(\".*\")|source=(\"https://github.com/${GH_USER}/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
            TARBALL_URL="https://github.com/${GH_USER}/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
            if asset_exists "$TARBALL_URL" "$PKGVER" "$TARBALL"; then
                asset_exists=1
            else
                asset_exists=0
            fi
            if (( asset_exists == 0 )); then
                # Asset not found - offer to upload automatically if gh CLI is available
                if command -v gh >/dev/null 2>&1; then
                    warn "[aur] Release asset not found. GitHub CLI (gh) detected."
                    if [[ "${AUTO:-}" == "y" ]]; then
                        upload_choice="y"
                    else
                        # Default is always supplied to prompt; variable will always be set, even in CI/headless mode.
                        prompt "Do you want to upload the tarball and signature to GitHub releases automatically? [y/N] " upload_choice n
                    fi
                    if [[ "$upload_choice" =~ ^[Yy]$ ]]; then
                        set_signature_ext
                        log "[aur] Uploading ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to GitHub release ${PKGVER}..."
                        # Upload tarball
                        gh_upload_or_exit "$OUTDIR/$TARBALL" "${GH_USER}/${PKGNAME}" "${PKGVER}"
                        # Upload signature
                        gh_upload_or_exit "$OUTDIR/$TARBALL$SIGNATURE_EXT" "${GH_USER}/${PKGNAME}" "${PKGVER}"
                        if (( no_wait )); then
                            printf '[aur] --no-wait flag set: Skipping post-upload wait for asset availability. (CI/advanced mode)\n' >&2
                        else
                            printf '[aur] Waiting for GitHub to propagate the uploaded asset (this may take some time due to CDN delay)...\n' >&2
                            RETRIES=6
                            DELAYS=(10 20 30 40 50 60)
                            total_wait=0
                            for ((i=1; i<=RETRIES; i++)); do
                                DELAY=${DELAYS[$((i-1))]}
                                if curl -I -L -f --silent "$TARBALL_URL" > /dev/null; then
                                    log "[aur] Asset is now available on GitHub (after $i attempt(s))."
                                    if (( total_wait > 0 )); then
                                        printf '[aur] Total wait time: %s seconds.\n' "$total_wait" >&2
                                    fi
                                    break
                                else
                                    if (( i < RETRIES )); then
                                        printf '[aur] Asset not available yet (attempt %s/%s). Waiting %s seconds...\n' "$i" "$RETRIES" "$DELAY" >&2
                                        sleep "$DELAY"
                                        total_wait=$((total_wait + DELAY))
                                    else
                                        warn "[aur] Asset still not available after $RETRIES attempts. This is normal if GitHub CDN is slow."
                                        printf '[aur] Please check the asset URL in your browser: %s\n' "$TARBALL_URL" >&2
                                        printf 'If the asset is available, you can continue. If not, wait a bit longer and refresh the page.\n' >&2
                                        prompt "Press Enter to continue when the asset is available (or Ctrl+C to abort)..." _
                                    fi
                                fi
                            done
                        fi
                        printf '[aur] Note: After upload, makepkg will attempt to download the asset to generate checksums. If you see a download error, wait a few seconds and retry. This is normal due to GitHub CDN propagation.\n' >&2
                    else
                        err "[aur] Release asset not found and automatic upload declined. Aborting."
                        # shellcheck disable=SC2317
                        printf 'After uploading the tarball manually, run: makepkg -g >> PKGBUILD to update checksums.\n'
                        # shellcheck disable=SC2317
                        exit 1
                    fi
                else
                    err "[aur] ERROR: Release asset not found at either location. GitHub CLI (gh) not available for automatic upload."
                    # shellcheck disable=SC2317
                    printf 'Please install GitHub CLI (gh) or manually upload %q and %q to the GitHub release page.\n' "$OUTDIR/$TARBALL" "$OUTDIR/$TARBALL$SIGNATURE_EXT"
                    # shellcheck disable=SC2317
                    printf 'After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums.\n'
                    # shellcheck disable=SC2317
                    exit 1
                fi
            fi
        fi
        update_checksums
        generate_srcinfo
        log "[aur] Preparation complete."
        if (( asset_exists == 0 )); then
            if command -v gh >/dev/null 2>&1; then
                printf 'Assets have been automatically uploaded to GitHub release %s.\n' "$PKGVER"
            else
                set_signature_ext
                printf 'Now push the git tag and upload %q and %q to the GitHub release page.\n' "$OUTDIR/$TARBALL" "$OUTDIR/$TARBALL$SIGNATURE_EXT"
            fi
        else
            printf 'Assets already exist on GitHub release %s. No upload was performed.\n' "$PKGVER" >&2
        fi
        printf 'Then, copy the generated PKGBUILD and .SRCINFO to your local AUR git repository, commit, and push to update the AUR package.\n'
        install_pkg "aur"
        exit 0
    else
        update_checksums
        generate_srcinfo
        install_pkg "$MODE"
        exit 0
    fi
fi

awk -v gh_user="$GH_USER" -v pkgname_short="${PKGNAME%-git}" '
    BEGIN { sums = "b2sums=(\"SKIP\")" }
    /^pkgname=/ {
        print "pkgname=vglog-filter-git"; next
    }
    /^source=/ {
        print "source=(\"git+https://github.com/" gh_user "/vglog-filter.git#branch=main\")";
        print sums;
        next
    }
    /^b2sums=/ || /^sha256sums=/ { next }
    { gsub(/\${pkgname}-\${pkgver}|\$pkgname-\$pkgver/, pkgname_short); print }
' "$PKGBUILD0" >| "$SCRIPT_DIR/PKGBUILD.git"
# Insert pkgver() as before if missing
if ! grep -q '^pkgver()' "$SCRIPT_DIR/PKGBUILD.git"; then
    awk '
        /^source=/ {
            print;
            print "";
            print "pkgver() {";
            print "    cd \"$srcdir/${pkgname%-git}\"";
            printf "    git describe --long --tags 2>/dev/null | sed \"s/^v//;s/-/./g\" || \\\n";
            print "        printf \"r%s.%s\" \"$(git rev-list --count HEAD)\" \"$(git rev-parse --short HEAD)\"";
            print "}";
            next
        }
        { print }
    ' "$SCRIPT_DIR/PKGBUILD.git" >| "$SCRIPT_DIR/PKGBUILD.git.tmp" && mv "$SCRIPT_DIR/PKGBUILD.git.tmp" "$SCRIPT_DIR/PKGBUILD.git"
fi
PKGBUILD_TEMPLATE="$SCRIPT_DIR/PKGBUILD.git"
# Inject makedepends=(git) if missing or incomplete
if ! grep -q '^makedepends=.*git' "$PKGBUILD_TEMPLATE"; then
    awk 'BEGIN{done=0} \
        /^pkgname=/ && !done {print; print "makedepends=(git)"; done=1; next} \
        {print}' "$PKGBUILD_TEMPLATE" >| "$PKGBUILD_TEMPLATE.tmp" && mv "$PKGBUILD_TEMPLATE.tmp" "$PKGBUILD_TEMPLATE"
    log "[aur-git] Injected makedepends=(git) into PKGBUILD.git."
fi
cp -f "$PKGBUILD_TEMPLATE" "$PKGBUILD"
log "[aur-git] PKGBUILD.git generated and copied to PKGBUILD."
# Set validpgpkeys if missing
if [[ -n "${GPG_KEY_ID:-}" ]]; then
    grep -q "^validpgpkeys=('${GPG_KEY_ID}')" "$PKGBUILD" || printf "validpgpkeys=('%s')\n" "$GPG_KEY_ID" >> "$PKGBUILD"
fi
# Do NOT run updpkgsums for VCS (git) packages, as checksums must be SKIP
# and updpkgsums would overwrite them with real sums, breaking the PKGBUILD.
generate_srcinfo
install_pkg "aur-git"
exit 0