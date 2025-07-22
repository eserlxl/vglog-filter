#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PKGNAME=vglog-filter

function usage() {
    echo "Usage: $0 [local|aur|aur-git|clean]"
    echo
    echo "Modes:"
    echo "  local     Build and install the package from a local tarball (for testing)."
    echo "  aur       Prepare a release tarball, sign it with GPG, and update PKGBUILD for AUR upload."
    echo "  aur-git   Generate a PKGBUILD for the -git (VCS) AUR package (no tarball/signing)."
    echo "  clean     Remove all generated files and directories in the aur/ folder."
    echo
    echo "Notes:"
    echo "- Requires PKGBUILD.0 as the template for PKGBUILD generation."
    echo "- For 'aur' mode, a GPG secret key is required for signing the tarball."
    echo "- For 'aur' and 'local' modes, the script will attempt to update checksums and .SRCINFO."
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

MODE="$1"
echo "Running in $MODE mode"
case "$MODE" in
    local)
        echo "[local] Build and install from local tarball."
        ;;
    aur)
        echo "[aur] Prepare for AUR upload: creates tarball, GPG signature, and PKGBUILD for release."
        ;;
    aur-git)
        echo "[aur-git] Prepare PKGBUILD for VCS (git) package. No tarball is created."
        ;;
    clean)
        echo "[clean] Remove generated files and directories."
        # Clean mode does not require PKGVER or PKGBUILD0
        OUTDIR="$SCRIPT_DIR"
        PKGBUILD="$SCRIPT_DIR/PKGBUILD"
        SRCINFO="$SCRIPT_DIR/.SRCINFO"
        TARBALL_GLOB="$SCRIPT_DIR/"${PKGNAME}-*.tar.gz
        echo "Cleaning AUR directory..."
        rm -f $TARBALL_GLOB $TARBALL_GLOB.sig "$PKGBUILD" "$SRCINFO"
        rm -rf "$SCRIPT_DIR/src" "$SCRIPT_DIR/pkg"
        rm -f "$SCRIPT_DIR"/*.pkg.tar.*
        echo "Clean complete."
        exit 0
        ;;
esac

# Only define PKGVER and PKGVER-dependent variables for non-clean modes
PKGBUILD0="$SCRIPT_DIR/PKGBUILD.0"
if [[ ! -f "$PKGBUILD0" ]]; then
    echo "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    exit 1
fi
source "$PKGBUILD0"
PKGVER="$pkgver"
TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
OUTDIR="$SCRIPT_DIR"
PKGBUILD="$SCRIPT_DIR/PKGBUILD"
SRCINFO="$SCRIPT_DIR/.SRCINFO"

# Check for PKGBUILD.0 and source pkgver early
if [[ ! -f "$PKGBUILD0" ]]; then
    echo "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    exit 1
fi
source "$PKGBUILD0"
PKGVER="$pkgver"

# Only create the tarball for aur and local modes
if [[ "$MODE" == "aur" || "$MODE" == "local" ]]; then
    cd "$PROJECT_ROOT"
    tar --exclude-vcs \
        --exclude="**/${TARBALL}" \
        --exclude=".github" \
        --exclude=".vscode" \
        --exclude="Backups" \
        --exclude="CMakeFiles" \
        --exclude="aur" \
        --exclude="build" \
        --exclude="doc" \
        -czf "$OUTDIR/$TARBALL" . --transform "s,^.,${PKGNAME}-${PKGVER},"
    echo "Created $OUTDIR/$TARBALL"

    # Create GPG signature for aur mode only
    if [[ "$MODE" == "aur" ]]; then
        # Check for GPG secret key before signing
        if ! gpg --list-secret-keys | grep -q '^sec'; then
            echo "Error: No GPG secret key found. Please generate or import a GPG key before signing."
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
                echo "No GPG secret keys found."
                exit 1
            fi
            echo "Available GPG secret keys:" >&2
            for i in "${!KEYS[@]}"; do
                USER=$(gpg --list-secret-keys "${KEYS[$i]}" | grep uid | head -n1 | sed 's/.*] //')
                echo "$((i+1)). ${KEYS[$i]} ($USER)" >&2
            done
            read -rp "Select a key [1-${#KEYS[@]}]: " choice
            if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#KEYS[@]} )); then
                echo "Invalid selection."
                exit 1
            fi
            GPG_KEY="${KEYS[$((choice-1))]}"
        fi
        if [[ -n "$GPG_KEY" ]]; then
            gpg --detach-sign -u "$GPG_KEY" --output "$OUTDIR/$TARBALL.sig" "$OUTDIR/$TARBALL"
        else
            gpg --detach-sign --output "$OUTDIR/$TARBALL.sig" "$OUTDIR/$TARBALL"
        fi
        echo "[aur] Created GPG signature: $OUTDIR/$TARBALL.sig"
    fi
