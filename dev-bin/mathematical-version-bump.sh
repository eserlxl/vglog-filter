#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Mathematical Version Bumper for vglog-filter
# Purely mathematical versioning system - no manual bump types needed

set -euo pipefail
shopt -s lastpipe
IFS=$'\n\t'
export LC_ALL=C

# ------------------------------ bootstrap ------------------------------------

readonly PROG=${0##*/}

# realpath is required before SCRIPT_DIR is known
if ! command -v realpath >/dev/null 2>&1; then
  echo "[$PROG] Error: realpath not found." >&2
  exit 127
fi

SCRIPT_DIR="$(dirname -- "$(realpath -- "$0")")"

# Helper to die consistently (before version-utils is sourced)
_die_boot() { printf '[%s] %s\n' "$PROG" "$*" >&2; exit 1; }

# Require Bash ≥ 4 (associative arrays & modern features used in utilities)
if (( BASH_VERSINFO[0] < 4 )); then
  _die_boot "Bash ≥ 4 is required; current: ${BASH_VERSION}"
fi

# Validate helper scripts exist early (fail fast & clear)
_need_exec() {
  local p="$1" name="${2:-$1}"
  [[ -x "$p" ]] || _die_boot "Required helper '$name' not executable at: $p"
}

# version-utils is a sourced library (must exist and be readable)
[[ -r "$SCRIPT_DIR/version-utils.sh" ]] || _die_boot "Missing: $SCRIPT_DIR/version-utils.sh"
# Other helpers are called as executables
_need_exec "$SCRIPT_DIR/semantic-version-analyzer.sh" "semantic-version-analyzer"
_need_exec "$SCRIPT_DIR/version-calculator-loc.sh" "version-calculator-loc"
_need_exec "$SCRIPT_DIR/git-operations.sh" "git-operations"
_need_exec "$SCRIPT_DIR/version-validator.sh" "version-validator"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
source "$SCRIPT_DIR/version-utils.sh"

# ------------------------------ traps/cleanup --------------------------------

# Ensure cleanup hook exists even if utilities change later
setup_cleanup "TMP_FILE"

# shellcheck disable=SC2154
trap '{
  st=$?
  if (( st != 0 )); then
    warn "Aborted with status $st at line ${BASH_LINENO[0]} executing: ${BASH_COMMAND}"
  fi
  # cleanup function is provided by version-utils via setup_cleanup
}' EXIT

# ------------------------------ environment ----------------------------------

setup_environment() {
    # Initialize colors (NO_COLOR=true disables)
    init_colors "${NO_COLOR:-false}"
    
    # Resolve and export common paths (provided by version-utils)
    resolve_script_paths "$0" "${REPO_ROOT:-}"
    
    # Keep the *original* root for analyzers that need unmodified context
    ORIGINAL_PROJECT_ROOT="$PROJECT_ROOT"
    
    # Check external commands we rely on
    require_cmd git grep sed awk tr realpath
}

# --------------------------- version file ops --------------------------------

handle_version_file() {
    local version_exists="false"
    local current_version="none"
    
    if [[ -f "$VERSION_FILE" ]]; then
        version_exists="true"
        validate_version_file_path "$VERSION_FILE" "$PROJECT_ROOT"
        current_version="$(read_version_file "$VERSION_FILE")"
        
        if ! is_semver "$current_version"; then
            die "Invalid format in VERSION ($VERSION_FILE): '$current_version'"
            printf '%s\n' "${YELLOW}Expected: MAJOR.MINOR.PATCH (optionally with prerelease/build when allowed)${RESET}" >&2
            exit 1
        fi
    elif [[ -n "${SET_VERSION:-}" ]]; then
        printf '%s\n' "${YELLOW}Note: VERSION not found; will create with ${SET_VERSION}${RESET}" >&2
    else
        die "VERSION file not found at: $VERSION_FILE"
        printf '%s\n' "${YELLOW}Provide --set VERSION to create it, or add a VERSION file${RESET}" >&2
        exit 1
    fi
    
    # Two-line output for simple capture
    printf '%s\n%s' "$version_exists" "$current_version"
}

