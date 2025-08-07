#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test script for modular semantic version analyzer components

set -Euo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Keep Git fast and quiet inside tests
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=1

# ---------------------- appearance & output ----------------------
is_tty=0; [[ -t 1 ]] && is_tty=1
USE_COLOR=1
# Disable colors in non-interactive environments
((is_tty)) || USE_COLOR=0
QUIET=0
VERBOSE=0
KEEP_OUTPUT=0
STOP_ON_FAIL=0
ONLY_FILTER=""
TIMEOUT=""
TIMEOUT_BIN="$(command -v timeout || true)"

# Environment overrides for repository-dependent expectations
EXPECT_VERSION="${EXPECT_VERSION:-10.5.12}"

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
# shellcheck disable=SC2329,SC2317
say() { ((QUIET)) || printf '%s\n' "$*"; }
sayc() { ((QUIET)) || { color "$1" "$2"; printf '\n'; } }
die() { sayc red "Error: $*"; exit 1; }

# ---------------------- args ----------------------
# Get project root
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEV_BIN="$PROJECT_ROOT/dev-bin"
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
# shellcheck disable=SC2317,SC2329
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# ---------------------- counters & bookkeeping ----------------------
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
START_TS=$(date +%s)

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

run_test() {
    local name="$1" cmd="$2" expect="$3"
    
    # Check if test should be filtered
    if [[ -n "$ONLY_FILTER" && ! "$name" =~ $ONLY_FILTER ]]; then
        ((TESTS_SKIPPED++))
        return 0
    fi
    
    ((QUIET)) || printf 'Running: %s\n' "$name"
    
    # Execute command and capture output
    local output
    output="$(eval "$cmd" 2>&1)"
    
    # Check if output contains expected string (supports pipe-separated alternatives)
    local found=0
    if [[ "$expect" == *"|"* ]]; then
        # Multiple alternatives separated by |
        IFS='|' read -ra patterns <<< "$expect"
        for pattern in "${patterns[@]}"; do
            if echo "$output" | grep -q "$pattern"; then
                found=1
                break
            fi
        done
    else
        # Single pattern
        if echo "$output" | grep -q "$expect"; then
            found=1
        fi
    fi
    
    if ((found)); then
        ((TESTS_PASSED++))
        ((QUIET)) || printf '✓ PASS: %s\n' "$name"
        if ((VERBOSE)) || ((KEEP_OUTPUT)); then
            printf '  Output:\n'
            printf '  %s\n' "$output" | sed 's/^/    /'
        fi
    else
        ((TESTS_FAILED++))
        color red "✗ FAIL: $name"
        printf '  Expected: %s\n' "$expect"
        printf '  Got: %s\n' "$output"
        if ((VERBOSE)) || ((KEEP_OUTPUT)); then
            printf '  Full output:\n'
            printf '  %s\n' "$output" | sed 's/^/    /'
        fi
        if ((STOP_ON_FAIL)); then
            exit 1
        fi
    fi
}

