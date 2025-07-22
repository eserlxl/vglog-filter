#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# vglog-filter build script
#
# Usage: ./build.sh [performance] [warnings] [debug]
#
# Modes:
#   performance : Enables performance optimizations (disables debug mode if both are set)
#   warnings    : Enables extra compiler warnings
#   debug       : Enables debug mode (disables performance mode if both are set)
#
# Notes:
#   - 'performance' and 'debug' are mutually exclusive; enabling one disables the other.
#   - You can combine 'warnings' with either mode.
#   - Example: ./build.sh performance warnings
#
set -euo pipefail

PERFORMANCE_BUILD=OFF
WARNING_MODE=OFF
DEBUG_MODE=OFF

for arg in "$@"; do
  case $arg in
    performance)
      PERFORMANCE_BUILD=ON
      ;;
    warnings)
      WARNING_MODE=ON
      ;;
    debug)
      DEBUG_MODE=ON
      ;;
  esac
done

# If debug is ON, force performance OFF (mutually exclusive)
if [ "$DEBUG_MODE" = "ON" ]; then
  PERFORMANCE_BUILD=OFF
fi

if [ ! -d build ]; then
  mkdir build
fi
cd build

echo "Build configuration:"
echo "  PERFORMANCE_BUILD = $PERFORMANCE_BUILD"
echo "  WARNING_MODE     = $WARNING_MODE"
echo "  DEBUG_MODE       = $DEBUG_MODE"

cmake -DPERFORMANCE_BUILD=$PERFORMANCE_BUILD -DWARNING_MODE=$WARNING_MODE -DDEBUG_MODE=$DEBUG_MODE ..
make -j20 