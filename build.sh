#!/usr/bin/env bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# vglog-filter build script
#
# Usage:
#   ./build.sh [performance] [warnings] [debug] [clean] [tests] [-j N] [--build-dir DIR]
#   ./build.sh --help
#
# Modes:
#   performance : Enables performance optimizations (disables debug mode if both are set)
#   warnings    : Enables extra compiler warnings
#   debug       : Enables debug mode (disables performance mode if both are set)
#   clean       : Removes the build directory for a truly clean CMake configure/build
#   tests       : Builds and runs the test suite (uses ctest if available)
#
# Notes:
#   - 'performance' and 'debug' are mutually exclusive; enabling one disables the other.
#   - You can combine 'warnings' with either mode.
#   - 'clean' wipes the build dir to avoid generator/tool differences (Ninja/Makefiles).
#   - Use -j/--jobs to control parallelism. Defaults to detected CPU count.

set -Eeuo pipefail
IFS=$'\n\t'

# -------- helpers --------------------------------------------------------------
msg()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

on_err() {
  local exit_code=$?
  warn "Build script failed (exit=$exit_code) at line ${BASH_LINENO[0]}."
  exit "$exit_code"
}
trap on_err ERR

# -------- defaults -------------------------------------------------------------
PERFORMANCE_BUILD=OFF
WARNING_MODE=OFF
DEBUG_MODE=OFF
CLEAN_BUILD=OFF
BUILD_TESTS=OFF
RUN_TESTS=OFF

# Allow overrides via env
BUILD_DIR="${BUILD_DIR:-build}"

# Detect CPU count for parallel builds
detect_jobs() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN || echo 1
  else
    echo 1
  fi
}
JOBS="${JOBS:-$(detect_jobs)}"

# -------- resolve project root -------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$SCRIPT_DIR"

# -------- usage ----------------------------------------------------------------
print_help() {
  cat <<EOF
vglog-filter build script

Usage:
  $(basename "$0") [performance] [warnings] [debug] [clean] [tests] [-j N] [--build-dir DIR]
  $(basename "$0") --help

Options/Modes:
  performance        Enable performance optimizations (mutually exclusive with debug)
  warnings           Enable extra compiler warnings
  debug              Enable debug mode (mutually exclusive with performance)
  clean              Remove the build directory and reconfigure
  tests              Build and run tests (ctest if available)
  -j, --jobs N       Parallel build jobs (default: $JOBS)
  --build-dir DIR    Build directory (default: $BUILD_DIR)
  -h, --help         Show this help

Environment overrides:
  BUILD_DIR=/path/to/build   Set build directory
  JOBS=N                     Set parallel build jobs
EOF
}

# -------- arg parsing ----------------------------------------------------------
if [[ $# -eq 0 ]]; then
  : # default config is fine; still print summary later
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    performance) PERFORMANCE_BUILD=ON; shift ;;
    warnings)    WARNING_MODE=ON; shift ;;
    debug)       DEBUG_MODE=ON; shift ;;
    clean)       CLEAN_BUILD=ON; shift ;;
    tests)       BUILD_TESTS=ON; RUN_TESTS=ON; shift ;;
    -j|--jobs)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      [[ "$2" =~ ^[0-9]+$ ]] || die "Invalid jobs value: $2"
      JOBS="$2"; shift 2 ;;
    --build-dir)
      [[ $# -ge 2 ]] || die "Missing value for --build-dir"
      BUILD_DIR="$2"; shift 2 ;;
    -h|--help) print_help; exit 0 ;;
    *)
      warn "Unknown argument '$1' will be ignored"
      shift ;;
  esac
done

# Mutually exclusive: debug wins over performance
if [[ "$DEBUG_MODE" == "ON" ]]; then
  PERFORMANCE_BUILD=OFF
fi

# -------- sanity checks --------------------------------------------------------
command -v cmake >/dev/null 2>&1 || die "cmake not found"
# ctest is optional; we'll detect it later
# generator is auto; users can set CMAKE_GENERATOR env externally if desired

# -------- prepare build dir ----------------------------------------------------
cd "$PROJECT_ROOT"

if [[ "$CLEAN_BUILD" == "ON" ]]; then
  msg "Clean build requested: removing '$BUILD_DIR'..."
  rm -rf -- "$BUILD_DIR"
fi

mkdir -p -- "$BUILD_DIR"

# -------- configuration summary ------------------------------------------------
msg "Build configuration:"
msg "  PROJECT_ROOT    = $PROJECT_ROOT"
msg "  BUILD_DIR       = $BUILD_DIR"
msg "  PERFORMANCE     = $PERFORMANCE_BUILD"
msg "  WARNINGS        = $WARNING_MODE"
msg "  DEBUG           = $DEBUG_MODE"
msg "  BUILD_TESTS     = $BUILD_TESTS"
msg "  RUN_TESTS       = $RUN_TESTS"
msg "  JOBS            = $JOBS"
if [[ -n "${CMAKE_GENERATOR:-}" ]]; then
  msg "  CMAKE_GENERATOR = $CMAKE_GENERATOR"
fi

# -------- configure ------------------------------------------------------------
# Use -S/-B to keep cwd stable and avoid generator-specific assumptions.
cmake \
  -S "$PROJECT_ROOT" \
  -B "$BUILD_DIR" \
  -DPERFORMANCE_BUILD="$PERFORMANCE_BUILD" \
  -DWARNING_MODE="$WARNING_MODE" \
  -DDEBUG_MODE="$DEBUG_MODE" \
  -DBUILD_TESTS="$BUILD_TESTS"

# -------- build ----------------------------------------------------------------
cmake --build "$BUILD_DIR" --parallel "$JOBS"

# -------- run tests (if requested) ---------------------------------------------
if [[ "$RUN_TESTS" == "ON" ]]; then
  msg "Running tests..."

  # Pre-test cleanup of stray temp files
  msg "Cleaning up any leftover test files (*.tmp) before tests..."
  find "$PROJECT_ROOT" -type f -name '*.tmp' -delete 2>/dev/null || true

  if command -v ctest >/dev/null 2>&1; then
    # Prefer ctest, honoring CMake's test config
    ctest --test-dir "$BUILD_DIR" --output-on-failure --parallel "$JOBS"
    msg "All tests completed (ctest)."
  else
    warn "ctest not found; attempting to run test executables directly."
    # Fallback: run any test_* executable in the build dir
    shopt -s nullglob
    tests_found=0
    for tbin in "$BUILD_DIR"/bin/test_*; do
      if [[ -x "$tbin" ]]; then
        msg "Running $(basename "$tbin") ..."
        "$tbin"
        tests_found=1
      fi
    done
    shopt -u nullglob
    if [[ "$tests_found" -eq 0 ]]; then
      warn "No test executables found in '$BUILD_DIR/bin'."
      warn "If tests are defined, ensure CMake config enables them (BUILD_TESTS=ON)."
    else
      msg "All tests completed (direct executables)."
    fi
  fi

  # Post-test cleanup
  msg "Cleaning up any leftover test files (*.tmp) after tests..."
  find "$PROJECT_ROOT" -type f -name '*.tmp' -delete 2>/dev/null || true
fi

msg "Done."
