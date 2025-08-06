#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# File Change Analyzer
# Analyzes file changes and classifies them by type

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Prevent any pager and avoid unnecessary repo locks for better performance.
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=0

# Bash features used by this script (for trimming globs safely)
shopt -s extglob

show_help() {
    cat << 'EOF'
File Change Analyzer

Usage: file-change-analyzer [options]

Options:
  --base <ref>             Base reference for comparison              (required)
  --target <ref>           Target reference for comparison (default: HEAD)
  --repo-root <path>       Set repository root directory
  --only-paths <globs>     Restrict analysis to comma-separated path globs
  --ignore-whitespace      Ignore whitespace changes in diff analysis
  --machine                Output machine-readable key=value format
  --json                   Output machine-readable JSON
  --help, -h               Show this help

Examples:
  file-change-analyzer --base v1.0.0 --target HEAD
  file-change-analyzer --base HEAD~5 --target HEAD --machine
  file-change-analyzer --base v1.0.0 --target v1.1.0 --json
EOF
}

# --- Parse arguments ----------------------------------------------------------
BASE_REF=""
TARGET_REF="HEAD"
REPO_ROOT=""
ONLY_PATHS=""
IGNORE_WHITESPACE=false
MACHINE_OUTPUT=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --base)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --base requires a value\n' >&2; exit 1; }
            BASE_REF="$2"; shift 2;;
        --target)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --target requires a value\n' >&2; exit 1; }
            TARGET_REF="$2"; shift 2;;
        --repo-root)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --repo-root requires a value\n' >&2; exit 1; }
            REPO_ROOT="$2"; shift 2;;
        --only-paths)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --only-paths requires a comma-separated globs list\n' >&2; exit 1; }
            ONLY_PATHS="$2"; shift 2;;
        --ignore-whitespace) IGNORE_WHITESPACE=true; shift;;
        --machine) MACHINE_OUTPUT=true; shift;;
        --json) JSON_OUTPUT=true; shift;;
        --help|-h) show_help; exit 0;;
        *) printf 'Error: Unknown option: %s\n' "$1" >&2; show_help; exit 1;;
    esac
done

# --- Validation & setup -------------------------------------------------------
err() { printf '%s\n' "$*" >&2; }

# Validate required arguments
if [[ -z "$BASE_REF" ]]; then
    err 'Error: --base is required'
    exit 1
fi

# Check git command
if ! command -v git >/dev/null 2>&1; then
    err 'Error: git command not found'
    exit 1
fi

# Validate output format options
if [[ "$MACHINE_OUTPUT" == true && "$JSON_OUTPUT" == true ]]; then
    err 'Error: --json and --machine cannot be used together'
    exit 1
fi

