#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
set -euo pipefail

# --- Config / Constants ---
readonly PKGNAME="vglog-filter"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLOR=1
VALID_MODES=(local aur aur-git clean)

# --- Functions ---
require() {
    local t
    for t in "$@"; do
        command -v "$t" >/dev/null || { echo "Missing $t"; exit 1; }
    done
}

# Color helper function
color_echo() {
    local color_code="$1"
    shift
    if (( COLOR )); then
        printf '\e[%sm%s\e[0m\n' "$color_code" "$*"
    else
        printf '%s\n' "$*"
    fi
}

log() { color_echo "1;32" "$*"; }
warn() { color_echo "1;33" "$*" >&2; }
err() { color_echo "1;31" "$*" >&2; }

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
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[$mode] --dry-run: Skipping makepkg -si. All previous steps completed successfully."
    else
        if [[ "$mode" == "aur" ]]; then
            if [[ "${CI:-}" == 1 || "${AUTO:-}" == "y" ]]; then
                run_makepkg=n
            else
                read -rp "Do you want to run makepkg -si now? [y/N] " run_makepkg
            fi
            if [[ "$run_makepkg" =~ ^[Yy]$ ]]; then
                makepkg -si
            fi
        else
            makepkg -si
        fi
    fi
}

function usage() {
    log "Usage: $0 [--no-color|-n] [local|aur|aur-git|clean] [--dry-run|-d]"
    echo
    log "Modes:"
    log "  local     Build and install the package from a local tarball (for testing)."
    log "  aur       Prepare a release tarball, sign it with GPG, and update PKGBUILD for AUR upload."
    log "  aur-git   Generate a PKGBUILD for the -git (VCS) AUR package (no tarball/signing)."
    log "  clean     Remove all generated files and directories"
    echo
    log "Options:"
    log "  --no-color, -n   Disable colored output (also supported via NO_COLOR env variable)"
    log "  --dry-run, -d    Run all steps except the final makepkg -si (for CI/testing)"
    echo
    log "Notes:"
    log "- Requires PKGBUILD.0 as the template for PKGBUILD generation."
    log "- For 'aur' mode, a GPG secret key is required for signing the tarball."
    log "- For 'aur' and 'local' modes, the script will attempt to update checksums and .SRCINFO."
    log "- To skip the GPG key selection menu in 'aur' mode, set GPG_KEY_ID to your key's ID:"
    log "    GPG_KEY_ID=ABCDEF ./aur-generator.sh aur"
    log "- To disable colored output, set NO_COLOR=1 or use --no-color/-n."
    log "- To test the script without running makepkg -si, add --dry-run or -d as the second argument."
    exit 1
}

# --- Main Logic ---
# Colorized log helpers (disable color if NO_COLOR is set or --no-color/-n is passed)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-color|-n)
            COLOR=0
            shift
            ;;
        *)
            break
            ;;
    esac
done
if [[ -n "${NO_COLOR:-}" ]]; then
    COLOR=0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
fi

MODE="$1"
DRY_RUN=0
if [[ $# -eq 2 ]]; then
    case "$2" in
        --dry-run|-d)
            DRY_RUN=1
            ;;
        *)
            err "Unknown second argument: $2"
            usage
            ;;
    esac
