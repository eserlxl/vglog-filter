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
STOP_ON_FAIL=0
ONLY_FILTER=""
TIMEOUT=""
TIMEOUT_BIN="$(command -v timeout || true)"

# Environment overrides for repository-dependent expectations
EXPECT_VERSION="${EXPECT_VERSION:-10.5.12}"
EXPECT_CMAKE_DETECT="${EXPECT_CMAKE_DETECT:-variable}"

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
  --only <pattern>    Run tests whose names match pattern (grep -E)
  --list              List tests and exit
  --quiet             Only print summary
  --verbose           Print command outputs on failure and more details
  --keep-output       Also show command outputs on success
  --stop-on-fail      Stop at first failure
  --timeout <sec>     Per-test timeout in seconds (requires coreutils 'timeout')
  --no-color          Disable colored output
  -h, --help          Show this help

Env overrides:
  EXPECT_VERSION=<ver>          Expected "current" VERSION when asserted (default: $EXPECT_VERSION)
  EXPECT_CMAKE_DETECT=<value>   Expected cmake-updater detect result (default: $EXPECT_CMAKE_DETECT)
  NO_COLOR=true                 Disable colors
EOF
}

while (($#)); do
    case "$1" in
        --dev-bin) DEV_BIN="${2:-}"; shift 2;;
        --base) BASE_REF="${2:-}"; shift 2;;
        --target) TARGET_REF="${2:-}"; shift 2;;
        --only) ONLY_FILTER="${2:-}"; shift 2;;
        --list) LIST_TESTS=1; shift;;
        --quiet) QUIET=1; shift;;
        --verbose) VERBOSE=1; shift;;
        --keep-output) KEEP_OUTPUT=1; shift;;
        --stop-on-fail) STOP_ON_FAIL=1; shift;;
        --timeout) TIMEOUT="${2:-}"; shift 2;;
        --no-color) USE_COLOR=0; shift;;
        -h|--help) usage; exit 0;;
        *) sayc red "Unknown option: $1"; usage; exit 2;;
    esac
done

# ---------------------- temp workspace ----------------------
TMPDIR="$(mktemp -d -t semver-tests.XXXXXX)"
# shellcheck disable=SC2317
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# ---------------------- counters & bookkeeping ----------------------
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
START_TS=$(date +%s)

# Arrays to store tests
declare -a TEST_NAMES TEST_CMDS TEST_EXPECTS TEST_MODES TEST_EXITS

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
            ((QUIET)) || color yel "⚠ SKIP: $name (missing executable: $first_token)\n"
            return 0
        fi
    fi

    # ONLY filter
    if [[ -n "$ONLY_FILTER" && ! "$name" =~ $ONLY_FILTER ]]; then
        ((TESTS_SKIPPED++))
        ((QUIET)) || color yel "⚠ SKIP: $name (filtered)\n"
        return 0
    fi

    ((QUIET)) || color blu "Running: $name\n"

    local output="" status=0
    if [[ -n "$TIMEOUT" && -n "$TIMEOUT_BIN" ]]; then
        set +e
        output="$($TIMEOUT_BIN -s KILL "$TIMEOUT" bash -c "$cmd" 2>&1)"
        status=$?
        set -e
        if (( status == 137 )); then
            ((TESTS_FAILED++))
            color red "✗ FAIL: $name\n"
            printf '  Error: timed out after %ss\n' "$TIMEOUT"
            ((STOP_ON_FAIL)) && exit 1
            return 1
        fi
    else
        set +e
        output="$(bash -c "$cmd" 2>&1)"
        status=$?
        set -e
    fi

    ((VERBOSE)) && printf 'Command: %s\n' "$cmd"
    ((VERBOSE)) && printf 'Exit: %d\n' "$status"
    ((VERBOSE)) && printf 'Output:\n%s\n' "$output"

    if (( status != want_exit )); then
        ((TESTS_FAILED++))
        color red "✗ FAIL: $name\n"
        printf '  Error: expected exit %d, got %d\n' "$want_exit" "$status"
        if ((VERBOSE)) || [[ "$want_exit" -eq 0 ]]; then
            printf '  Output:\n'
            printf '  %s\n' "$output" | sed 's/^/    /'
        fi
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
    ((QUIET)) || color grn "✓ PASS: $name\n"
    if ((KEEP_OUTPUT)); then
        printf '  Output:\n'
        printf '  %s\n' "$output" | sed 's/^/    /'
    fi
    return 0
}

