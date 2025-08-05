#!/usr/bin/env bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Reference Resolver
# Resolves git references and determines base references for comparison

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Prevent any pager and avoid unnecessary repo locks for better performance.
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=0

show_help() {
    cat << 'EOF'
Reference Resolver

Usage: reference-resolver [options]

Options:
  --since <tag>            Analyze changes since specific tag (default: last tag)
  --since-tag <tag>        Alias for --since
  --since-commit <hash>    Analyze changes since specific commit
  --since-date <date>      Analyze changes since specific date (YYYY-MM-DD)
  --base <ref>             Set base reference for comparison (default: auto-detected)
  --target <ref>           Set target reference for comparison (default: HEAD)
  --repo-root <path>       Set repository root directory
  --no-merge-base          Disable automatic merge-base adjustment for disjoint branches
  --print-base             Output the chosen base reference SHA only
  --machine                Output machine-readable key=value format
  --json                   Output machine-readable JSON
  --help, -h               Show this help

Examples:
  reference-resolver --since v1.1.0
  reference-resolver --since-date 2025-01-01
  reference-resolver --base HEAD~5 --target HEAD
  reference-resolver --base v1.0.0 --target v1.1.0 --print-base
EOF
}

# --- args ---
SINCE_TAG=""
SINCE_COMMIT=""
SINCE_DATE=""
BASE_REF=""
TARGET_REF="HEAD"
REPO_ROOT=""
NO_MERGE_BASE=false
PRINT_BASE=false
MACHINE_OUTPUT=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --since|--since-tag)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --since requires a value\n' >&2; exit 1; }
            SINCE_TAG=$2; shift 2;;
        --since-commit)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --since-commit requires a value\n' >&2; exit 1; }
            SINCE_COMMIT=$2; shift 2;;
        --since-date)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --since-date requires a value\n' >&2; exit 1; }
            # Validate date format (YYYY-MM-DD)
            [[ "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { printf 'Error: --since-date requires YYYY-MM-DD format\n' >&2; exit 1; }
            IFS='-' read -r _ m d <<< "$2"
            ((m>=1 && m<=12)) || { printf 'Error: Invalid month in date %s (01-12)\n' "$2" >&2; exit 1; }
            ((d>=1 && d<=31)) ||  { printf 'Error: Invalid day in date %s (01-31)\n' "$2" >&2; exit 1; }
            SINCE_DATE=$2; shift 2;;
        --base)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --base requires a value\n' >&2; exit 1; }
            BASE_REF=$2; shift 2;;
        --target)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --target requires a value\n' >&2; exit 1; }
            TARGET_REF=$2; shift 2;;
        --repo-root)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --repo-root requires a value\n' >&2; exit 1; }
            REPO_ROOT=$2; shift 2;;
        --no-merge-base) NO_MERGE_BASE=true; shift;;
        --print-base) PRINT_BASE=true; shift;;
        --machine) MACHINE_OUTPUT=true; shift;;
        --json) JSON_OUTPUT=true; shift;;
        --help|-h) show_help; exit 0;;
        *) printf 'Error: Unknown option: %s\n' "$1" >&2; show_help; exit 1;;
    esac
done

# Check git command
if ! command -v git >/dev/null 2>&1; then
    printf 'Error: git command not found\n' >&2
    exit 1
fi