# -------------------------- mathematical version calculation ------------------

calculate_mathematical_version() {
    local current_version="$1"
    local set_version="${SET_VERSION:-}"
    
    if [[ -n "$set_version" ]]; then
        validate_version_format "$set_version" "${ALLOW_PRERELEASE:-false}"
        printf '%s' "$set_version"
        return 0
    fi
    
    printf '%s\n' "${CYAN}Analyzing changes to determine mathematical version bump...${RESET}" >&2
    
    # Use semantic analyzer to determine the appropriate bump type
    local analyzer_args=(
        --suggest-only
        --strict-status
    )
    
    if [[ -n "${REPO_ROOT:-}" ]]; then
        analyzer_args+=(--repo-root "${REPO_ROOT}")
    fi
    
    if [[ -n "${SINCE_TAG:-}" ]]; then
        analyzer_args+=(--since "${SINCE_TAG}")
    fi
    
    if [[ -n "${SINCE_COMMIT:-}" ]]; then
        analyzer_args+=(--since-commit "${SINCE_COMMIT}")
    fi
    
    if [[ -n "${SINCE_DATE:-}" ]]; then
        analyzer_args+=(--since-date "${SINCE_DATE}")
    fi
    
    if [[ -n "${BASE_REF:-}" ]]; then
        analyzer_args+=(--base "${BASE_REF}")
    fi
    
    if [[ -n "${TARGET_REF:-}" ]]; then
        analyzer_args+=(--target "${TARGET_REF}")
    fi
    
    if [[ "${NO_MERGE_BASE:-false}" == "true" ]]; then
        analyzer_args+=(--no-merge-base)
    fi
    
    if [[ -n "${ONLY_PATHS:-}" ]]; then
        analyzer_args+=(--only-paths "${ONLY_PATHS}")
    fi
    
    if [[ "${IGNORE_WHITESPACE:-false}" == "true" ]]; then
        analyzer_args+=(--ignore-whitespace)
    fi
    
    # Run semantic analyzer to get suggested bump type
    local suggested_bump
    suggested_bump="$("$SCRIPT_DIR/semantic-version-analyzer.sh" "${analyzer_args[@]}" 2>/dev/null || true)"
    
    if [[ -z "$suggested_bump" || "$suggested_bump" == "none" ]]; then
        printf '%s\n' "${YELLOW}No changes detected; version unchanged.${RESET}" >&2
        printf '%s' "$current_version"
        return 0
    fi
    
    printf '%s\n' "${CYAN}Mathematical analysis suggests: $suggested_bump bump${RESET}" >&2
    
    # Use version calculator to apply the mathematical bump
    local -a calculator_args=(
        --current-version "$current_version"
        --bump-type "$suggested_bump"
        --original-project-root "$ORIGINAL_PROJECT_ROOT"
    )
    if [[ -n "${REPO_ROOT:-}" ]]; then
        calculator_args+=(--repo-root "${REPO_ROOT}")
    fi
    
    local new_version
    new_version="$("$SCRIPT_DIR/version-calculator-loc.sh" "${calculator_args[@]}")"
    printf '%s' "$new_version"
}

# ------------------------------ file updates ---------------------------------

update_files() {
    local new_version="$1"
    local current_version="$2"
    
    # Guard: do not persist prereleases into VERSION
    if [[ "$new_version" != *-* ]]; then
        safe_write_file "$VERSION_FILE" "$new_version"
        if [[ "$current_version" == "none" ]]; then
            success "Created VERSION: $new_version"
        else
            success "Updated VERSION: $current_version → $new_version"
        fi
    else
        warn "Pre-release $new_version — skipping write to VERSION"
        printf '%s\n' "${CYAN}Note: Pre-release identifiers are not stored in VERSION.${RESET}" >&2
    fi
    
    # CMakeLists.txt auto-updates from VERSION file (no manual update needed)
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        printf '%s\n' "${YELLOW}DRY RUN: CMakeLists.txt will auto-update from VERSION file${RESET}" >&2
    fi
}