list_tests() {
    local i
    for ((i=0; i<${#TEST_NAMES[@]}; i++)); do
        printf '%2d) %s\n' "$((i+1))" "${TEST_NAMES[$i]}"
    done
}

# ---------------------- domain-specific helpers ----------------------
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

# ---------------------- define tests ----------------------
build_tests() {
    # preconditions
    require_git_repo
    ensure_dev_bin

    local cur_ver expect_next
    cur_ver="$(read_version_file)"
    expect_next="$(bump_patch "$cur_ver" || true)"
    # Fallback to provided expectation if bump failed
    [[ -n "$expect_next" ]] || expect_next="10.5.13"

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

    # Binary availability tests
    add_test "ref-resolver exists" "test -x \"$DEV_BIN/ref-resolver\"" "" "succeeds"
    add_test "version-config-loader exists" "test -x \"$DEV_BIN/version-config-loader\"" "" "succeeds"
    add_test "file-change-analyzer exists" "test -x \"$DEV_BIN/file-change-analyzer\"" "" "succeeds"
    add_test "cli-options-analyzer exists" "test -x \"$DEV_BIN/cli-options-analyzer\"" "" "succeeds"
    add_test "security-keyword-analyzer exists" "test -x \"$DEV_BIN/security-keyword-analyzer\"" "" "succeeds"
    add_test "version-calculator exists" "test -x \"$DEV_BIN/version-calculator\"" "" "succeeds"
    add_test "semantic-version-analyzer exists" "test -x \"$DEV_BIN/semantic-version-analyzer\"" "" "succeeds"

    # Help output tests
    add_test "ref-resolver --help" "\"$DEV_BIN/ref-resolver\" --help" "Usage:" "contains"
    add_test "version-config-loader --help" "\"$DEV_BIN/version-config-loader\" --help" "Usage:" "contains"
    add_test "file-change-analyzer --help" "\"$DEV_BIN/file-change-analyzer\" --help" "Usage:" "contains"
    add_test "cli-options-analyzer --help" "\"$DEV_BIN/cli-options-analyzer\" --help" "Usage:" "contains"
    add_test "security-keyword-analyzer --help" "\"$DEV_BIN/security-keyword-analyzer\" --help" "Usage:" "contains"
    add_test "version-calculator --help" "\"$DEV_BIN/version-calculator\" --help" "Usage:" "contains"
    add_test "semantic-version-analyzer --help" "\"$DEV_BIN/semantic-version-analyzer\" --help" "Usage:" "contains"

    # Configuration loading tests
    add_test "version-config-loader --validate-only" "\"$DEV_BIN/version-config-loader\" --validate-only" "" "succeeds"
    add_test "version-config-loader --machine" "\"$DEV_BIN/version-config-loader\" --machine" "" "succeeds"

    # Reference resolution tests
    add_test "ref-resolver --print-base" "\"$DEV_BIN/ref-resolver\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --print-base" "" "succeeds"
    add_test "ref-resolver --machine" "\"$DEV_BIN/ref-resolver\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" "" "succeeds"

    # File change analysis tests
    add_test "file-change-analyzer basic" "\"$DEV_BIN/file-change-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" "" "succeeds"
    add_test "file-change-analyzer machine" "\"$DEV_BIN/file-change-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" "" "succeeds"

    # CLI options analysis tests
    add_test "cli-options-analyzer basic" "\"$DEV_BIN/cli-options-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" "" "succeeds"
    add_test "cli-options-analyzer machine" "\"$DEV_BIN/cli-options-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" "" "succeeds"

    # Security keyword analysis tests
    add_test "security-keyword-analyzer basic" "\"$DEV_BIN/security-keyword-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" "" "succeeds"
    add_test "security-keyword-analyzer machine" "\"$DEV_BIN/security-keyword-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" "" "succeeds"

    # Version calculation tests
    add_test "version-calculator basic" "\"$DEV_BIN/version-calculator\" --current-version 1.2.3 --bump-type minor --loc 500" "" "succeeds"
    add_test "version-calculator machine" "\"$DEV_BIN/version-calculator\" --current-version 1.2.3 --bump-type minor --loc 500 --machine" "" "succeeds"

    # Orchestrator tests
    add_test "semantic-version-analyzer basic" "\"$DEV_BIN/semantic-version-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" "" "succeeds"
    add_test "semantic-version-analyzer --suggest-only" "\"$DEV_BIN/semantic-version-analyzer\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --suggest-only" "" "succeeds"

    # Error handling tests
    add_test "invalid base reference" "\"$DEV_BIN/ref-resolver\" --base INVALID_REF --target \"$TARGET_REF\"" "" "succeeds" 1
    add_test "missing required argument" "\"$DEV_BIN/file-change-analyzer\"" "" "succeeds" 1
    add_test "invalid bump type" "\"$DEV_BIN/version-calculator\" --current-version 1.2.3 --bump-type invalid" "" "succeeds" 1

    # Additional tools from o3 version (if they exist)
    if [[ -x "$DEV_BIN/version-utils" ]]; then
        add_test "version-utils last-tag" "\"$DEV_BIN/version-utils\" last-tag v" "" "succeeds"
        add_test "version-utils hash-file VERSION" "\"$DEV_BIN/version-utils\" hash-file VERSION" "" "succeeds"
        add_test "version-utils read-version" "\"$DEV_BIN/version-utils\" read-version VERSION" "$EXPECT_VERSION" "contains"
    fi

    if [[ -x "$DEV_BIN/version-validator" ]]; then
        add_test "version-validator validate 1.0.0" "\"$DEV_BIN/version-validator\" validate 1.0.0" "valid" "contains"
        add_test "version-validator compare 1.0.0 1.0.1" "\"$DEV_BIN/version-validator\" compare 1.0.0 1.0.1" "-1" "contains"
        add_test "version-validator parse 1.2.3" "\"$DEV_BIN/version-validator\" parse 1.2.3" "1" "contains"
        add_test "version-validator is-prerelease 1.0.0-rc.1" "\"$DEV_BIN/version-validator\" is-prerelease 1.0.0-rc.1" "true" "contains"
    fi

    if [[ -x "$DEV_BIN/version-calculator-loc" ]]; then
        add_test "version-calculator-loc patch bump" "\"$DEV_BIN/version-calculator-loc\" --current-version 1.0.0 --bump-type patch" "1.0.1" "contains"
        add_test "version-calculator-loc help" "\"$DEV_BIN/version-calculator-loc\" --help" "Usage:" "contains"
    fi

    if [[ -x "$DEV_BIN/cmake-updater" ]]; then
        add_test "cmake-updater detect CMakeLists.txt" "\"$DEV_BIN/cmake-updater\" detect CMakeLists.txt" "$EXPECT_CMAKE_DETECT" "contains"
        add_test "cmake-updater help" "\"$DEV_BIN/cmake-updater\"" "Usage:" "contains"
    fi

    if [[ -x "$DEV_BIN/git-operations" ]]; then
        add_test "git-operations help" "\"$DEV_BIN/git-operations\"" "Usage:" "contains"
    fi

    if [[ -x "$DEV_BIN/cli-parser" ]]; then
        add_test "cli-parser help" "\"$DEV_BIN/cli-parser\" help" "Usage:" "contains"
        add_test "cli-parser validate patch --commit" "\"$DEV_BIN/cli-parser\" validate patch --commit" "valid" "contains"
    fi

    if [[ -x "$DEV_BIN/bump-version" ]]; then
        add_test "bump-version help" "\"$DEV_BIN/bump-version\" --help" "Usage:" "contains"
        add_test "bump-version dry-run" "\"$DEV_BIN/bump-version\" patch --dry-run" "$expect_next" "contains"
    fi
}

# ---------------------- main ----------------------
main() {
    maybe_warn_timeout
    build_tests

    if [[ "${LIST_TESTS:-0}" -eq 1 ]]; then
        list_tests
        exit 0
    fi

    sayc yel "Testing Modular Semantic Version Analyzer Components"
    say "Base ref:    $BASE_REF ($BASE_COMMIT_SHA)"
    say "Target ref:  $TARGET_REF ($LAST_COMMIT_SHA)"
    say "Executables: $DEV_BIN"
    say ""

    local i
    for ((i=0; i<${#TEST_NAMES[@]}; i++)); do
        run_one "$i"
    done

    # Summary
    printf '\n'
    sayc yel "=== Test Summary ==="
    say "Tests passed: $(color grn "$TESTS_PASSED")"
    say "Tests failed: $(color red "$TESTS_FAILED")"
    say "Tests skipped: $(color yel "$TESTS_SKIPPED")"
    say "Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    local elapsed=$(( $(date +%s) - START_TS ))
    printf 'Elapsed: %ss\n' "$elapsed"

    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        sayc grn "All tests passed! Modular components look healthy."
        exit 0
    else
        sayc red "Some tests failed. See outputs above for details."
        exit 1
    fi
}

main "$@" 