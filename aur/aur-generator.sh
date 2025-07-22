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
    echo "Usage: $0 [local|aur]"
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

if [[ "$MODE" == "local" ]]; then
    cp -f "$PKGBUILD0" "$PKGBUILD"
    echo "[local] PKGBUILD.0 copied to PKGBUILD."
elif [[ "$MODE" == "aur" ]]; then
    cp -f "$PKGBUILD0" "$PKGBUILD"
    sed -i "s|source=(\".*\")|source=(\"https://github.com/eserlxl/vglog-filter/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
    echo "[aur] Updated source line in PKGBUILD."
    # Check for required tools
    for tool in updpkgsums makepkg; do
        if ! command -v $tool >/dev/null 2>&1; then
            echo "Error: $tool is required but not installed."
            exit 1
        fi
    done
    updpkgsums
    echo "[aur] Ran updpkgsums."
    if command -v mksrcinfo >/dev/null 2>&1; then
        mksrcinfo
        echo "[aur] Updated .SRCINFO with mksrcinfo."
    elif command -v makepkg >/dev/null 2>&1; then
        makepkg --printsrcinfo > .SRCINFO
        echo "[aur] Updated .SRCINFO with makepkg --printsrcinfo."
    else
        echo "Warning: Could not update .SRCINFO (mksrcinfo/makepkg not found)."
    fi
    makepkg -si
else
    usage
    exit 0
fi

makepkg -si