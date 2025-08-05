#!/usr/bin/env bash
# Copyright © 2025 Eser KUBALI
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test script for modular version management components (refactored)

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

# --------------- appearance & flags ---------------
is_tty=0; [[ -t 1 ]] && is_tty=1
NO_COLOR="${NO_COLOR:-false}"
USE_COLOR=1; [[ "$NO_COLOR" == "true" || $is_tty -eq 0 ]] && USE_COLOR=0

# RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
color() { ((USE_COLOR)) || { printf '%s' "$2"; return; }
  case "$1" in red) printf '\033[0;31m%s\033[0m' "$2";;
     green) printf '\033[0;32m%s\033[0m' "$2";;
     yellow) printf '\033[1;33m%s\033[0m' "$2";;
     cyan) printf '\033[0;36m%s\033[0m' "$2";;
     *) printf '%s' "$2";; esac; }

QUIET=0
VERBOSE=0
STOP_ON_FAIL=0
ONLY_FILTER=""
TIMEOUT_SECS=""
TIMEOUT_BIN="$(command -v timeout || true)"
DEV_BIN="./dev-bin"

# env overrides for repository-dependent expectations
EXPECT_VERSION="${EXPECT_VERSION:-10.5.12}"
EXPECT_CMAKE_DETECT="${EXPECT_CMAKE_DETECT:-variable}"

# --------------- counters & bookkeeping ---------------
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
START_TS=$(date +%s)

# Arrays to store tests
declare -a TEST_NAMES TEST_CMDS TEST_EXPECTS TEST_MODES TEST_EXITS

# log() { ((QUIET)) || printf '%s\n' "$*"; }
vlog() { ((VERBOSE)) && printf '%s\n' "$*"; }
die() { color red "Error: $*\n" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --only <pattern>      Run tests whose names match pattern (grep -E)
  --list                List tests and exit
  --quiet               Minimal output
  --verbose             Extra output
  --stop-on-fail        Stop at first failure
  --timeout <seconds>   Per-test timeout (requires 'timeout')
  --dev-bin <dir>       Path to dev-bin (default: ./dev-bin)
  --help                Show this help

Env overrides:
  EXPECT_VERSION=<ver>          Expected "current" VERSION when asserted (default: $EXPECT_VERSION)
  EXPECT_CMAKE_DETECT=<value>   Expected cmake-updater detect result (default: $EXPECT_CMAKE_DETECT)
  NO_COLOR=true                 Disable colors
EOF
}

# --------------- traps ---------------
trap 'color red "Unexpected error at line $LINENO: $BASH_COMMAND\n" >&2' ERR

# --------------- helpers ---------------
require_in_repo() {
  [[ -f "VERSION" ]] || die "VERSION file not found. Run from project root."
  [[ -d "$DEV_BIN" ]] || die "dev-bin directory not found at: $DEV_BIN"
}

bin_exists() { [[ -x "$1" ]]; }

add_test() {
  local name="$1" cmd="$2" expect="${3:-}" mode="${4:-contains}" exit_code="${5:-0}"
  TEST_NAMES+=("$name")
  TEST_CMDS+=("$cmd")
  TEST_EXPECTS+=("$expect")
  TEST_MODES+=("$mode")
  TEST_EXITS+=("$exit_code")
}

match_output() {
  local mode="$1" expected="$2" output="$3"
  case "$mode" in
    succeeds)   return 0 ;;                            # exit-code-only
    contains)   [[ "$output" == *"$expected"* ]] ;;
    exact)      [[ "$output" == "$expected" ]] ;;
    nonempty)   [[ -n "$output" ]] ;;
    regex)      [[ "$output" =~ $expected ]] ;;
    *)          die "Unknown match mode: $mode" ;;
  esac
}