# ------------------------------ git ops --------------------------------------

perform_git_operations() {
    local new_version="$1"
    local current_version="$2"
    
    if [[ "${DO_COMMIT:-false}" == "true" || "${DO_TAG:-false}" == "true" || \
          "${DO_PUSH:-false}"   == "true" || "${PUSH_TAGS:-false}" == "true" ]]; then
        
        "$SCRIPT_DIR/git-operations.sh" perform_git_operations \
            "$VERSION_FILE" \
            "false" \
            "$new_version" \
            "$current_version" \
            "${DO_COMMIT:-false}" \
            "${DO_TAG:-false}" \
            "${DO_PUSH:-false}" \
            "${PUSH_TAGS:-false}" \
            "${COMMIT_MSG:-}" \
            "${NO_VERIFY:-false}" \
            "${COMMIT_SIGN:-false}" \
            "${TAG_PREFIX:-v}" \
            "${ANNOTATED_TAG:-true}" \
            "${SIGNED_TAG:-false}" \
            "${ALLOW_DIRTY:-false}" \
            "$PROJECT_ROOT" \
            "$ORIGINAL_PROJECT_ROOT" \
            "${REMOTE:-origin}" \
            "${ALLOW_NONMONOTONIC_TAG:-false}"
    fi
}

# ------------------------------ dry run --------------------------------------