fi

cd "$SCRIPT_DIR"

if [[ "$MODE" == "local" || "$MODE" == "aur" ]]; then
    cp -f "$PKGBUILD0" "$PKGBUILD"
    echo "[$MODE] PKGBUILD.0 copied to PKGBUILD."
    if [[ "$MODE" == "aur" ]]; then
        sed -i "s|source=(\".*\")|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
        echo "[aur] Updated source line in PKGBUILD."
        # Check if the tarball exists on GitHub before running updpkgsums
        TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
        if curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
            updpkgsums
            echo "[aur] Ran updpkgsums (b2sums updated)."
        else
            echo "[aur] Release asset not found at $TARBALL_URL. Skipping updpkgsums."
            echo "After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums."
        fi
    else
        updpkgsums
        echo "[$MODE] Ran updpkgsums (b2sums updated)."
    fi
    # Always generate .SRCINFO from PKGBUILD
    if command -v mksrcinfo >/dev/null 2>&1; then
        mksrcinfo
        echo "[$MODE] Updated .SRCINFO with mksrcinfo."
    elif command -v makepkg >/dev/null 2>&1; then
        makepkg --printsrcinfo > .SRCINFO
        echo "[$MODE] Updated .SRCINFO with makepkg --printsrcinfo."
    else
        echo "Warning: Could not update .SRCINFO (mksrcinfo/makepkg not found)."
    fi
    makepkg -si
    exit 0
elif [[ "$MODE" == "aur-git" ]]; then
    # Generate PKGBUILD.git from PKGBUILD.0
    cp -f "$PKGBUILD0" "$SCRIPT_DIR/PKGBUILD.git"
    sed -i 's/^pkgname=.*/pkgname=vglog-filter-git/' "$SCRIPT_DIR/PKGBUILD.git"
    sed -i 's|^source=(.*)|source=("git+https://github.com/eserlxl/vglog-filter.git#branch=main")|' "$SCRIPT_DIR/PKGBUILD.git"
    sed -i 's/^b2sums=.*/sha256sums=(\'SKIP\')/' "$SCRIPT_DIR/PKGBUILD.git"
    if ! grep -q '^sha256sums=' "$SCRIPT_DIR/PKGBUILD.git"; then
        echo "sha256sums=('SKIP')" >> "$SCRIPT_DIR/PKGBUILD.git"
    fi
    if ! grep -q '^pkgver()' "$SCRIPT_DIR/PKGBUILD.git"; then
        sed -i "/^source=/a \
pkgver() {\n  cd \"\$srcdir/\${pkgname%-git}\"\n  git describe --long --tags 2>/dev/null | sed \"s/^v//;s/-/./g\" || \\\n  printf \"r%s.%s\" \"\$(git rev-list --count HEAD)\" \"\$(git rev-parse --short HEAD)\"\n}\n" "$SCRIPT_DIR/PKGBUILD.git"
    fi
    PKGBUILD_TEMPLATE="$SCRIPT_DIR/PKGBUILD.git"
    cp -f "$PKGBUILD_TEMPLATE" "$PKGBUILD"
    echo "[aur-git] PKGBUILD.git generated and copied to PKGBUILD."
    # Set validpgpkeys if missing
    if ! grep -q '^validpgpkeys=' "$PKGBUILD"; then
        echo "validpgpkeys=('F677BC1E3BD7246E')" >> "$PKGBUILD"
    fi
    # Check for required tools
    for tool in makepkg; do
        if ! command -v $tool >/dev/null 2>&1; then
            echo "Error: $tool is required but not installed."
            exit 1
        fi
    done
    # Do NOT run updpkgsums for VCS (git) packages, as checksums must be SKIP
    # and updpkgsums would overwrite them with real sums, breaking the PKGBUILD.
    # Always generate .SRCINFO from PKGBUILD
    if command -v mksrcinfo >/dev/null 2>&1; then
        mksrcinfo
        echo "[aur-git] Updated .SRCINFO with mksrcinfo."
    elif command -v makepkg >/dev/null 2>&1; then
        makepkg --printsrcinfo > .SRCINFO
        echo "[aur-git] Updated .SRCINFO with makepkg --printsrcinfo."
    else
        echo "Warning: Could not update .SRCINFO (mksrcinfo/makepkg not found)."
    fi
    makepkg -si
    exit 0
else
    usage
fi