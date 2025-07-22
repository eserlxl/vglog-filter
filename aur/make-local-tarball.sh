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

cd "$PROJECT_ROOT"
tar --exclude-vcs --exclude="**/${TARBALL}" -czf "$OUTDIR/$TARBALL" . --transform "s,^.,${PKGNAME}-${PKGVER},"
echo "Created $OUTDIR/$TARBALL" 