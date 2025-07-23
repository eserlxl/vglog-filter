#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Modes summary:
#   local   - Build/install from a local tarball for testing.
#   aur     - Prepare a signed release tarball and PKGBUILD for AUR upload.
#   aur-git - Generate a PKGBUILD for the -git (VCS) AUR package.
# See doc/AUR.md for full details on each mode and workflow.
# NOTE: This script requires GNU getopt (util-linux) and is not compatible with macOS/BSD systems.
# The script is designed for GNU/Linux environments and does not aim to support macOS/BSD.

# Require Bash >= 4 early, before using any Bash 4+ features
if ((BASH_VERSINFO[0] < 4)); then
    echo "Bash ≥ 4 required" >&2
    exit 1
fi

# Ensure GPG pinentry works in CI/sudo/non-interactive shells
GPG_TTY=$(tty)  # Needed for GPG signing to work reliably (pinentry) in CI/sudo
export GPG_TTY

# color_enabled is set from env or default, but will be overridden by CLI options below
# Remove unreachable Bash version check for color_enabled
set -euo pipefail
# --- Tiny Helper Functions (moved to top for trap consistency) ---
err() {
    trap - ERR
    color_echo red "$*" >&2;
}
warn() { color_echo yellow "$*" >&2; }
log() { color_echo green "$*"; }
# Tool-to-package mapping for Arch Linux hints
# shellcheck disable=SC2034
# Associative array: tool name -> package name
# This is more maintainable than a case statement
# Requires Bash 4+
declare -Ar PKG_HINT=(
    [updpkgsums]=pacman-contrib
    [makepkg]=base-devel
    [curl]=curl
    [gpg]=gnupg
    [gh]=github-cli
    [flock]=util-linux
    [awk]=gawk
)
# Trap errors and print a helpful message with line number and command
# set -E: Ensure ERR trap is inherited by functions and subshells (Bash >=4.4). For older Bash, enable errtrace explicitly.
set -E
shopt -s errtrace
trap 'err "[FATAL] ${RED}${BASH_SOURCE[0]}:$LINENO: $BASH_COMMAND${RESET}"' ERR

# --- Functions ---
# Minimal help for scripts/AUR helpers
help() {
    printf 'Usage: %s [OPTIONS] MODE\n' "$SCRIPT_NAME"
    printf 'Modes: local | aur | aur-git | clean | test\n'
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
usage() {
    help
    printf '\n'
    printf 'Options:\n'
    printf '  -n, --no-color      Disable color output\n'
    printf '  -a, --ascii-armor   Use ASCII-armored GPG signatures (.asc)\n'
    printf '  -d, --dry-run       Dry run (no changes, for testing)\n'
    printf '  -h, --help          Show minimal usage and exit\n'
    printf '\n'
    printf 'All options must appear before the mode.\n'
    printf 'For full documentation, see doc/AUR.md.\n'
    printf '\n'
    printf 'If a required tool is missing, a hint will be printed with an installation suggestion (e.g., pacman -S pacman-contrib for updpkgsums).\n'
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

color_echo() {
    local color_name="$1"
    shift
    local msg="$*"
    if (( color_enabled )); then
        case "$color_name" in
            red) printf '%b%s%b\n' "$RED" "$msg" "$RESET" ;;
            green) printf '%b%s%b\n' "$GREEN" "$msg" "$RESET" ;;
            yellow) printf '%b%s%b\n' "$YELLOW" "$msg" "$RESET" ;;
            *) printf '%s\n' "$msg" ;;
        esac
    else
        printf '%s\n' "$msg"
    fi
}

hint() {
    local tool="$1"
    local pkg="${PKG_HINT[$tool]:-}"
    if [[ -n "$pkg" ]]; then
        warn "Hint: Install with 'pacman -S $pkg' (Arch Linux)"
    else
        warn "Hint: Install '$tool' using your package manager (e.g., pacman -S $tool)"
    fi
}

