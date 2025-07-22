#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PKGNAME=vglog-filter
PKGVER=1.0.0
TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
OUTDIR="$SCRIPT_DIR"
PKGBUILD0="$SCRIPT_DIR/PKGBUILD.0"
PKGBUILD="$SCRIPT_DIR/PKGBUILD"
SRCINFO="$SCRIPT_DIR/.SRCINFO"

function usage() {
    echo "Usage: $0 [local|aur|clean]"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

MODE="$1"

# Always create the tarball for both modes
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

cd "$SCRIPT_DIR"

if [[ ! -f "$PKGBUILD0" ]]; then
    echo "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    exit 1
fi

if [[ "$MODE" == "clean" ]]; then
    echo "Cleaning AUR directory..."
    rm -f "$OUTDIR/$TARBALL" "$PKGBUILD" "$SRCINFO"
    rm -rf "$SCRIPT_DIR/src" "$SCRIPT_DIR/pkg"
    rm -f "$SCRIPT_DIR"/*.pkg.tar.*
    echo "Clean complete."
    exit 0
fi

if [[ "$MODE" == "local" || "$MODE" == "aur" ]]; then
    cp -f "$PKGBUILD0" "$PKGBUILD"
    echo "[$MODE] PKGBUILD.0 copied to PKGBUILD."
    if [[ "$MODE" == "aur" ]]; then
        sed -i "s|source=(\".*\")|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
        echo "[aur] Updated source line in PKGBUILD."
    fi
    # Check for required tools
    for tool in updpkgsums makepkg; do
        if ! command -v $tool >/dev/null 2>&1; then
            echo "Error: $tool is required but not installed."
            exit 1
        fi
    done
    updpkgsums
    echo "[$MODE] Ran updpkgsums (b2sums updated)."
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
    cp -f "$PKGBUILD0" "$PKGBUILD"
    echo "[aur-git] PKGBUILD.0 copied to PKGBUILD."
    # Replace source, sha256sums, and validpgpkeys
    sed -i "s|source=(\".*\")|source=(\"git+https://github.com/eserlxl/${PKGNAME}.git#tag=v${PKGVER}\")|" "$PKGBUILD"
    if grep -q '^sha256sums=' "$PKGBUILD"; then
        sed -i "s|^sha256sums=.*|sha256sums=('SKIP')|" "$PKGBUILD"
    else
        echo "sha256sums=('SKIP')" >> "$PKGBUILD"
    fi
    if grep -q '^validpgpkeys=' "$PKGBUILD"; then
        sed -i "s|^validpgpkeys=.*|validpgpkeys=('F677BC1E3BD7246E')|" "$PKGBUILD"
    else
        echo "validpgpkeys=('F677BC1E3BD7246E')" >> "$PKGBUILD"
    fi
    # Check for required tools
    for tool in updpkgsums makepkg; do
        if ! command -v $tool >/dev/null 2>&1; then
            echo "Error: $tool is required but not installed."
            exit 1
        fi
    done
    updpkgsums
    echo "[aur-git] Ran updpkgsums (b2sums updated)."
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