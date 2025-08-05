#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for modular semantic version analyzer components

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Keep Git fast and quiet inside tests
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=1

# ---------------------- appearance & output ----------------------
is_tty=0; [[ -t 1 ]] && is_tty=1
USE_COLOR=1
QUIET=0
VERBOSE=0
KEEP_OUTPUT=0
TIMEOUT=""
TIMEOUT_BIN="$(command -v timeout || true)"

color() { 
    ((USE_COLOR && is_tty)) || { printf '%s' "$2"; return; }
    case "$1" in
        red) printf '\033[0;31m%s\033[0m' "$2" ;;
        grn) printf '\033[0;32m%s\033[0m' "$2" ;;
        yel) printf '\033[1;33m%s\033[0m' "$2" ;;
        blu) printf '\033[0;34m%s\033[0m' "$2" ;;
        dim) printf '\033[2m%s\033[0m' "$2" ;;
        *)  printf '%s' "$2" ;;
    esac
}
say() { ((QUIET)) || printf '%s\n' "$*"; }
sayc() { ((QUIET)) || { color "$1" "$2"; printf '\n'; } }
die() { sayc red "Error: $*"; exit 1; }

# ---------------------- args ----------------------
DEV_BIN="./dev-bin"
BASE_REF=""
TARGET_REF=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dev-bin <dir>     Path to executables directory (default: ./dev-bin)
  --base <ref>        Base ref for analyzers (default: auto)
  --target <ref>      Target ref for analyzers (default: HEAD)
  --quiet             Only print summary
  --verbose           Print command outputs on failure and more details
  --keep-output       Also show command outputs on success
  --timeout <sec>     Per-test timeout in seconds (requires coreutils 'timeout')
  --no-color          Disable colored output
  -h, --help          Show this help
EOF
}

while (($#)); do
    case "$1" in
        --dev-bin) DEV_BIN="${2:-}"; shift 2;;
        --base) BASE_REF="${2:-}"; shift 2;;
        --target) TARGET_REF="${2:-}"; shift 2;;
        --quiet) QUIET=1; shift;;
        --verbose) VERBOSE=1; shift;;
        --keep-output) KEEP_OUTPUT=1; shift;;
        --timeout) TIMEOUT="${2:-}"; shift 2;;
        --no-color) USE_COLOR=0; shift;;
        -h|--help) usage; exit 0;;
        *) sayc red "Unknown option: $1"; usage; exit 2;;
    esac
done

# ---------------------- temp workspace ----------------------
TMPDIR="$(mktemp -d -t semver-tests.XXXXXX)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# ---------------------- helpers ----------------------
require_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
        die "Not in a git repository. Run this inside a repository."
}

resolve_ref() {
    # echo resolved SHA and return 0; return 1 if not resolvable
    local ref="$1" out
    out="$(git rev-parse --verify --quiet "$ref" 2>/dev/null)" || return 1
    printf '%s\n' "$out"
}

ensure_dev_bin() {
    [[ -d "$DEV_BIN" ]] || die "--dev-bin not found: $DEV_BIN"
}

maybe_warn_timeout() {
    if [[ -n "$TIMEOUT" && -z "$TIMEOUT_BIN" ]]; then
        sayc yel "Warning: --timeout requested but 'timeout' not found; ignoring timeouts."
        TIMEOUT=""
    fi
}

run_cmd_capture() {
    # args: command_string output_file
    local cmd="$1" outfile="$2" ec=0
    : >"$outfile"
    if [[ -n "$TIMEOUT" ]]; then
        # Use bash -lc to keep parsing consistent and avoid eval
        "$TIMEOUT_BIN" "$TIMEOUT" bash -lc "$cmd" >"$outfile" 2>&1 || ec=$?
    else
        bash -lc "$cmd" >"$outfile" 2>&1 || ec=$?
    fi
    printf '%s\n' "$ec"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TEST_IDX=0

# Test function with improved output handling
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit="$3"
    
    ((TEST_IDX++))
    local tag="$(printf 'T%03d' "$TEST_IDX")"
    local outfile="$TMPDIR/$tag.out"
    
    sayc blu "Running: $test_name"
    ((VERBOSE)) && say "Command: $command"
    
    local exit_code
    exit_code="$(run_cmd_capture "$command" "$outfile")"
    
    if [[ "$exit_code" -eq "$expected_exit" ]]; then
        sayc grn "✓ PASS"
        ((TESTS_PASSED++))
        if ((KEEP_OUTPUT)); then
            say "$(color dim "Output:")"
            sed 's/^/  /' "$outfile"
        fi
    else
        sayc red "✗ FAIL - Expected exit $expected_exit, got $exit_code"
        ((TESTS_FAILED++))
        if ((VERBOSE)) || [[ "$expected_exit" -eq 0 ]]; then
            say "$(color dim "Output:")"
            sed 's/^/  /' "$outfile"
        fi
    fi
    say ""
}