# Change to repo root if specified
if [[ -n "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        printf 'Error: Not in a git repository at %s\n' "$REPO_ROOT" >&2
        exit 1
    }
fi

# Validate git reference
verify_ref() {
    local ref="$1"
    if ! git -c color.ui=false rev-parse -q --verify "$ref^{commit}" >/dev/null; then
        printf 'Error: Invalid reference: %s\n' "$ref" >&2
        exit 1
    fi
}

# Determine the base for comparison with better error handling
get_base_reference() {
    # Handle explicit base/target references
    if [[ -n "$BASE_REF" ]]; then
        verify_ref "$BASE_REF"; printf '%s|explicit_base' "$BASE_REF"; return
    fi

    if [[ -n "$SINCE_COMMIT" ]]; then
        verify_ref "$SINCE_COMMIT"; printf '%s|commit' "$SINCE_COMMIT"; return
    elif [[ -n "$SINCE_TAG" ]]; then
        verify_ref "$SINCE_TAG"; printf '%s|tag' "$SINCE_TAG"; return
    elif [[ -n "$SINCE_DATE" ]]; then
        # Find the latest commit before the specified date
        local ref
        ref=$(git -c color.ui=false rev-list -1 --before="$SINCE_DATE 23:59:59" HEAD 2>/dev/null || true)
        if [[ -n "$ref" ]]; then
            verify_ref "$ref"; printf '%s|date' "$ref"
        else
            printf 'Warning: No commits found before %s, using first commit\n' "$SINCE_DATE" >&2
            local first_commit
            first_commit=$(git -c color.ui=false rev-list --max-parents=0 HEAD 2>/dev/null || true)
            [[ -n "$first_commit" ]] || { printf 'Error: No commits found in repository\n' >&2; exit 1; }
            printf '%s|first' "$first_commit"
        fi
        return
    fi

    # Default to last tag, fallback to HEAD~1 if no tags exist
    local last_tag
    last_tag=$(git -c color.ui=false describe --tags --abbrev=0 2>/dev/null || true)
    if [[ -n "$last_tag" ]]; then
        verify_ref "$last_tag"
        printf '%s|last_tag' "$last_tag"
    else
        # If no tags exist, use HEAD~1 instead of first commit
        local parent_commit
        parent_commit=$(git -c color.ui=false rev-parse HEAD~1 2>/dev/null || true)
        if [[ -n "$parent_commit" ]]; then
            printf '%s|parent' "$parent_commit"
        else
            # Only use first commit if HEAD~1 doesn't exist (single-commit repo)
            local first_commit
            first_commit=$(git -c color.ui=false rev-list --max-parents=0 HEAD 2>/dev/null || true)
            [[ -n "$first_commit" ]] || { printf 'Error: No commits found in repository\n' >&2; exit 1; }
            printf '%s|first' "$first_commit"
        fi
    fi
}

# Check if there are commits in the range
check_commit_range() {
    local base_ref="$1"
    local target_ref="$2"

    local commit_count
    commit_count=$(git -c color.ui=false rev-list --count "$base_ref".."$target_ref" 2>/dev/null || printf '0')

    (( commit_count > 0 )) || { printf 'Warning: No commits found between %s and %s\n' "$base_ref" "$target_ref" >&2; return 1; }
    return 0
}

# Main execution
main() {
    local base_ref_info
    base_ref_info=$(get_base_reference)
    local base_ref ref_type
    IFS='|' read -r base_ref ref_type <<< "$base_ref_info"

    # Set target reference (default to HEAD)
    if [[ -n "$TARGET_REF" ]]; then
        verify_ref "$TARGET_REF"
    fi

    # Check and normalize disjoint branches with merge-base
    local actual_base
    actual_base=$(git -c color.ui=false merge-base "$base_ref" "$TARGET_REF" 2>/dev/null || printf '')
    if [[ -z "$actual_base" ]]; then
        # Check if this is a single-commit repository
        local commit_count
        commit_count=$(git -c color.ui=false rev-list --count HEAD 2>/dev/null || printf '0')
        if [[ "$commit_count" = "1" ]]; then
            # Single commit repository - no changes to analyze
            if [[ "$PRINT_BASE" = "true" ]]; then
                printf '%s\n' "$base_ref"
            elif [[ "$JSON_OUTPUT" = "true" ]]; then
                printf '{\n'
                printf '  "base_ref": "%s",\n' "$base_ref"
                printf '  "base_ref_type": "%s",\n' "$ref_type"
                printf '  "target_ref": "%s",\n' "$TARGET_REF"
                printf '  "commit_count": 0,\n'
                printf '  "single_commit_repo": true\n'
                printf '}\n'
            elif [[ "$MACHINE_OUTPUT" = "true" ]]; then
                printf 'BASE_REF=%s\n' "$base_ref"
                printf 'BASE_REF_TYPE=%s\n' "$ref_type"
                printf 'TARGET_REF=%s\n' "$TARGET_REF"
                printf 'COMMIT_COUNT=0\n'
                printf 'SINGLE_COMMIT_REPO=true\n'
            else
                printf '=== Reference Resolution ===\n'
                printf 'Single commit repository - no changes to analyze\n'
                printf 'Base reference: %s (%s)\n' "$base_ref" "$ref_type"
                printf 'Target reference: %s\n' "$TARGET_REF"
            fi
            exit 0
        else
            printf 'Error: No common ancestor found between %s and %s. Exiting.\n' "$base_ref" "$TARGET_REF" >&2
            exit 1
        fi
    fi
    if [[ "$actual_base" != "$base_ref" ]] && [[ "$NO_MERGE_BASE" != "true" ]]; then
        if [[ "$MACHINE_OUTPUT" != "true" ]]; then
            printf 'Info: Using merge-base %s instead of %s for disjoint branches\n' "$actual_base" "$base_ref" >&2
        fi
        base_ref="$actual_base"
        ref_type="merge_base"
    fi

    # Handle --print-base option
    if [[ "$PRINT_BASE" = "true" ]]; then
        printf '%s\n' "$base_ref"
        exit 0
    fi

    # Check commit range
    local commit_count=0
    local has_commits=false
    if check_commit_range "$base_ref" "$TARGET_REF"; then
        commit_count=$(git -c color.ui=false rev-list --count "$base_ref".."$TARGET_REF" 2>/dev/null || printf '0')
        has_commits=true
    fi

    # Output results
    if [[ "$JSON_OUTPUT" = "true" ]]; then
        printf '{\n'
        printf '  "base_ref": "%s",\n' "$base_ref"
        printf '  "base_ref_type": "%s",\n' "$ref_type"
        printf '  "target_ref": "%s",\n' "$TARGET_REF"
        printf '  "commit_count": %s,\n' "$commit_count"
        printf '  "has_commits": %s\n' "$has_commits"
        printf '}\n'
    elif [[ "$MACHINE_OUTPUT" = "true" ]]; then
        printf 'BASE_REF=%s\n' "$base_ref"
        printf 'BASE_REF_TYPE=%s\n' "$ref_type"
        printf 'TARGET_REF=%s\n' "$TARGET_REF"
        printf 'COMMIT_COUNT=%s\n' "$commit_count"
        printf 'HAS_COMMITS=%s\n' "$has_commits"
    else
        printf '=== Reference Resolution ===\n'
        printf 'Base reference: %s (%s)\n' "$base_ref" "$ref_type"
        printf 'Target reference: %s\n' "$TARGET_REF"
        printf 'Commit count: %s\n' "$commit_count"
        if [[ "$has_commits" = "true" ]]; then
            printf 'Status: Commits found in range\n'
        else
            printf 'Status: No commits found in range\n'
        fi
    fi
}

# Run main function
main "$@" 