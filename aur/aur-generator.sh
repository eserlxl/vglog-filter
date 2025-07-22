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

# Helper: require tools
require() { for t; do command -v "$t" >/dev/null || { echo "Missing $t"; exit 1; }; done; }

readonly PKGNAME="vglog-filter"

function usage() {
    echo "Usage: $0 [local|aur|aur-git|clean]"
    echo
    echo "Modes:"
    echo "  local     Build and install the package from a local tarball (for testing)."
    echo "  aur       Prepare a release tarball, sign it with GPG, and update PKGBUILD for AUR upload."
    echo "  aur-git   Generate a PKGBUILD for the -git (VCS) AUR package (no tarball/signing)."
    echo "  clean     Remove all generated files and directories"
    echo
    echo "Notes:"
    echo "- Requires PKGBUILD.0 as the template for PKGBUILD generation."
    echo "- For 'aur' mode, a GPG secret key is required for signing the tarball."
    echo "- For 'aur' and 'local' modes, the script will attempt to update checksums and .SRCINFO."
    echo "- To skip the GPG key selection menu in 'aur' mode, set GPG_KEY_ID to your key's ID:"
    echo "    GPG_KEY_ID=ABCDEF ./aur-generator.sh aur"
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
        require makepkg updpkgsums curl
        ;;
    aur)
        echo "[aur] Prepare for AUR upload: creates tarball, GPG signature, and PKGBUILD for release."
        require makepkg updpkgsums curl gpg
        ;;
    aur-git)
        echo "[aur-git] Prepare PKGBUILD for VCS (git) package. No tarball is created."
        require makepkg
        ;;
    clean)
        echo "[clean] Remove generated files and directories."
        # Clean mode does not require PKGVER or PKGBUILD0
        OUTDIR="$SCRIPT_DIR"
        PKGBUILD="$SCRIPT_DIR/PKGBUILD"
        SRCINFO="$SCRIPT_DIR/.SRCINFO"
        shopt -s nullglob
        TARBALL_GLOB=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz)
        # Use an explicit array to safely handle files with spaces
        files=("${TARBALL_GLOB[@]}" "${TARBALL_GLOB[@]/%/.sig}")
        echo "Cleaning AUR directory..."
        rm -f "${files[@]}" "$PKGBUILD" "$SRCINFO"
        rm -rf "$SCRIPT_DIR/src" "$SCRIPT_DIR/pkg"
        rm -f "$SCRIPT_DIR"/*.pkg.tar.*
        shopt -u nullglob
        echo "Clean complete."
        exit 0
        ;;
esac

# Only define PKGVER and PKGVER-dependent variables for non-clean modes
PKGBUILD0="$SCRIPT_DIR/PKGBUILD.0"
readonly PKGBUILD0
if [[ ! -f "$PKGBUILD0" ]]; then
    echo "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    exit 1
fi
# Extract pkgver from PKGBUILD.0 without sourcing
PKGVER=$(awk -F= '/^[[:space:]]*pkgver[[:space:]]*=/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$PKGBUILD0" | tr -d "\"'")
if [[ -z "$PKGVER" ]]; then
    echo "Error: Could not extract pkgver from $PKGBUILD0"
    exit 1
fi
readonly PKGVER
TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
readonly OUTDIR="$SCRIPT_DIR"
PKGBUILD="$SCRIPT_DIR/PKGBUILD"
SRCINFO="$SCRIPT_DIR/.SRCINFO"

# Only create the tarball for aur and local modes
if [[ "$MODE" == "aur" || "$MODE" == "local" ]]; then
    cd "$PROJECT_ROOT"
    tar --exclude-vcs \
        --exclude="./${TARBALL}" \
        --exclude=".github" \
        --exclude=".vscode" \
        --exclude="Backups" \
        --exclude="CMakeFiles" \
        --exclude="aur" \
        --exclude="build" \
        --exclude="doc" \
        --numeric-owner --owner=0 --group=0 --mtime='@0' --format=gnu \
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
        # Fix: Try correct link first, fallback to old 'v' link if needed
        sed -E -i "s|^([[:space:]]*source=\([^)]*\))([[:space:]]*#.*)?$|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}\")\2|" "$PKGBUILD"
        echo "[aur] Updated source line in PKGBUILD (no 'v' before version)."
        # Check if the tarball exists on GitHub before running updpkgsums
        TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}"
        if ! curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
            echo "[aur] WARNING: Release asset not found at $TARBALL_URL. Trying fallback with 'v' prefix."
            sed -i "s|source=(\".*\")|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
            TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
            if ! curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
                echo "[aur] ERROR: Release asset not found at either $TARBALL_URL or without 'v'. Aborting."
                echo "After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums."
                exit 1
            fi
        fi
        updpkgsums
        echo "[aur] Ran updpkgsums (b2sums updated)."
        # Always generate .SRCINFO from PKGBUILD
        if command -v makepkg >/dev/null 2>&1; then
            makepkg --printsrcinfo > .SRCINFO
            echo "[aur] Updated .SRCINFO with makepkg --printsrcinfo."
        elif command -v mksrcinfo >/dev/null 2>&1; then
            mksrcinfo
            echo "[aur] Updated .SRCINFO with mksrcinfo (deprecated, please update your tools)."
        else
            echo "Warning: Could not update .SRCINFO (makepkg --printsrcinfo/mksrcinfo not found)."
        fi
        echo "[aur] Preparation complete."
        echo "Now push the git tag and upload ${TARBALL} and ${TARBALL}.sig to the GitHub release page."
        echo "Then, copy the generated PKGBUILD and .SRCINFO to your local AUR git repository, commit, and push to update the AUR package."
        # Honour CI=1 or AUTO=y to auto-answer "no" to the makepkg -si question (for CI/automation)
        if [[ "${CI:-}" == 1 || "${AUTO:-}" == "y" ]]; then
            run_makepkg=n
        else
            read -rp "Do you want to run makepkg -si now? [y/N] " run_makepkg
        fi
        if [[ "$run_makepkg" =~ ^[Yy]$ ]]; then
            makepkg -si
        fi
        exit 0
    else
        updpkgsums
        echo "[$MODE] Ran updpkgsums (b2sums updated)."
        # Always generate .SRCINFO from PKGBUILD
        if command -v makepkg >/dev/null 2>&1; then
            makepkg --printsrcinfo > .SRCINFO
            echo "[$MODE] Updated .SRCINFO with makepkg --printsrcinfo."
        elif command -v mksrcinfo >/dev/null 2>&1; then
            mksrcinfo
            echo "[$MODE] Updated .SRCINFO with mksrcinfo (deprecated, please update your tools)."
        else
            echo "Warning: Could not update .SRCINFO (makepkg --printsrcinfo/mksrcinfo not found)."
        fi
        makepkg -si
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
  git describe --long --tags 2>/dev/null | sed "s/^v//;s/-/./g" || \\
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
    echo "[aur-git] PKGBUILD.git generated and copied to PKGBUILD."
    # Set validpgpkeys if missing
    if ! grep -q '^validpgpkeys=' "$PKGBUILD"; then
        echo "validpgpkeys=('F677BC1E3BD7246E')" >> "$PKGBUILD"
    fi
    # Check for required tools
    require makepkg
    # Do NOT run updpkgsums for VCS (git) packages, as checksums must be SKIP
    # and updpkgsums would overwrite them with real sums, breaking the PKGBUILD.
    # Always generate .SRCINFO from PKGBUILD
    if command -v makepkg >/dev/null 2>&1; then
        makepkg --printsrcinfo > .SRCINFO
        echo "[aur-git] Updated .SRCINFO with makepkg --printsrcinfo."
    elif command -v mksrcinfo >/dev/null 2>&1; then
        mksrcinfo
        echo "[aur-git] Updated .SRCINFO with mksrcinfo."
    else
        echo "Warning: Could not update .SRCINFO (makepkg --printsrcinfo/mksrcinfo not found)."
    fi
    makepkg -si
    exit 0
else
    usage
fi