require() {
    local t
    local -a missing=()
    for t in "$@"; do
        if ! command -v "$t" >/dev/null; then
            missing+=("$t")
        fi
    done
    if (( ${#missing[@]} )); then
        err "Missing required tool(s): $(IFS=, ; echo "${missing[*]}")"
        for t in "${missing[@]}"; do
            hint "$t"
        done
        return 1
    fi
}

# Prompt helper function that auto-skips when CI is set
# If CI=1 and default_value is provided, assigns it and returns 0 (success)
# If CI=1 and default_value is empty, skips prompt and returns 1 (caller may check this)
# This shortcut is relied upon in some code paths; see usage for details
prompt() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="${3:-}"
    if [[ ${CI:-0} == 1 ]]; then
        if [[ -n "$default_value" ]]; then
            eval "$var_name=\"$default_value\""
            log "[CI] Auto-selected '$default_value' for: $prompt_text"
            return 0
        else
            log "[CI] Skipping prompt: $prompt_text"
            return 1
        fi
    fi
    if ! [[ -t 0 ]]; then
        warn "[prompt] No interactive terminal available for: $prompt_text. Skipping prompt."
        if [[ -n "$default_value" ]]; then
            eval "$var_name=\"$default_value\""
            return 0
        else
            return 1
        fi
    fi
    local input
    read -rp "$prompt_text" input
    eval "$var_name=\"$input\""
}

update_checksums() {
    updpkgsums
    log "[update_checksums] Ran updpkgsums (b2sums updated)."
}
generate_srcinfo() {
    if command -v makepkg >/dev/null 2>&1; then
        makepkg --printsrcinfo > .SRCINFO
        log "[generate_srcinfo] Updated .SRCINFO with makepkg --printsrcinfo."
    elif command -v mksrcinfo >/dev/null 2>&1; then
        mksrcinfo
        log "[generate_srcinfo] Updated .SRCINFO with mksrcinfo (deprecated, please update your tools)."
    else
        warn "Warning: Could not update .SRCINFO (makepkg --printsrcinfo/mksrcinfo not found)."
    fi
}
install_pkg() {
    local mode="$1"
    local run_makepkg=n  # Always initialize to avoid set -u errors
    if [[ $dry_run -eq 1 ]]; then
        log "[$mode] --dry-run: Skipping makepkg -si. All required steps completed successfully."
    else
        if [[ "$mode" == "aur" ]]; then
            if [[ "${AUTO:-}" == "y" ]]; then
                run_makepkg=n
            else
                prompt "Do you want to run makepkg -si now? [y/N] " run_makepkg n
            fi
            if [[ "$run_makepkg" =~ ^[Yy]$ ]]; then
                makepkg -si
            fi
        else
            makepkg -si
        fi
    fi
}

# --- Config / Constants ---
readonly PKGNAME="vglog-filter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT
# Determine GH_USER: environment > PKGBUILD.0 url > fallback
if [[ -z "${GH_USER:-}" ]]; then
    PKGBUILD0_URL=$(awk -F/ '/^url="https:\/\/github.com\// {print $5}' "$SCRIPT_DIR/PKGBUILD.0")
    if [[ -n "$PKGBUILD0_URL" ]]; then
        GH_USER="$PKGBUILD0_URL"
    else
        GH_USER="eserlxl"
        warn "[aur-generator] Could not parse GitHub user/org from PKGBUILD.0 url field, defaulting to 'eserlxl'."
    fi
fi
readonly GH_USER
# VALID_MODES is used for validation in the usage function and mode checking
# shellcheck disable=SC2034
readonly -a VALID_MODES=(local aur aur-git clean test)

# --- Main Logic ---
# Initialize variables from environment or defaults before flag parsing
dry_run=${DRY_RUN:-0}
ascii_armor=${ASCII_ARMOR:-0}
# color_enabled=${COLOR:-1}  # <-- Remove this line, already set at top

# Use getopt for unified short and long option parsing
# This allows for robust handling of both short (-n) and long (--no-color) options
# IMPORTANT: Always check the exit code of getopt before using its output.
# If getopt fails (e.g., due to an unknown flag), set -e does not abort inside $(),
# so we must check the status explicitly to avoid silent bad-option handling.
getopt_output=$(getopt --shell bash -o nadh --long no-color,ascii-armor,dry-run,help -- "$@")
getopt_status=$?
if (( getopt_status != 0 )); then
    err "Failed to parse options."; usage; exit 1
fi
if ! read -ra PARSED_OPTS <<< "$getopt_output"; then
    err "Failed to parse options."; usage; exit 1
fi
# Note: set -- resets positional parameters to the parsed result
# Use array-safe idiom to avoid word-splitting hazard (see shell scripting best practices)
set -- "${PARSED_OPTS[@]}"
# Set color_enabled default from environment, will be overridden by CLI flags
color_enabled=$([[ ${NO_COLOR:-0} == 1 ]] && echo 0 || echo "${COLOR:-1}")
while true; do
    case "$1" in
        -n|--no-color)
            color_enabled=0; shift ;;
        -a|--ascii-armor)
            ascii_armor=1; shift ;;
        -d|--dry-run)
            dry_run=1; shift ;;
        -h|--help)
            help; exit 0 ;;
        --)
            shift; break ;;
        *)
            err "Unknown option: $1"; usage; exit 1 ;;
    esac