simulate_dry_run() {
    local new_version="$1"
    local current_version="$2"
    local version_exists="$3"
    
    if [[ "$current_version" == "none" ]]; then
        if [[ "$new_version" == *-* ]]; then
            printf '%s\n' "${YELLOW}DRY RUN: Would print pre-release $new_version (no VERSION write)${RESET}" >&2
        else
            printf '%s\n' "${YELLOW}DRY RUN: Would create VERSION with $new_version${RESET}" >&2
        fi
    else
        if [[ "$new_version" == *-* ]]; then
            printf '%s\n' "${YELLOW}DRY RUN: Would print pre-release $new_version (no VERSION update)${RESET}" >&2
        else
            printf '%s\n' "${YELLOW}DRY RUN: Would update VERSION to $new_version${RESET}" >&2
        fi
    fi
    
    # Simulate git operations
    if [[ "${DO_COMMIT:-false}" == "true" ]]; then
        printf '%s\n' "${YELLOW}DRY RUN: Would create commit: chore(release): ${TAG_PREFIX:-v}${new_version}${RESET}" >&2
        local -a effective_files=()
        [[ "$new_version" != *-* ]] && effective_files+=("VERSION")
        if ((${#effective_files[@]} > 0)); then
            printf '%s\n' "${YELLOW}DRY RUN: Would commit files: ${effective_files[*]}${RESET}" >&2
        else
            printf '%s\n' "${YELLOW}DRY RUN: Would skip commit (no file changes)${RESET}" >&2
        fi
    fi
    
    if [[ "${DO_TAG:-false}" == "true" ]]; then
        if [[ "$new_version" == *-* ]]; then
            printf '%s\n' "${YELLOW}DRY RUN: Would block tag creation for pre-release $new_version${RESET}" >&2
        else
            printf '%s\n' "${YELLOW}DRY RUN: Would create tag: ${TAG_PREFIX:-v}${new_version}${RESET}" >&2
        fi
        local last_tag
        last_tag="$("$SCRIPT_DIR/version-utils.sh" last-tag "${TAG_PREFIX:-v}" || true)"
        [[ -n "$last_tag" ]] && printf '%s\n' "${YELLOW}DRY RUN: Last tag for comparison: $last_tag${RESET}" >&2
    fi
    
    # Always print computed version to stdout for pipelines
    printf '%s\n' "$new_version"
}

# ----------------------------- print-only mode -------------------------------

handle_print_only() {
    local set_version="${SET_VERSION:-}"
    
    if [[ -n "$set_version" ]]; then
        validate_version_format "$set_version" "${ALLOW_PRERELEASE:-false}"
        printf '%s\n' "$set_version"
        exit 0
    elif [[ -f "$VERSION_FILE" ]]; then
        local current_version
        current_version="$(read_version_file "$VERSION_FILE")"
        if is_semver "$current_version"; then
            calculate_mathematical_version "$current_version"
            exit 0
        fi
    fi
    
    die "Cannot compute version for --print. Provide --set VERSION or ensure VERSION file exists and is valid."
}

# ------------------------------ help -----------------------------------------

show_help() {
    cat << 'EOF'
Mathematical Version Bumper for vglog-filter

Usage: ./dev-bin/mathematical-version-bump.sh [options]

Purely mathematical versioning system - no manual bump types needed.
The system automatically determines the appropriate version bump based on
semantic analysis of changes.

Options:
  --set VERSION              Set version directly (X.Y.Z format)
  --commit                   Create a commit with version changes
  --tag                      Create a git tag for the new version
  --push                     Push commits to remote
  --push-tags                Push tags to remote
  --message MSG              Custom commit message
  --allow-dirty              Allow version bump on dirty working tree
  --lightweight-tag          Create lightweight tag instead of annotated
  --signed-tag               Create signed tag
  --no-verify                Skip git hooks
  --sign-commit              Sign the commit
  --tag-prefix PREFIX        Tag prefix (default: v)
  --no-color                 Disable colored output
  --print                    Print computed version and exit
  --dry-run                  Show what would be done without doing it
  --allow-prerelease         Allow prerelease versions with --set
  --repo-root PATH           Repository root directory
  --remote REMOTE            Remote name (default: origin)
  --allow-nonmonotonic-tag   Allow tags that are not monotonically increasing

Analysis Options (passed to semantic analyzer):
  --since TAG                Analyze changes since specific tag
  --since-commit HASH        Analyze changes since specific commit
  --since-date DATE          Analyze changes since specific date (YYYY-MM-DD)
  --base REF                 Set base reference for comparison
  --target REF               Set target reference for comparison
  --no-merge-base            Disable automatic merge-base detection
  --only-paths GLOBS         Restrict analysis to comma-separated path globs
  --ignore-whitespace        Ignore whitespace changes in diff analysis

Examples:
  ./dev-bin/mathematical-version-bump.sh --dry-run
  ./dev-bin/mathematical-version-bump.sh --commit --tag
  ./dev-bin/mathematical-version-bump.sh --set 1.0.0 --allow-prerelease
  ./dev-bin/mathematical-version-bump.sh --since v1.0.0 --commit
  ./dev-bin/mathematical-version-bump.sh --print

The system automatically:
1. Analyzes changes using semantic version analyzer
2. Determines appropriate bump type (major/minor/patch)
3. Calculates new version using mathematical rollover logic
4. Updates VERSION file and optionally creates git operations
EOF
}

# ---------------------------------- main -------------------------------------

main() {
    # Fast help path
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Parse CLI arguments manually (simplified for mathematical system)
    local SET_VERSION="" DO_COMMIT="false" DO_TAG="false" DO_PUSH="false" PUSH_TAGS="false"
    local COMMIT_MSG="" NO_VERIFY="false" COMMIT_SIGN="false" TAG_PREFIX="v"
    local ANNOTATED_TAG="true" SIGNED_TAG="false" ALLOW_DIRTY="false" REMOTE="origin"
    local ALLOW_NONMONOTONIC_TAG="false" PRINT_ONLY="false" DRY_RUN="false"
    local ALLOW_PRERELEASE="false" REPO_ROOT="" NO_COLOR="false"
    
    # Analysis options
    local SINCE_TAG="" SINCE_COMMIT="" SINCE_DATE="" BASE_REF="" TARGET_REF=""
    local NO_MERGE_BASE="false" ONLY_PATHS="" IGNORE_WHITESPACE="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --set)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--set requires a value"
                SET_VERSION="$2"; shift 2 ;;
            --commit) DO_COMMIT="true"; shift ;;
            --tag) DO_TAG="true"; shift ;;
            --push) DO_PUSH="true"; shift ;;
            --push-tags) PUSH_TAGS="true"; shift ;;
            --message)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--message requires a value"
                COMMIT_MSG="$2"; shift 2 ;;
            --allow-dirty) ALLOW_DIRTY="true"; shift ;;
            --lightweight-tag) ANNOTATED_TAG="false"; shift ;;
            --signed-tag) SIGNED_TAG="true"; shift ;;
            --no-verify) NO_VERIFY="true"; shift ;;
            --sign-commit) COMMIT_SIGN="true"; shift ;;
            --tag-prefix)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--tag-prefix requires a value"
                TAG_PREFIX="$2"; shift 2 ;;
            --no-color) NO_COLOR="true"; shift ;;
            --print) PRINT_ONLY="true"; shift ;;
            --dry-run) DRY_RUN="true"; shift ;;
            --allow-prerelease) ALLOW_PRERELEASE="true"; shift ;;
            --repo-root)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--repo-root requires a value"
                REPO_ROOT="$2"; shift 2 ;;
            --remote)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--remote requires a value"
                REMOTE="$2"; shift 2 ;;
            --allow-nonmonotonic-tag) ALLOW_NONMONOTONIC_TAG="true"; shift ;;
            
            # Analysis options
            --since)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--since requires a value"
                SINCE_TAG="$2"; shift 2 ;;
            --since-commit)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--since-commit requires a value"
                SINCE_COMMIT="$2"; shift 2 ;;
            --since-date)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--since-date requires a value"
                SINCE_DATE="$2"; shift 2 ;;
            --base)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--base requires a value"
                BASE_REF="$2"; shift 2 ;;
            --target)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--target requires a value"
                TARGET_REF="$2"; shift 2 ;;
            --no-merge-base) NO_MERGE_BASE="true"; shift ;;
            --only-paths)
                [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--only-paths requires a value"
                ONLY_PATHS="$2"; shift 2 ;;
            --ignore-whitespace) IGNORE_WHITESPACE="true"; shift ;;
            
            *) die "Unknown option: $1" ;;
        esac
    done
    
    setup_environment
    
    # Print-only early exit
    if [[ "$PRINT_ONLY" == "true" ]]; then
        handle_print_only
    fi
    
    # VERSION file handling
    local version_info version_exists current_version
    version_info="$(handle_version_file)"
    version_exists="${version_info%$'\n'*}"
    current_version="${version_info#*$'\n'}"
    
    # Compute new version using mathematical analysis
    local new_version
    new_version="$(calculate_mathematical_version "$current_version")"
    
    # No-op guard
    if [[ "$current_version" == "$new_version" ]]; then
        printf '%s\n' "${YELLOW}Version unchanged ($current_version); nothing to do.${RESET}" >&2
        printf '%s\n' "$new_version"
        exit 0
    fi
    
    # Dry-run path
    if [[ "$DRY_RUN" == "true" ]]; then
        simulate_dry_run "$new_version" "$current_version" "$version_exists"
        exit 0
    fi
    
    # Apply updates
    update_files "$new_version" "$current_version"
    
    # Git actions
    perform_git_operations "$new_version" "$current_version"
    
    # Success & next steps
    if [[ "$current_version" == "none" ]]; then
        success "Mathematical version bump completed: created $new_version"
    else
        success "Mathematical version bump completed: $current_version → $new_version"
    fi
    
    if [[ "$DO_TAG" == "true" ]]; then
        printf '%s\n' "${YELLOW}Next steps:${RESET}" >&2
        local current_branch
        current_branch="$(git rev-parse --abbrev-ref HEAD)"
        printf '%s\n' "  git push ${REMOTE} ${current_branch}" >&2
        printf '%s\n' "  git push ${REMOTE} ${TAG_PREFIX}${new_version}" >&2
    fi
    
    # Stdout only: computed version (for pipelines)
    printf '%s\n' "$new_version"
}

# --------------------------------- entry -------------------------------------

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