# Change to repo root if specified
if [[ -n "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        err "Error: Not in a git repository at $REPO_ROOT"
        exit 1
    }
fi

# Build PATH_ARGS array from --only-paths (as pathspecs)
PATH_ARGS=()
if [[ -n "$ONLY_PATHS" ]]; then
    IFS=',' read -r -a _paths <<< "$ONLY_PATHS"
    if ((${#_paths[@]} > 0)); then
        PATH_ARGS+=(--)
        for g in "${_paths[@]}"; do
            # Trim surrounding spaces via extglob
            g="${g##+([[:space:]])}"
            g="${g%%+([[:space:]])}"
            [[ -n "$g" ]] && PATH_ARGS+=("$g")
        done
    fi
fi

# Validate git references
verify_ref() {
    local ref="$1"
    if ! git -c color.ui=false rev-parse -q --verify "$ref^{commit}" >/dev/null; then
        err "Error: Invalid reference: $ref"
        exit 1
    fi
}

verify_ref "$BASE_REF"
verify_ref "$TARGET_REF"

# --- Classification -----------------------------------------------------------
# Returns: 30=source, 10=test, 20=doc, 0=other/ignored
classify_path() {
    local path="$1"
    local path_lower
    path_lower=$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')

    # Ignore build/third-party/binary artifacts (nested-aware)
    if [[ "$path" =~ (^|/)(build|dist|out|third_party|vendor|\.git|node_modules|target|bin|obj)(/|$) ]] || \
       [[ "$path" =~ \.(lock|exe|dll|so|dylib|jar|war|ear|zip|tar|gz|bz2|xz|7z|rar|png|jpg|jpeg|gif|bmp|ico|pdf)$ ]]; then
        printf '0'; return
    fi

    # Source files (common languages + C/C++)
    if [[ "$path" =~ (^|/)(src|source|app|lib|include)(/|$) ]] || \
       [[ "$path" =~ \.(c|cc|cpp|cxx|h|hh|hpp|inl|go|rs|java|cs|m|mm|swift|kt|ts|tsx|js|jsx|sh|py|rb|php|pl|lua|sql|cmake)$ ]] || \
       [[ "$path" =~ (^|/)(CMakeLists\.txt|Makefile|makefile|GNUmakefile)$ ]]; then
        printf '30'; return
    fi

    # Tests
    if [[ "$path" =~ (^|/)(test|tests|unittests|it|e2e)(/|$) ]] || \
       [[ "$path" =~ (_test|\.test|\.spec)\.(c|cc|cpp|cxx|py|js|ts|sh)$ ]]; then
        printf '10'; return
    fi

    # Documentation
    if [[ "$path_lower" =~ (^|/)(doc|docs|documentation|examples)(/|$) ]] || \
       [[ "$path_lower" =~ (^|/)(readme|changelog|contributing|license|copying|authors|install|news|history) ]] || \
       [[ "$path_lower" =~ \.(md|markdown|mkd|rst|adoc|txt)$ ]]; then
        printf '20'; return
    fi

    printf '0'
}

# --- Helpers -----------------------------------------------------------------
# Binary-safe numstat summation (treats '-' as 0)
sum_numstat() {
    local total_ins=0 total_del=0
    # shellcheck disable=SC2068  # intentional array expansion to pass full cmd
    while IFS=$'\t' read -r ins del _; do
        [[ $ins =~ ^[0-9]+$ ]] || ins=0
        [[ $del =~ ^[0-9]+$ ]] || del=0
        total_ins=$((total_ins + ins))
        total_del=$((total_del + del))
    done < <("$@")
    printf '%s' $((total_ins + total_del))
}

print_empty_results() {
    local reason="$1"
    [[ -n "$reason" ]] && err "Warning: $reason"
    if [[ "$JSON_OUTPUT" = "true" ]]; then
        cat <<'JSON'
{
  "added_files": 0,
  "modified_files": 0,
  "deleted_files": 0,
  "new_source_files": 0,
  "new_test_files": 0,
  "new_doc_files": 0,
  "diff_size": 0
}
JSON
    elif [[ "$MACHINE_OUTPUT" = "true" ]]; then
        printf 'ADDED_FILES=0\nMODIFIED_FILES=0\nDELETED_FILES=0\nNEW_SOURCE_FILES=0\nNEW_TEST_FILES=0\nNEW_DOC_FILES=0\nDIFF_SIZE=0\n'
    else
        printf '=== File Change Analysis ===\nNo changes detected\n'
    fi
}

# --- Core --------------------------------------------------------------------
analyze_file_changes() {
    local base_ref="$1"
    local target_ref="$2"
    
    # Initialize counters
    local added_files=0
    local modified_files=0
    local deleted_files=0
    local new_source_files=0
    local new_test_files=0
    local new_doc_files=0
    local diff_size=0

    # Build common git diff args
    local -a DIFF_ARGS=( -c color.ui=false -c core.quotepath=false )
    local -a DIFF_OPTS=( -M -C )
    if [[ "$IGNORE_WHITESPACE" = "true" ]]; then
        DIFF_OPTS+=( -w )
    fi

    # Quick check: any changes? (respect path filters)
    if git "${DIFF_ARGS[@]}" diff "${DIFF_OPTS[@]}" --quiet "${base_ref}..${target_ref}" "${PATH_ARGS[@]}" 2>/dev/null; then
        local msg="No changes detected between ${base_ref} and ${target_ref}"
        [[ "$IGNORE_WHITESPACE" = "true" ]] && msg+=" (ignoring whitespace)"
        print_empty_results "$msg"
        return
    fi

    # NUL-delimited status (rename/copy aware)
    while IFS= read -r -d '' status; do
        local path1 path2 file
        IFS= read -r -d '' path1 || true
        file="$path1"
        case "${status:0:1}" in
            R|C) IFS= read -r -d '' path2 || true; file="$path2" ;;
        esac

        case "${status:0:1}" in
            A) 
                added_files=$((added_files + 1))
                case "$(classify_path "$file")" in
                    30) new_source_files=$((new_source_files + 1)) ;;
                    10) new_test_files=$((new_test_files + 1)) ;;
                    20) new_doc_files=$((new_doc_files + 1)) ;;
                esac
                ;;
            M|T) modified_files=$((modified_files + 1)) ;;
            D)   deleted_files=$((deleted_files + 1)) ;;
            R|C) modified_files=$((modified_files + 1)) ;; # count rename/copy as modification
        esac
    done < <(git "${DIFF_ARGS[@]}" diff "${DIFF_OPTS[@]}" --name-status -z "${base_ref}..${target_ref}" "${PATH_ARGS[@]}" 2>/dev/null)

    # Compute diff size (insertions + deletions)
    diff_size=$(sum_numstat git "${DIFF_ARGS[@]}" diff "${DIFF_OPTS[@]}" --numstat "${base_ref}..${target_ref}" "${PATH_ARGS[@]}")

    # Output results
    if [[ "$JSON_OUTPUT" = "true" ]]; then
        printf '{\n'
        printf '  "added_files": %s,\n'        "$added_files"
        printf '  "modified_files": %s,\n'     "$modified_files"
        printf '  "deleted_files": %s,\n'      "$deleted_files"
        printf '  "new_source_files": %s,\n'   "$new_source_files"
        printf '  "new_test_files": %s,\n'     "$new_test_files"
        printf '  "new_doc_files": %s,\n'      "$new_doc_files"
        printf '  "diff_size": %s\n'           "$diff_size"
        printf '}\n'
    elif [[ "$MACHINE_OUTPUT" = "true" ]]; then
        printf 'ADDED_FILES=%s\n'       "$added_files"
        printf 'MODIFIED_FILES=%s\n'    "$modified_files"
        printf 'DELETED_FILES=%s\n'     "$deleted_files"
        printf 'NEW_SOURCE_FILES=%s\n'  "$new_source_files"
        printf 'NEW_TEST_FILES=%s\n'    "$new_test_files"
        printf 'NEW_DOC_FILES=%s\n'     "$new_doc_files"
        printf 'DIFF_SIZE=%s\n'         "$diff_size"
    else
        printf '=== File Change Analysis ===\n'
        printf 'Base reference:   %s\n' "$base_ref"
        printf 'Target reference: %s\n' "$target_ref"
        printf '\nFile Changes:\n'
        printf '  Added files:    %s\n' "$added_files"
        printf '  Modified files: %s\n' "$modified_files"
        printf '  Deleted files:  %s\n' "$deleted_files"
        printf '\nNew Content:\n'
        printf '  New source files: %s\n' "$new_source_files"
        printf '  New test files:   %s\n' "$new_test_files"
        printf '  New doc files:    %s\n' "$new_doc_files"
        printf '\nChange Magnitude:\n'
        printf '  Diff size: %s lines\n' "$diff_size"
    fi
}

# --- Main --------------------------------------------------------------------
analyze_file_changes "$BASE_REF" "$TARGET_REF" 