done
# Now set color variables based on final color_enabled value
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
        RED='\e[1;31m'
        GREEN='\e[1;32m'
        YELLOW='\e[1;33m'
        RESET='\e[0m'
    fi
else
    RED=''
    GREEN=''
    YELLOW=''
    RESET=''
fi

MODE=${1:-}
if [[ -z $MODE ]]; then
    usage; exit 1
fi

# Validate mode using is_valid_mode function
if ! is_valid_mode "$MODE"; then
    err "Unknown mode: $MODE"
    usage; exit 1
fi

# --- Early dependency checks: fail fast if required tools are missing ---
case "$MODE" in
    local)
        # local mode requires: makepkg, updpkgsums, curl
        require makepkg updpkgsums curl || exit 1
        ;;
    aur)
        # aur mode requires: makepkg, updpkgsums, curl, gpg
        require makepkg updpkgsums curl gpg || exit 1
        ;;
    aur-git)
        # aur-git mode requires: makepkg
        require makepkg || exit 1
        ;;
    # clean and test modes do not require special tools
esac

log "Running in $MODE mode"
case "$MODE" in
    local)
        log "[local] Build and install from local tarball."
        # require call moved above
        ;;
    aur)
        log "[aur] Prepare for AUR upload: creates tarball, GPG signature, and PKGBUILD for release."
        # require call moved above
        # Fail early in CI if AUTO=y but gh is not installed
        if [[ "${AUTO:-}" == "y" ]] && ! command -v gh >/dev/null 2>&1; then
            err "[aur] ERROR: AUTO=y is set but GitHub CLI (gh) is not installed. Cannot upload assets automatically in CI. Please install gh or unset AUTO."
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
        OUTDIR="$SCRIPT_DIR"
        PKGBUILD="$SCRIPT_DIR/PKGBUILD"
        SRCINFO="$SCRIPT_DIR/.SRCINFO"
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
        TEST_ERRORS=0
        # Run the test mode (rely only on --dry-run flag, do not export DRY_RUN)
        for test_mode in local aur aur-git; do
            log "--- Testing $test_mode mode ---"
            log "[test] Running clean before $test_mode test..."
            if ! bash "$SCRIPT_DIR/$SCRIPT_NAME" clean > /dev/null 2>&1; then
                warn "[test] Warning: Clean failed for $test_mode test, but continuing..."
            fi
            # Use a persistent log file in SCRIPT_DIR
            TEST_LOG_FILE="$SCRIPT_DIR/test-$test_mode-$(date +%s).log"
            export CI=1  # Skip prompts
            if [[ "$test_mode" == "aur" ]]; then
                export GPG_KEY_ID="TEST_KEY_FOR_DRY_RUN"
            fi
            if bash "$SCRIPT_DIR/$SCRIPT_NAME" --dry-run "$test_mode" > "$TEST_LOG_FILE" 2>&1; then
                log "[test] ✓ $test_mode mode passed"
            else
                err "[test] ✗ $test_mode mode failed"
                TEST_ERRORS=$((TEST_ERRORS + 1))
                warn "Error output for $test_mode is in: $TEST_LOG_FILE"
                cat "$TEST_LOG_FILE" >&2
            fi
            log "[test] Log for $test_mode: $TEST_LOG_FILE"
        done
        # Report results
        if [[ $TEST_ERRORS -eq 0 ]]; then
            log "[test] ✓ All test modes passed successfully!"
        else
            err "[test] ✗ $TEST_ERRORS test mode(s) failed"
            exit 1
        fi
        exit 0
        ;;
esac

# Only define PKGVER and PKGVER-dependent variables for non-clean modes
PKGBUILD0="$SCRIPT_DIR/PKGBUILD.0"
readonly PKGBUILD0
if [[ ! -f "$PKGBUILD0" ]]; then
    err "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    exit 1