# ---------------------- main ----------------------
main() {
    maybe_warn_timeout
    
    # preconditions
    require_git_repo
    ensure_dev_bin

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

    if [[ "${LIST_TESTS:-0}" -eq 1 ]]; then
        printf 'Available tests:\n'
        printf '  - Binary availability tests\n'
        printf '  - Help output tests\n'
        printf '  - Version calculation tests\n'
        printf '  - Mathematical version bump tests\n'
        printf '  - Tag manager tests\n'
        printf '  - Orchestrator tests\n'
        printf '  - Error handling tests\n'
        printf '  - Additional tools tests\n'
        exit 0
    fi

    printf 'Testing Modular Semantic Version Analyzer Components\n'
    printf 'Base ref:    %s (%s)\n' "$BASE_REF" "$BASE_COMMIT_SHA"
    printf 'Target ref:  %s (%s)\n' "$TARGET_REF" "$LAST_COMMIT_SHA"
    printf 'Executables: %s\n' "$DEV_BIN"
    printf '\n'

    # Binary availability tests
    run_test "ref-resolver exists" "test -x \"$DEV_BIN/ref-resolver.sh\"" ""
    run_test "version-config-loader exists" "test -x \"$DEV_BIN/version-config-loader.sh\"" ""
    run_test "file-change-analyzer exists" "test -x \"$DEV_BIN/file-change-analyzer.sh\"" ""
    run_test "cli-options-analyzer exists" "test -x \"$DEV_BIN/cli-options-analyzer.sh\"" ""
    run_test "security-keyword-analyzer exists" "test -x \"$DEV_BIN/security-keyword-analyzer.sh\"" ""
    run_test "version-calculator exists" "test -x \"$DEV_BIN/version-calculator.sh\"" ""
    run_test "semantic-version-analyzer exists" "test -x \"$DEV_BIN/semantic-version-analyzer.sh\"" ""
    run_test "mathematical-version-bump exists" "test -x \"$DEV_BIN/mathematical-version-bump.sh\"" ""
    run_test "tag-manager exists" "test -x \"$DEV_BIN/tag-manager.sh\"" ""
    run_test "version-utils exists" "test -x \"$DEV_BIN/version-utils.sh\"" ""
    run_test "version-validator exists" "test -x \"$DEV_BIN/version-validator.sh\"" ""
    run_test "version-calculator-loc exists" "test -x \"$DEV_BIN/version-calculator-loc.sh\"" ""
    run_test "git-operations exists" "test -x \"$DEV_BIN/git-operations.sh\"" ""

    # Help output tests
    run_test "ref-resolver --help" "\"$DEV_BIN/ref-resolver.sh\" --help" "Reference Resolver"
    run_test "version-config-loader --help" "\"$DEV_BIN/version-config-loader.sh\" --help" "Version Configuration Loader"
    run_test "file-change-analyzer --help" "\"$DEV_BIN/file-change-analyzer.sh\" --help" "File Change Analyzer"
    run_test "cli-options-analyzer --help" "\"$DEV_BIN/cli-options-analyzer.sh\" --help" "CLI Options Analyzer"
    run_test "security-keyword-analyzer --help" "\"$DEV_BIN/security-keyword-analyzer.sh\" --help" "Security Keyword Analyzer"
    run_test "version-calculator --help" "\"$DEV_BIN/version-calculator.sh\" --help" "Version Calculator"
    run_test "semantic-version-analyzer --help" "\"$DEV_BIN/semantic-version-analyzer.sh\" --help" "Semantic Version Analyzer v2"
    run_test "mathematical-version-bump --help" "\"$DEV_BIN/mathematical-version-bump.sh\" --help" "Mathematical Version Bumper for vglog-filter"
    run_test "tag-manager help" "\"$DEV_BIN/tag-manager.sh\"" "Tag Manager for vglog-filter"
    run_test "version-utils --help" "\"$DEV_BIN/version-utils.sh\" --help" "Usage: version-utils.sh"
    run_test "version-validator --help" "\"$DEV_BIN/version-validator.sh\" --help" "Usage: version-validator"
    run_test "version-calculator-loc --help" "\"$DEV_BIN/version-calculator-loc.sh\" --help" "Usage: version-calculator-loc"
    run_test "git-operations --help" "\"$DEV_BIN/git-operations.sh\" --help" "Usage: git-operations.sh"

    # Configuration loading tests
    run_test "version-config-loader --validate-only" "\"$DEV_BIN/version-config-loader.sh\" --validate-only" ""
    run_test "version-config-loader --machine" "\"$DEV_BIN/version-config-loader.sh\" --machine" ""

    # Reference resolution tests
    run_test "ref-resolver --print-base" "\"$DEV_BIN/ref-resolver.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --print-base" ""
    run_test "ref-resolver --machine" "\"$DEV_BIN/ref-resolver.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" ""

    # File change analysis tests
    run_test "file-change-analyzer basic" "\"$DEV_BIN/file-change-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" ""
    run_test "file-change-analyzer machine" "\"$DEV_BIN/file-change-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" ""

    # CLI options analysis tests
    run_test "cli-options-analyzer basic" "\"$DEV_BIN/cli-options-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" ""
    run_test "cli-options-analyzer machine" "\"$DEV_BIN/cli-options-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" ""

    # Security keyword analysis tests
    run_test "security-keyword-analyzer basic" "\"$DEV_BIN/security-keyword-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" ""
    run_test "security-keyword-analyzer machine" "\"$DEV_BIN/security-keyword-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --machine" ""

    # Version calculation tests
    run_test "version-calculator basic" "\"$DEV_BIN/version-calculator.sh\" --current-version 1.2.3 --bump-type minor --loc 500" "Next version:"
    run_test "version-calculator machine" "\"$DEV_BIN/version-calculator.sh\" --current-version 1.2.3 --bump-type minor --loc 500 --machine" "NEXT_VERSION="
    run_test "version-calculator-loc basic" "\"$DEV_BIN/version-calculator-loc.sh\" --current-version 1.2.3 --bump-type minor" "1.7.0"
    run_test "version-calculator-loc machine" "\"$DEV_BIN/version-calculator-loc.sh\" --current-version 1.2.3 --bump-type minor --machine" "NEW="

    # Mathematical version bump tests
    run_test "mathematical-version-bump print" "\"$DEV_BIN/mathematical-version-bump.sh\" --print --base \"$BASE_REF\" --target \"$TARGET_REF\"" "Mathematical analysis suggests:|No qualifying changes detected"
    run_test "mathematical-version-bump dry-run" "\"$DEV_BIN/mathematical-version-bump.sh\" --dry-run --base \"$BASE_REF\" --target \"$TARGET_REF\"" "Mathematical analysis suggests:|No qualifying changes detected"

    # Tag manager tests
    run_test "tag-manager list" "\"$DEV_BIN/tag-manager.sh\" list" ""

    # Orchestrator tests
    run_test "semantic-version-analyzer basic" "\"$DEV_BIN/semantic-version-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\"" ""
    run_test "semantic-version-analyzer --suggest-only" "\"$DEV_BIN/semantic-version-analyzer.sh\" --base \"$BASE_REF\" --target \"$TARGET_REF\" --suggest-only" ""

    # Error handling tests
    run_test "invalid base reference" "\"$DEV_BIN/ref-resolver.sh\" --base INVALID_REF --target \"$TARGET_REF\"" "" 1
    run_test "missing required argument" "\"$DEV_BIN/file-change-analyzer.sh\"" "" 1
    run_test "invalid bump type" "\"$DEV_BIN/version-calculator.sh\" --current-version 1.2.3 --bump-type invalid" "" 1

    # Additional tools tests (if they exist)
    if [[ -x "$DEV_BIN/version-utils.sh" ]]; then
        run_test "version-utils last-tag" "\"$DEV_BIN/version-utils.sh\" last-tag v" ""
        run_test "version-utils hash-file VERSION" "\"$DEV_BIN/version-utils.sh\" hash-file VERSION" ""
        run_test "version-utils read-version" "\"$DEV_BIN/version-utils.sh\" read-version VERSION" "$EXPECT_VERSION"
    fi

    if [[ -x "$DEV_BIN/version-validator.sh" ]]; then
        run_test "version-validator validate 1.0.0" "\"$DEV_BIN/version-validator.sh\" validate 1.0.0" "valid"
        run_test "version-validator compare 1.0.0 1.0.1" "\"$DEV_BIN/version-validator.sh\" compare 1.0.0 1.0.1" "^-1$"
        run_test "version-validator parse 1.2.3" "\"$DEV_BIN/version-validator.sh\" parse 1.2.3" "1"
        run_test "version-validator is-prerelease 1.0.0-rc.1" "\"$DEV_BIN/version-validator.sh\" is-prerelease 1.0.0-rc.1" "true"
    fi

    # Summary
    printf '\n'
    printf '=== Test Summary ===\n'
    printf 'Tests passed: %s\n' "$TESTS_PASSED"
    printf 'Tests failed: %s\n' "$TESTS_FAILED"
    printf 'Tests skipped: %s\n' "$TESTS_SKIPPED"
    printf 'Total tests: %s\n' "$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    local elapsed=$(( $(date +%s) - START_TS ))
    printf 'Elapsed: %ss\n' "$elapsed"

    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        printf 'All tests passed! Modular components look healthy.\n'
        exit 0
    else
        printf 'Some tests failed. See outputs above for details.\n'
        exit 1
    fi
}

main "$@" 