#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Core version bump orchestrator for vglog-filter
# Modular version of the original bump-version script

set -euo pipefail
shopt -s lastpipe
IFS=$'\n\t'
export LC_ALL=C

# ------------------------------ bootstrap ------------------------------------

readonly PROG=${0##*/}

# realpath is required before SCRIPT_DIR is known; fall back to python if needed
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
_need_exec "$SCRIPT_DIR/cli-parser.sh"         "cli-parser"
_need_exec "$SCRIPT_DIR/version-calculator-loc.sh" "version-calculator-loc"
_need_exec "$SCRIPT_DIR/git-operations.sh"     "git-operations"
_need_exec "$SCRIPT_DIR/version-validator.sh"  "version-validator"

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
    
    # Check external commands we rely on; version-utils should implement require_cmd
    # Keep the list minimal & explicit for this orchestrator.
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

# -------------------------- version calculation ------------------------------

calculate_new_version() {
    local current_version="$1"
    local bump_type="${BUMP_TYPE:-}"
    local set_version="${SET_VERSION:-}"
    
    if [[ -n "$set_version" ]]; then
        validate_version_format "$set_version" "${ALLOW_PRERELEASE:-false}"
        printf '%s' "$set_version"
        return 0
    fi
    
    [[ -n "$bump_type" ]] || die "No bump type specified (expected one of: major|minor|patch)."
    
    printf '%s\n' "${CYAN}Bumping version from $current_version...${RESET}" >&2
    
    local -a calculator_args=(
        --current-version "$current_version"
        --bump-type "$bump_type"
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
    
    # Simulate CMake update once (detect format only once)
    
    # Simulate git operations
    if [[ "${DO_COMMIT:-false}" == "true" ]]; then
        printf '%s\n' "${YELLOW}DRY RUN: Would create commit: chore(release): ${TAG_PREFIX:-v}${new_version}${RESET}" >&2
        local -a effective_files=()
        [[ "$new_version" != *-* ]] && effective_files+=("VERSION")
        # CMakeLists.txt auto-updates from VERSION file, so no need to track it separately
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
    local bump_type="${BUMP_TYPE:-}"
    
    if [[ -n "$set_version" ]]; then
        validate_version_format "$set_version" "${ALLOW_PRERELEASE:-false}"
        printf '%s\n' "$set_version"
        exit 0
    elif [[ -n "$bump_type" && -f "$VERSION_FILE" ]]; then
        local current_version
        current_version="$(read_version_file "$VERSION_FILE")"
        if is_semver "$current_version"; then
            local -a calculator_args=(
                --current-version "$current_version"
                --bump-type "$bump_type"
                --original-project-root "$ORIGINAL_PROJECT_ROOT"
            )
            if [[ -n "${REPO_ROOT:-}" ]]; then
                calculator_args+=(--repo-root "${REPO_ROOT}")
            fi
            "$SCRIPT_DIR/version-calculator-loc.sh" "${calculator_args[@]}"
            exit 0
        fi
    fi
    
    die "Cannot compute version for --print. Provide --set VERSION or a bump type with an existing VERSION file."
}

# ---------------------------------- main -------------------------------------

main() {
    # Fast help path
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        "$SCRIPT_DIR/cli-parser.sh" help
        exit 0
    fi
    
    # Parse CLI -> exports variables used below
    # We eval only the output of our trusted parser to set env vars/flags.
    eval "$("$SCRIPT_DIR/cli-parser.sh" parse "$@")"
    
    setup_environment
    
    # Print-only early exit
    if [[ "${PRINT_ONLY:-false}" == "true" ]]; then
        handle_print_only
    fi
    
    # VERSION file handling
    local version_info version_exists current_version
    version_info="$(handle_version_file)"
    version_exists="${version_info%$'\n'*}"
    current_version="${version_info#*$'\n'}"
    
    # Compute new version
    local new_version
    new_version="$(calculate_new_version "$current_version")"
    
    # No-op guard
    if [[ "$current_version" == "$new_version" ]]; then
        printf '%s\n' "${YELLOW}Version unchanged ($current_version); nothing to do.${RESET}" >&2
        printf '%s\n' "$new_version"
        exit 0
    fi
    
    # Dry-run path
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        simulate_dry_run "$new_version" "$current_version" "$version_exists"
        exit 0
    fi
    
    # Apply updates
    update_files "$new_version" "$current_version"
    
    # Git actions
    perform_git_operations "$new_version" "$current_version"
    
    # Sanity warning for --set without tagging (helps ordering in release flows)
    if [[ -n "${SET_VERSION:-}" && "${DO_TAG:-false}" != "true" && "$new_version" != *-* ]]; then
        local last_tag last_version
        last_tag="$("$SCRIPT_DIR/version-utils.sh" last-tag "${TAG_PREFIX:-v}" || true)"
        if [[ -n "$last_tag" ]]; then
            last_version="${last_tag:${#TAG_PREFIX:-v}}"
            if is_semver "$last_version"; then
                if ! "$SCRIPT_DIR/version-validator.sh" is_version_greater "$new_version" "$last_version"; then
                    warn "--set version $new_version is not greater than last tag $last_tag"
                fi
            fi
        fi
    fi
    
    # Success & next steps
    if [[ "$current_version" == "none" ]]; then
        success "Version bump completed: created $new_version"
    else
        success "Version bump completed: $current_version → $new_version"
    fi
    
    if [[ "${DO_TAG:-false}" == "true" ]]; then
        printf '%s\n' "${YELLOW}Next steps:${RESET}" >&2
        local current_branch
        current_branch="$(git rev-parse --abbrev-ref HEAD)"
        printf '%s\n' "  git push ${REMOTE:-origin} ${current_branch}" >&2
        printf '%s\n' "  git push ${REMOTE:-origin} ${TAG_PREFIX:-v}${new_version}" >&2
    fi
    
    # Stdout only: computed version (for pipelines)
    printf '%s\n' "$new_version"
}

# --------------------------------- entry -------------------------------------

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 