fi
# Extract pkgver from PKGBUILD.0 without sourcing
# NOTE: PKGBUILD.0 is always a static template with a simple pkgver=... assignment.
# Dynamic or function-based pkgver is not supported or needed for this workflow.
PKGVER_LINE=$(awk -F= '/^[[:space:]]*pkgver[[:space:]]*=/ {print $2}' "$PKGBUILD0")
if [[ "$PKGVER_LINE" =~ [\$\`\(\)] ]]; then
    err "Dynamic pkgver assignment detected in $PKGBUILD0. Only static assignments are supported."
    exit 1
fi
PKGVER=$(echo "$PKGVER_LINE" | tr -d "\"'[:space:]")
if [[ -z "$PKGVER" ]]; then
    err "Error: Could not extract static pkgver from $PKGBUILD0"
    exit 1
fi
readonly PKGVER
TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
readonly TARBALL
OUTDIR="$SCRIPT_DIR"
readonly OUTDIR
PKGBUILD="$SCRIPT_DIR/PKGBUILD"
SRCINFO="$SCRIPT_DIR/.SRCINFO"

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
        log "[aur] Using SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH for tarball mtime."
    else
        # Use the commit date of GIT_REF for reproducible, traceable mtime
        COMMIT_EPOCH=$(git show -s --format=%ct "$GIT_REF")
        ARCHIVE_MTIME="--mtime=@$COMMIT_EPOCH"
        log "[aur] Using commit date (epoch $COMMIT_EPOCH) of $GIT_REF for tarball mtime."
    fi
    # Check if git archive supports --mtime (Git >= 2.32)
    if git archive --help | grep -q -- '--mtime'; then
        (
            set -euo pipefail
            unset CI
            trap '' ERR
            git -C "$PROJECT_ROOT" archive --format=tar --prefix="${PKGNAME}-${PKGVER}/" "$ARCHIVE_MTIME" "$GIT_REF" | \
                gzip -n > "$OUTDIR/$TARBALL"
        )
        log "Created $OUTDIR/$TARBALL using $GIT_REF with reproducible mtime."
    else
        (
            set -euo pipefail
            unset CI
            trap '' ERR
            git -C "$PROJECT_ROOT" archive --format=tar --prefix="${PKGNAME}-${PKGVER}/" "$GIT_REF" > "$OUTDIR/$TARBALL.tmp.tar"
            gzip -n < "$OUTDIR/$TARBALL.tmp.tar" > "$OUTDIR/$TARBALL"
            rm -f "$OUTDIR/$TARBALL.tmp.tar"
            # Set mtime on the tarball if possible
            if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
                touch -d "@${SOURCE_DATE_EPOCH}" "$OUTDIR/$TARBALL"
            else
                touch -d "@${COMMIT_EPOCH}" "$OUTDIR/$TARBALL"
            fi
        )
        log "Created $OUTDIR/$TARBALL using $GIT_REF (fallback: no --mtime in git archive, set mtime on tarball)."
    fi

    # Create GPG signature for aur mode only
    if [[ "$MODE" == "aur" ]]; then
        # Check for GPG secret key before signing
        if ! gpg --list-secret-keys --with-colons | grep -q '^sec:'; then
            err "Error: No GPG secret key found. Please generate or import a GPG key before signing."
            exit 1
        fi
        # Set signature file extension and armor option
        set_signature_ext
        log "[aur] Using $([[ $ascii_armor -eq 1 ]] && echo 'ASCII-armored signatures (.asc)' || echo 'binary signatures (.sig)')"
        # GPG key selection logic
        GPG_KEY=""
        if [[ -n "$GPG_KEY_ID" ]]; then
            if [[ "$GPG_KEY_ID" == "TEST_KEY_FOR_DRY_RUN" ]]; then
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
                exit 1
            fi
            warn "Available GPG secret keys:" >&2
            for i in "${!KEYS[@]}"; do
                USER=$(gpg --list-secret-keys "${KEYS[$i]}" | grep uid | head -n1 | sed 's/.*] //')
                warn "$((i+1)). ${KEYS[$i]} ($USER)" >&2
            done
            if ! [ -t 0 ]; then
                err "No interactive terminal: please set GPG_KEY_ID in headless mode."
                exit 1
            fi
            prompt "Select a key [1-${#KEYS[@]}]: " choice 1
            # Ensure choice is set to a default if empty
            # shellcheck disable=SC2154
            if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#KEYS[@]} )); then
                err "Invalid selection."
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
    cp -f "$PKGBUILD0" "$PKGBUILD"
    log "[aur] PKGBUILD.0 copied to PKGBUILD."
    # --- pkgrel bump logic for aur mode ---
    if [[ "$MODE" == "aur" ]]; then
        # --- Begin flock-protected critical section for pkgrel bump ---
        # Use exclusive flock to ensure only one process can bump pkgrel at a time.
        # The lockfile is not written to, but exclusive lock prevents race conditions.
        LOCKFILE="$PWD/.lock"
        (
            set -euo pipefail  # Ensure require and all commands fail early in flock-protected critical section
            flock 200
            OLD_PKGVER=""
            OLD_PKGREL=""
            cp -f "$PKGBUILD0" "$PKGBUILD"
            log "[aur] PKGBUILD.0 copied to PKGBUILD. (locked)"
            if [[ -s "$PKGBUILD" ]]; then
                cp "$PKGBUILD" "$PKGBUILD.bak"
                trap 'rm -f "$PKGBUILD.bak"' RETURN
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
            awk -v new_pkgrel="$NEW_PKGREL" 'BEGIN{done=0} /^[[:space:]]*pkgrel[[:space:]]*=/ && !done {print "pkgrel=" new_pkgrel; done=1; next} {print}' "$PKGBUILD" > "$PKGBUILD.tmp" && mv "$PKGBUILD.tmp" "$PKGBUILD"
            trap - RETURN
        ) 200>"$LOCKFILE"
        # --- End flock-protected critical section ---
    fi
    if [[ "$MODE" == "aur" ]]; then
        # Fix: Append tarball URL to source=(), robustly handling multiline arrays and preserving extra sources
        set_signature_ext
        TARBALL_URL="https://github.com/${GH_USER}/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}"
        awk -v tarball_url="$TARBALL_URL" '
            BEGIN { in_source=0; new_source_line=""; }
            /^source=\(/ {
                in_source=1;
                # Properly quote tarball_url for PKGBUILD
                printf "source=(\"%s\"\n", tarball_url);
                next
            }
            in_source && /\)/ {
                in_source=0;
                # Remove closing parenthesis from the line
                sub(/\)/, "");
                # Print any remaining sources/comments on this line
                if (length($0) > 0) {
                    # Remove leading/trailing whitespace
                    gsub(/^ +| +$/, "");
                    if (length($0) > 0) print $0;
                }
                print ")";
                print "# <<< aur-generator >>>";
                next
            }
            in_source {
                # Print all lines inside the array (sources, comments)
                print;
                next
            }
            { print }
        ' "$PKGBUILD" > "$PKGBUILD.tmp" && mv "$PKGBUILD.tmp" "$PKGBUILD"
        log "[aur] Appended tarball URL to source array in PKGBUILD (preserves extra sources and comments)."
        # Check if the tarball exists on GitHub before running updpkgsums
        asset_exists=1
        if command -v gh >/dev/null 2>&1; then
            if ! gh api "/repos/${GH_USER}/${PKGNAME}/releases/assets" --jq ".[] | select(.name == \"${TARBALL}\")" >/dev/null 2>&1; then
                asset_exists=0
            fi
        else
            if ! curl -sSf -L "$TARBALL_URL" -o /dev/null; then
                asset_exists=0
            fi
        fi
        if (( asset_exists == 0 )); then
            warn "[aur] WARNING: Release asset not found at $TARBALL_URL. Trying fallback with 'v' prefix."
            sed -i "s|source=(\".*\")|source=(\"https://github.com/${GH_USER}/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
            TARBALL_URL="https://github.com/${GH_USER}/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
            asset_exists=1
            if command -v gh >/dev/null 2>&1; then
                if ! gh api "/repos/${GH_USER}/${PKGNAME}/releases/assets" --jq ".[] | select(.name == \"${TARBALL}\")" >/dev/null 2>&1; then
                    asset_exists=0
                fi
            else
                if ! curl -sSf -L "$TARBALL_URL" -o /dev/null; then
                    asset_exists=0
                fi
            fi
            if (( asset_exists == 0 )); then
                # Asset not found - offer to upload automatically if gh CLI is available
                if command -v gh >/dev/null 2>&1; then
                    warn "[aur] Release asset not found. GitHub CLI (gh) detected."
                    if [[ "${AUTO:-}" == "y" ]]; then
                        upload_choice="y"
                    else
                        prompt "Do you want to upload the tarball and signature to GitHub releases automatically? [y/N] " upload_choice n
                    fi
                    if [[ "$upload_choice" =~ ^[Yy]$ ]]; then
                        set_signature_ext
                        log "[aur] Uploading ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to GitHub release ${PKGVER}..."
                        # Upload tarball
                        gh_upload_or_exit "$OUTDIR/$TARBALL" "${GH_USER}/${PKGNAME}" "${PKGVER}"
                        # Upload signature
                        gh_upload_or_exit "$OUTDIR/$TARBALL$SIGNATURE_EXT" "${GH_USER}/${PKGNAME}" "${PKGVER}"
                        # Verify the upload was successful
                        sleep 2  # Give GitHub a moment to process
                        if curl -I -L -f --silent --retry 3 --retry-delay 2 --retry-all-errors "$TARBALL_URL" > /dev/null; then
                            log "[aur] Asset upload verified successfully."
                        else
                            warn "[aur] Asset upload may not be immediately available. Continuing anyway..."
                        fi
                    else
                        err "[aur] Release asset not found and automatic upload declined. Aborting."
                        echo "After uploading the tarball manually, run: makepkg -g >> PKGBUILD to update checksums."
                        exit 1
                    fi
                else
                    err "[aur] ERROR: Release asset not found at either location. GitHub CLI (gh) not available for automatic upload."
                    echo "Please install GitHub CLI (gh) or manually upload ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to the GitHub release page."
                    echo "After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums."
                    exit 1
                fi
            fi
        fi
        update_checksums
        generate_srcinfo
        log "[aur] Preparation complete."
        if command -v gh >/dev/null 2>&1; then
            echo "Assets have been automatically uploaded to GitHub release ${PKGVER}."
        else
            set_signature_ext
            echo "Now push the git tag and upload ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to the GitHub release page."
        fi
        echo "Then, copy the generated PKGBUILD and .SRCINFO to your local AUR git repository, commit, and push to update the AUR package."
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
' "$PKGBUILD0" > "$SCRIPT_DIR/PKGBUILD.git"
# Insert pkgver() as before if missing
if ! grep -q '^pkgver()' "$SCRIPT_DIR/PKGBUILD.git"; then
    awk -v pkgver_func='pkgver() {
    cd "$srcdir/${pkgname%-git}"
    git describe --long --tags 2>/dev/null | sed "s/^v//;s/-/./g" || \
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}' '
        /^source=/ {
            print;
            print pkgver_func;
            next
        }
        { print }
    ' "$SCRIPT_DIR/PKGBUILD.git" > "$SCRIPT_DIR/PKGBUILD.git.tmp" && mv "$SCRIPT_DIR/PKGBUILD.git.tmp" "$SCRIPT_DIR/PKGBUILD.git"
fi
PKGBUILD_TEMPLATE="$SCRIPT_DIR/PKGBUILD.git"
# Inject makedepends=(git) if missing or incomplete
if ! grep -q '^makedepends=.*git' "$PKGBUILD_TEMPLATE"; then
    awk 'BEGIN{done=0} \
        /^pkgname=/ && !done {print; print "makedepends=(git)"; done=1; next} \
        {print}' "$PKGBUILD_TEMPLATE" > "$PKGBUILD_TEMPLATE.tmp" && mv "$PKGBUILD_TEMPLATE.tmp" "$PKGBUILD_TEMPLATE"
    log "[aur-git] Injected makedepends=(git) into PKGBUILD.git."
fi
cp -f "$PKGBUILD_TEMPLATE" "$PKGBUILD"
log "[aur-git] PKGBUILD.git generated and copied to PKGBUILD."
# Set validpgpkeys if missing
if [[ -n "${GPG_KEY_ID:-}" ]]; then
    grep -q "^validpgpkeys=('${GPG_KEY_ID}')" "$PKGBUILD" || echo "validpgpkeys=('${GPG_KEY_ID}')" >> "$PKGBUILD"
fi
# Check for required tools
require makepkg || exit 1
# Do NOT run updpkgsums for VCS (git) packages, as checksums must be SKIP
# and updpkgsums would overwrite them with real sums, breaking the PKGBUILD.
generate_srcinfo
install_pkg "aur-git"
exit 0