fi
log "Running in $MODE mode"
case "$MODE" in
    local)
        log "[local] Build and install from local tarball."
        require makepkg updpkgsums curl
        ;;
    aur)
        log "[aur] Prepare for AUR upload: creates tarball, GPG signature, and PKGBUILD for release."
        require makepkg updpkgsums curl gpg
        ;;
    aur-git)
        log "[aur-git] Prepare PKGBUILD for VCS (git) package. No tarball is created."
        require makepkg
        ;;
    clean)
        log "[clean] Remove generated files and directories."
        # Clean mode does not require PKGVER or PKGBUILD0
        OUTDIR="$SCRIPT_DIR"
        PKGBUILD="$SCRIPT_DIR/PKGBUILD"
        SRCINFO="$SCRIPT_DIR/.SRCINFO"
        shopt -s nullglob
        TARBALL_GLOB=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz)
        # Use an explicit array to safely handle files with spaces
        files=("${TARBALL_GLOB[@]}" "${TARBALL_GLOB[@]/%/.sig}")
        echo "Cleaning AUR directory..."
        if (( ${#files[@]} )); then
            rm -f -- "${files[@]}"
        fi
        rm -f "$PKGBUILD" "$SRCINFO"
        rm -rf "$SCRIPT_DIR/src" "$SCRIPT_DIR/pkg"
        rm -f "$SCRIPT_DIR"/*.pkg.tar.*
        shopt -u nullglob
        log "Clean complete."
        exit 0
        ;;
    *)
        err "Unknown mode: $MODE"
        usage
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
PKGVER=$(awk -F= '/^[[:space:]]*pkgver[[:space:]]*=/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$PKGBUILD0" | tr -d "\"'")
if [[ -z "$PKGVER" ]]; then
    err "Error: Could not extract pkgver from $PKGBUILD0"
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
    cd "$PROJECT_ROOT"
    # Use git archive to create the release tarball, including only tracked files
    # This avoids hand-maintaining exclude lists by respecting .gitignore
    git -C "$PROJECT_ROOT" archive --format=tar --prefix="${PKGNAME}-${PKGVER}/" HEAD | \
        gzip -n > "$OUTDIR/$TARBALL"
    log "Created $OUTDIR/$TARBALL"

    # Create GPG signature for aur mode only
    if [[ "$MODE" == "aur" ]]; then
        # Check for GPG secret key before signing
        if ! gpg --list-secret-keys --with-colons | grep -q '^sec:'; then
            err "Error: No GPG secret key found. Please generate or import a GPG key before signing."
            exit 1
        fi
        # GPG key selection logic
        GPG_KEY=""
        if [[ -n "${GPG_KEY_ID:-}" ]]; then
            GPG_KEY="$GPG_KEY_ID"
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
            read -rp "Select a key [1-${#KEYS[@]}]: " choice
            if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#KEYS[@]} )); then
                err "Invalid selection."
                exit 1
            fi
            GPG_KEY="${KEYS[$((choice-1))]}"
        fi
        if [[ -n "$GPG_KEY" ]]; then
            gpg --detach-sign -u "$GPG_KEY" --output "$OUTDIR/$TARBALL.sig" "$OUTDIR/$TARBALL"
        else
            gpg --detach-sign --output "$OUTDIR/$TARBALL.sig" "$OUTDIR/$TARBALL"
        fi
        log "[aur] Created GPG signature: $OUTDIR/$TARBALL.sig"
    fi
fi

cd "$SCRIPT_DIR"

if [[ "$MODE" == "local" || "$MODE" == "aur" ]]; then
    cp -f "$PKGBUILD0" "$PKGBUILD"
    log "[$MODE] PKGBUILD.0 copied to PKGBUILD."
    if [[ "$MODE" == "aur" ]]; then
        # Fix: Try correct link first, fallback to old 'v' link if needed
        sed -E -i "s|^([[:space:]]*source=\([^)]*\))([[:space:]]*#.*)?$|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}\")\2|" "$PKGBUILD"
        log "[aur] Updated source line in PKGBUILD (no 'v' before version)."
        # Check if the tarball exists on GitHub before running updpkgsums
        TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}"
        if ! curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
            warn "[aur] WARNING: Release asset not found at $TARBALL_URL. Trying fallback with 'v' prefix."
            sed -i "s|source=(\".*\")|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
            TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
            if ! curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
                err "[aur] ERROR: Release asset not found at either $TARBALL_URL or without 'v'. Aborting."
                echo "After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums."
                exit 1
            fi
        fi
        update_checksums
        generate_srcinfo
        log "[aur] Preparation complete."
        echo "Now push the git tag and upload ${TARBALL} and ${TARBALL}.sig to the GitHub release page."
        echo "Then, copy the generated PKGBUILD and .SRCINFO to your local AUR git repository, commit, and push to update the AUR package."
        install_pkg "aur"
        exit 0
    else
        update_checksums
        generate_srcinfo
        install_pkg "$MODE"
        exit 0
    fi
elif [[ "$MODE" == "aur-git" ]]; then
    # Generate PKGBUILD.git from PKGBUILD.0
    cp -f "$PKGBUILD0" "$SCRIPT_DIR/PKGBUILD.git"
    sed -i 's/^pkgname=.*/pkgname=vglog-filter-git/' "$SCRIPT_DIR/PKGBUILD.git"
    sed -E -i 's|^source=\(.*\)|source=("git+https://github.com/eserlxl/vglog-filter.git#branch=main")|' "$SCRIPT_DIR/PKGBUILD.git"
    # Remove any b2sums or sha256sums lines
    sed -i '/^b2sums=/d' "$SCRIPT_DIR/PKGBUILD.git"
    sed -i '/^sha256sums=/d' "$SCRIPT_DIR/PKGBUILD.git"
    # Insert sha256sums=('SKIP') after the source= line using awk -v
    awk -v sums="sha256sums=('SKIP')" '/^source=/ { print; print sums; next } { print }' "$SCRIPT_DIR/PKGBUILD.git" > "$SCRIPT_DIR/PKGBUILD.git.tmp" && mv "$SCRIPT_DIR/PKGBUILD.git.tmp" "$SCRIPT_DIR/PKGBUILD.git"
    # shellcheck disable=SC2016
    # We want to replace the literal text '${pkgname}-${pkgver}' in the PKGBUILD template, not expand shell variables.
    sed -i 's|\${pkgname}-\${pkgver}|\${pkgname%-git}|g; s|\$pkgname-\$pkgver|\${pkgname%-git}|g' "$SCRIPT_DIR/PKGBUILD.git"
    # Remove the global replacements for ${pkgname}-${pkgver} and $pkgname-$pkgver to avoid affecting comments
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
    cp -f "$PKGBUILD_TEMPLATE" "$PKGBUILD"
    log "[aur-git] PKGBUILD.git generated and copied to PKGBUILD."
    # Set validpgpkeys if missing
    if ! grep -q '^validpgpkeys=' "$PKGBUILD"; then
        echo "validpgpkeys=('F677BC1E3BD7246E')" >> "$PKGBUILD"
    fi
    # Check for required tools
    require makepkg
    # Do NOT run updpkgsums for VCS (git) packages, as checksums must be SKIP
    # and updpkgsums would overwrite them with real sums, breaking the PKGBUILD.
    generate_srcinfo
    install_pkg "aur-git"
    exit 0
else
    usage
fi