# ---------------------- init ----------------------
require_git_repo
ensure_dev_bin
maybe_warn_timeout

# Default refs
TARGET_REF="${TARGET_REF:-HEAD}"

if [[ -z "${BASE_REF:-}" ]]; then
    # Prefer parent of HEAD, but handle single-commit repos gracefully
    if resolve_ref "HEAD~1" >/dev/null; then
        BASE_REF="HEAD~1"
    else
        # Single commit: use HEAD for base (zero diff). Analyzers should handle this.
        BASE_REF="HEAD"
        sayc yel "Single-commit repository detected; using --base HEAD for smoke tests (no diffs)."
    fi
fi

LAST_COMMIT_SHA="$(resolve_ref "$TARGET_REF" || true)"
BASE_COMMIT_SHA="$(resolve_ref "$BASE_REF" || true)"
[[ -n "$LAST_COMMIT_SHA" ]] || die "Cannot resolve target ref: $TARGET_REF"
[[ -n "$BASE_COMMIT_SHA" ]] || die "Cannot resolve base ref: $BASE_REF"

sayc yel "Testing Modular Semantic Version Analyzer Components"
say "Base ref:    $BASE_REF ($BASE_COMMIT_SHA)"
say "Target ref:  $TARGET_REF ($LAST_COMMIT_SHA)"
say "Executables: $DEV_BIN"
say ""

# Test 1: Check if all required binaries exist
sayc blu "=== Binary Availability ==="
tools=(
    ref-resolver
    version-config-loader
    file-change-analyzer
    cli-options-analyzer
    security-keyword-analyzer
    version-calculator
    semantic-version-analyzer
)
for t in "${tools[@]}"; do
    run_test "$t exists" "test -x \"$DEV_BIN/$t\"" 0
done

# Test 2: Test help functionality
sayc blu "=== Help Output ==="
for t in "${tools[@]}"; do
    run_test "$t --help" "\"$DEV_BIN/$t\" --help" 0
done

# Test 3: Test configuration loading
sayc blu "=== Configuration Loading ==="
run_test "version-config-loader --validate-only" "\"$DEV_BIN/version-config-loader\" --validate-only" 0
run_test "version-config-loader --machine" "\"$DEV_BIN/version-config-loader\" --machine" 0

# Test 4: Test reference resolution
sayc blu "=== Reference Resolution ==="
run_test "ref-resolver --print-base" "\"$DEV_BIN/ref-resolver\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --print-base" 0
run_test "ref-resolver --machine" "\"$DEV_BIN/ref-resolver\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" 0

# Test 5: Test file change analysis
sayc blu "=== File Change Analysis ==="
run_test "file-change-analyzer basic" "\"$DEV_BIN/file-change-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" 0
run_test "file-change-analyzer machine" "\"$DEV_BIN/file-change-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" 0

# Test 6: Test CLI options analysis
sayc blu "=== CLI Options Analysis ==="
run_test "cli-options-analyzer basic" "\"$DEV_BIN/cli-options-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" 0
run_test "cli-options-analyzer machine" "\"$DEV_BIN/cli-options-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" 0

# Test 7: Test security keyword analysis
sayc blu "=== Security Keyword Analysis ==="
run_test "security-keyword-analyzer basic" "\"$DEV_BIN/security-keyword-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" 0
run_test "security-keyword-analyzer machine" "\"$DEV_BIN/security-keyword-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" 0

# Test 8: Test version calculation
sayc blu "=== Version Calculation ==="
run_test "version-calculator basic" "\"$DEV_BIN/version-calculator\" --current-version 1.2.3 --bump-type minor --loc 500" 0
run_test "version-calculator machine" "\"$DEV_BIN/version-calculator\" --current-version 1.2.3 --bump-type minor --loc 500 --machine" 0

# Test 9: Test orchestrator
sayc blu "=== Orchestrator ==="
run_test "semantic-version-analyzer basic" "\"$DEV_BIN/semantic-version-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" 0
run_test "semantic-version-analyzer --suggest-only" "\"$DEV_BIN/semantic-version-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --suggest-only" 0

# Test 10: Test error handling
sayc blu "=== Error Handling ==="
run_test "invalid base reference" "\"$DEV_BIN/ref-resolver\" --base INVALID_REF --target \"$TARGET_REF\"" 1
run_test "missing required argument" "\"$DEV_BIN/file-change-analyzer\"" 1
run_test "invalid bump type" "\"$DEV_BIN/version-calculator\" --current-version 1.2.3 --bump-type invalid" 1

# Summary
sayc yel "=== Test Summary ==="
say "Tests passed: $(color grn "$TESTS_PASSED")"
say "Tests failed: $(color red "$TESTS_FAILED")"
say "Total tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    sayc grn "All tests passed! Modular components look healthy."
    exit 0
else
    sayc red "Some tests failed. See outputs above for details."
    exit 1
fi 