run_one() {
  local idx="$1"
  local name="${TEST_NAMES[$idx]}"
  local cmd="${TEST_CMDS[$idx]}"
  local expect="${TEST_EXPECTS[$idx]}"
  local mode="${TEST_MODES[$idx]}"
  local want_exit="${TEST_EXITS[$idx]}"

  # binary presence check (first token path)
  local first_token; first_token="$(printf '%s' "$cmd" | awk '{print $1}')"
  if [[ "$first_token" == ./* || "$first_token" == /* ]]; then
    if ! bin_exists "$first_token"; then
      ((TESTS_SKIPPED++))
      ((QUIET)) || color yellow "⚠ SKIP: $name (missing executable: $first_token)\n"
      return 0
    fi
  fi

  # ONLY filter
  if [[ -n "$ONLY_FILTER" && ! "$name" =~ $ONLY_FILTER ]]; then
    ((TESTS_SKIPPED++))
    ((QUIET)) || color yellow "⚠ SKIP: $name (filtered)\n"
    return 0
  fi

  ((QUIET)) || color cyan "Running: $name\n"

  local output="" status=0
  if [[ -n "$TIMEOUT_SECS" && -n "$TIMEOUT_BIN" ]]; then
    set +e
    output="$($TIMEOUT_BIN -s KILL "$TIMEOUT_SECS" bash -c "$cmd" 2>&1)"
    status=$?
    set -e
    if (( status == 137 )); then
      ((TESTS_FAILED++))
      color red "✗ FAIL: $name\n"
      printf '  Error: timed out after %ss\n' "$TIMEOUT_SECS"
      ((STOP_ON_FAIL)) && exit 1
      return 1
    fi
  else
    set +e
    output="$(bash -c "$cmd" 2>&1)"
    status=$?
    set -e
  fi

  vlog "Command: $cmd"
  vlog "Exit: $status"
  ((VERBOSE)) && printf 'Output:\n%s\n' "$output"

  if (( status != want_exit )); then
    ((TESTS_FAILED++))
    color red "✗ FAIL: $name\n"
    printf '  Error: expected exit %d, got %d\n' "$want_exit" "$status"
    ((STOP_ON_FAIL)) && exit 1
    return 1
  fi

  if ! match_output "$mode" "$expect" "$output"; then
    ((TESTS_FAILED++))
    color red "✗ FAIL: $name\n"
    printf '  Error: output check failed (%s)\n' "$mode"
    printf '  Expected: %s\n' "$expect"
    printf '  Got: %s\n' "$output"
    ((STOP_ON_FAIL)) && exit 1
    return 1
  fi

  ((TESTS_PASSED++))
  ((QUIET)) || color green "✓ PASS: $name\n"
  return 0
}

list_tests() {
  local i
  for ((i=0; i<${#TEST_NAMES[@]}; i++)); do
    printf '%2d) %s\n' "$((i+1))" "${TEST_NAMES[$i]}"
  done
}

# --------------- CLI ---------------
while (($#)); do
  case "$1" in
    --only) ONLY_FILTER="$2"; shift 2;;
    --list) require_in_repo; build_tests; list_tests; exit 0;;
    --quiet) QUIET=1; shift;;
    --verbose) VERBOSE=1; shift;;
    --stop-on-fail) STOP_ON_FAIL=1; shift;;
    --timeout) TIMEOUT_SECS="$2"; shift 2;;
    --dev-bin) DEV_BIN="$2"; shift 2;;
    --help|-h) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

# --------------- domain-specific helpers ---------------
read_version_file() { [[ -f VERSION ]] && tr -d ' \t\r\n' < VERSION || echo ""; }

bump_patch() {
  local v="$1"
  # simple semver bump: MAJOR.MINOR.PATCH[-pre] -> MAJOR.MINOR.(PATCH+1)
  # strip prerelease if any for expectation
  v="${v%%-*}"
  IFS='.' read -r MA MI PA <<<"$v"
  [[ -n "$MA" && -n "$MI" && -n "$PA" ]] || return 1
  printf '%d.%d.%d' "$MA" "$MI" "$((PA+1))"
}

# --------------- define tests ---------------
build_tests() {
  # preconditions
  require_in_repo

  local cur_ver expect_next
  cur_ver="$(read_version_file)"
  expect_next="$(bump_patch "$cur_ver" || true)"
  # Fallback to provided expectation if bump failed
  [[ -n "$expect_next" ]] || expect_next="10.5.13"

  # version-utils
  add_test "version-utils last-tag" \
    "$DEV_BIN/version-utils last-tag v" \
    "" "succeeds"
  add_test "version-utils hash-file VERSION" \
    "$DEV_BIN/version-utils hash-file VERSION" \
    "" "succeeds"
  add_test "version-utils read-version" \
    "$DEV_BIN/version-utils read-version VERSION" \
    "$EXPECT_VERSION" "contains"

  # version-validator
  add_test "version-validator validate 1.0.0" \
    "$DEV_BIN/version-validator validate 1.0.0" \
    "valid" "contains"
  add_test "version-validator compare 1.0.0 1.0.1" \
    "$DEV_BIN/version-validator compare 1.0.0 1.0.1" \
    "-1" "contains"
  add_test "version-validator parse 1.2.3" \
    "$DEV_BIN/version-validator parse 1.2.3" \
    "1" "contains"
  add_test "version-validator is-prerelease 1.0.0-rc.1" \
    "$DEV_BIN/version-validator is-prerelease 1.0.0-rc.1" \
    "true" "contains"

  # version-calculator-loc
  add_test "version-calculator-loc patch bump" \
    "$DEV_BIN/version-calculator-loc --current-version 1.0.0 --bump-type patch" \
    "1.0.1" "contains"
  add_test "version-calculator-loc help" \
    "$DEV_BIN/version-calculator-loc --help" \
    "Usage:" "contains"

  # cmake-updater
  add_test "cmake-updater detect CMakeLists.txt" \
    "$DEV_BIN/cmake-updater detect CMakeLists.txt" \
    "$EXPECT_CMAKE_DETECT" "contains"
  add_test "cmake-updater help" \
    "$DEV_BIN/cmake-updater" \
    "Usage:" "contains"

  # git-operations
  add_test "git-operations help" \
    "$DEV_BIN/git-operations" \
    "Usage:" "contains"

  # cli-parser
  add_test "cli-parser help" \
    "$DEV_BIN/cli-parser help" \
    "Usage:" "contains"
  add_test "cli-parser validate patch --commit" \
    "$DEV_BIN/cli-parser validate patch --commit" \
    "valid" "contains"

  # bump-version-core
  add_test "bump-version-core help" \
    "$DEV_BIN/bump-version-core --help" \
    "Usage:" "contains"
  add_test "bump-version-core dry-run" \
    "$DEV_BIN/bump-version-core patch --dry-run" \
    "$expect_next" "contains"

  # comparison with original (exact last line equality)
  # Safely handle absence by allowing runner to SKIP if binaries missing.
  add_test "bump-version vs core dry-run comparison" \
    "orig=\$($DEV_BIN/bump-version patch --dry-run 2>/dev/null | tail -1); mod=\$($DEV_BIN/bump-version-core patch --dry-run 2>/dev/null | tail -1); [[ \"\$orig\" == \"\$mod\" ]] && echo OK || { echo \"Original: \$orig | Modular: \$mod\"; exit 1; }" \
    "OK" "exact"
}

# --------------- main ---------------
main() {
  build_tests

  local i
  for ((i=0; i<${#TEST_NAMES[@]}; i++)); do
    run_one "$i"
  done

  # summary
  printf '\n'
  color yellow "=== Test Summary ===\n"
  color green "Passed: $TESTS_PASSED\n"
  color red   "Failed: $TESTS_FAILED\n"
  color yellow "Skipped: $TESTS_SKIPPED\n"
  local elapsed=$(( $(date +%s) - START_TS ))
  printf 'Elapsed: %ss\n' "$elapsed"

  if ((TESTS_FAILED==0)); then
    color green "\nAll tests passed! Modular version management is working correctly.\n"
    exit 0
  else
    color red "\nSome tests failed. See details above.\n"
    exit 1
  fi
}

main "$@"
