#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# CMake updater for vglog-filter
# Handles updating CMakeLists.txt version fields

set -euo pipefail
export LC_ALL=C

# Source utilities
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/version-utils.sh"

# --- Config / Flags ----------------------------------------------------------
: "${ALLOW_PRERELEASE_IN_CMAKE:=false}"

# --- Small helpers -----------------------------------------------------------
_is_git_repo() {
    command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

_git_add_safe() {
    local path="$1"
    if _is_git_repo; then
        git add -- "$path" || warn "git add failed for $path"
    fi
}

# Strip an optional leading "v"
_normalize_version_token() {
    printf '%s' "${1#v}"
}

_is_prerelease() {
    # true if contains a hyphen e.g., 1.2.3-rc.1
    [[ "$1" == *-* ]]
}

# --- CMake version field detection -------------------------------------------
# Returns one of: variable | inline | set | split | none
detect_cmake_version_format() {
    local cmake_file="$1"
    
    if [[ ! -f "$cmake_file" ]]; then
        printf '%s' "none"
        return
    fi
    
    # Work on non-commented lines only
    # variable: project(... VERSION ${VAR})
    if grep -Ev '^[[:space:]]*#' "$cmake_file" | \
       grep -Eq '^[[:space:]]*project\([^)]*VERSION[[:space:]]+\$\{[^}]+\}'; then
        printf '%s' "variable"
        return
    fi
    
    # inline: project(... VERSION 1.2.3)
    if grep -Ev '^[[:space:]]*#' "$cmake_file" | \
       grep -Eq '^[[:space:]]*project\([^)]*VERSION[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+'; then
        printf '%s' "inline"
        return
    fi
    
    # set: set(PROJECT_VERSION 1.2.3) (with or without quotes)
    if grep -Ev '^[[:space:]]*#' "$cmake_file" | \
       grep -Eq '^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION[[:space:]]+"?[0-9]+\.[0-9]+\.[0-9]+'; then
        printf '%s' "set"
        return
    fi
    
    # split: set(PROJECT_VERSION_MAJOR 1) etc.
    if grep -Ev '^[[:space:]]*#' "$cmake_file" | \
       grep -Eq '^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION_(MAJOR|MINOR|PATCH)[[:space:]]+"?[0-9]+'; then
        printf '%s' "split"
        return
    fi
    
    printf '%s' "none"
}

# --- CMake version update functions ------------------------------------------
update_cmake_variable_format() {
    local cmake_file="$1"
    local new_version="$2"
    
    # For variable format, no update needed since CMakeLists.txt reads from VERSION file
    printf '%s\n' "${GREEN}CMakeLists.txt uses VERSION file variable (no update needed)${RESET}" >&2
    return 0
}

update_cmake_inline_format() {
    local cmake_file="$1"
    local new_version="$2"
    
    local before after
    before="$(_hash_file "$cmake_file")"
    
    # Replace on non-commented lines only
    sed -E -i '/^[[:space:]]*#/! s/(^[[:space:]]*project\([^)]*VERSION[[:space:]]+)[0-9]+\.[0-9]+\.[0-9]+/\1'"$new_version"'/g' "$cmake_file"
    
    after="$(_hash_file "$cmake_file")"
    if [[ -n "$before" && -n "$after" && "$before" != "$after" ]]; then
        printf '%s\n' "${GREEN}Updated CMakeLists.txt to ${new_version}${RESET}" >&2
        _git_add_safe "$cmake_file"
        return 0
    else
        warn "No changes made to CMakeLists.txt"
        return 1
    fi
}

update_cmake_set_format() {
    local cmake_file="$1"
    local new_version="$2"
    
    local before after
    before="$(_hash_file "$cmake_file")"
    
    sed -E -i '/^[[:space:]]*#/! s/(^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION[[:space:]]+"?)[0-9]+\.[0-9]+\.[0-9]+/\1'"$new_version"'/g' "$cmake_file"
    
    after="$(_hash_file "$cmake_file")"
    if [[ -n "$before" && -n "$after" && "$before" != "$after" ]]; then
        printf '%s\n' "${GREEN}Updated CMakeLists.txt to ${new_version}${RESET}" >&2
        _git_add_safe "$cmake_file"
        return 0
    else
        warn "No changes made to CMakeLists.txt"
        return 1
    fi
}

update_cmake_split_format() {
    local cmake_file="$1"
    local new_version="$2"
    local major minor patch
    IFS='.' read -r major minor patch <<<"$new_version"
    
    local before after
    before="$(_hash_file "$cmake_file")"
    
    # Only on non-commented lines
    sed -E -i "/^[[:space:]]*#/! s/(^[[:space:]]*set[[:space:]]*\\([[:space:]]*PROJECT_VERSION_MAJOR[[:space:]]+\")?[0-9]+((\"|)[[:space:]]*\\).*/\\1${major}\\2/g" "$cmake_file" || true
    sed -E -i "/^[[:space:]]*#/! s/(^[[:space:]]*set[[:space:]]*\\([[:space:]]*PROJECT_VERSION_MINOR[[:space:]]+\")?[0-9]+((\"|)[[:space:]]*\\).*/\\1${minor}\\2/g" "$cmake_file" || true
    sed -E -i "/^[[:space:]]*#/! s/(^[[:space:]]*set[[:space:]]*\\([[:space:]]*PROJECT_VERSION_PATCH[[:space:]]+\")?[0-9]+((\"|)[[:space:]]*\\).*/\\1${patch}\\2/g" "$cmake_file" || true
    
    after="$(_hash_file "$cmake_file")"
    if [[ -n "$before" && -n "$after" && "$before" != "$after" ]]; then
        printf '%s\n' "${GREEN}Updated CMakeLists.txt (MAJOR=${major}, MINOR=${minor}, PATCH=${patch})${RESET}" >&2
        _git_add_safe "$cmake_file"
        return 0
    else
        warn "No changes made to CMakeLists.txt"
        return 1
    fi
}

# --- Main CMake update function ----------------------------------------------
update_cmake_version() {
    local cmake_file="$1"
    local raw_version="$2"
    
    if [[ ! -f "$cmake_file" ]]; then
        return 0
    fi
    
    local new_version
    new_version="$(_normalize_version_token "$raw_version")"
    
    if _is_prerelease "$new_version" && [[ "$ALLOW_PRERELEASE_IN_CMAKE" != "true" ]]; then
        warn "Skipping CMakeLists.txt update for pre-release (${new_version})"
        return 0
    fi
    
    local format
    format=$(detect_cmake_version_format "$cmake_file")
    
    case "$format" in
        "variable")
            update_cmake_variable_format "$cmake_file" "$new_version"
            ;;
        "inline")
            update_cmake_inline_format "$cmake_file" "$new_version"
            ;;
        "set")
            update_cmake_set_format "$cmake_file" "$new_version"
            ;;
        "split")
            update_cmake_split_format "$cmake_file" "$new_version"
            ;;
        "none")
            warn "CMakeLists.txt present but no recognizable version field"
            return 0
            ;;
        *)
            warn "Unknown CMake version format"
            return 1
            ;;
    esac
}

# --- Dry run simulation ------------------------------------------------------
simulate_cmake_update() {
    local cmake_file="$1"
    local raw_version="$2"
    local new_version
    new_version="$(_normalize_version_token "$raw_version")"
    
    if _is_prerelease "$new_version" && [[ "$ALLOW_PRERELEASE_IN_CMAKE" != "true" ]]; then
        printf '%s\n' "${YELLOW}DRY RUN: Would skip CMakeLists update (pre-release ${new_version})${RESET}" >&2
        return 0
    fi
    
    if [[ ! -f "$cmake_file" ]]; then
        printf '%s\n' "${YELLOW}DRY RUN: Would skip CMakeLists (file not found)${RESET}" >&2
        return 0
    fi
    
    local format
    format=$(detect_cmake_version_format "$cmake_file")
    
    case "$format" in
        "variable")
            printf '%s\n' "${YELLOW}DRY RUN: Would skip CMakeLists.txt update (uses VERSION file variable)${RESET}" >&2
            ;;
        "inline")
            printf '%s\n' "${YELLOW}DRY RUN: Would update CMakeLists.txt to $new_version${RESET}" >&2
            ;;
        "set")
            printf '%s\n' "${YELLOW}DRY RUN: Would update set(PROJECT_VERSION ...) to $new_version${RESET}" >&2
            ;;
        "split")
            printf '%s\n' "${YELLOW}DRY RUN: Would set MAJOR/MINOR/PATCH to $new_version${RESET}" >&2
            ;;
        "none")
            printf '%s\n' "${YELLOW}DRY RUN: Would skip CMakeLists.txt update (no recognizable version field)${RESET}" >&2
            ;;
        *)
            printf '%s\n' "${YELLOW}DRY RUN: Would skip CMakeLists.txt update (unknown format)${RESET}" >&2
            ;;
    esac
}

# --- CMake validation --------------------------------------------------------
validate_cmake_file() {
    local cmake_file="$1"
    
    if [[ ! -f "$cmake_file" ]]; then
        return 1
    fi
    
    # Basic CMake syntax check - only on non-commented lines
    if ! grep -Ev '^[[:space:]]*#' "$cmake_file" | grep -q '^[[:space:]]*project('; then
        warn "CMakeLists.txt does not contain a project() declaration"
        return 1
    fi
    
    return 0
}

# --- CMake version extraction ------------------------------------------------
extract_cmake_version() {
    local cmake_file="$1"
    
    if [[ ! -f "$cmake_file" ]]; then
        return 1
    fi
    
    local format
    format=$(detect_cmake_version_format "$cmake_file")
    
    case "$format" in
        "inline")
            grep -Ev '^[[:space:]]*#' "$cmake_file" | \
                grep -E '^[[:space:]]*project\([^)]*VERSION[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' | \
                sed -E 's/.*VERSION[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -n1
            ;;
        "set")
            grep -Ev '^[[:space:]]*#' "$cmake_file" | \
                grep -E '^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION[[:space:]]+"?[0-9]+\.[0-9]+\.[0-9]+' | \
                sed -E 's/.*PROJECT_VERSION[[:space:]]+"?([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -n1
            ;;
        "split")
            local maj min pat
            maj="$(grep -Ev '^[[:space:]]*#' "$cmake_file" | grep -E '^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION_MAJOR[[:space:]]+"?[0-9]+' | sed -E 's/.*PROJECT_VERSION_MAJOR[[:space:]]+"?([0-9]+).*/\1/' | head -n1 || true)"
            min="$(grep -Ev '^[[:space:]]*#' "$cmake_file" | grep -E '^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION_MINOR[[:space:]]+"?[0-9]+' | sed -E 's/.*PROJECT_VERSION_MINOR[[:space:]]+"?([0-9]+).*/\1/' | head -n1 || true)"
            pat="$(grep -Ev '^[[:space:]]*#' "$cmake_file" | grep -E '^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_VERSION_PATCH[[:space:]]+"?[0-9]+' | sed -E 's/.*PROJECT_VERSION_PATCH[[:space:]]+"?([0-9]+).*/\1/' | head -n1 || true)"
            if [[ -n "$maj" && -n "$min" && -n "$pat" ]]; then
                printf '%s.%s.%s\n' "$maj" "$min" "$pat"
            else
                return 1
            fi
            ;;
        "variable"|"none"|*)
            return 1
            ;;
    esac
}

# --- CMake backup and restore ------------------------------------------------
backup_cmake_file() {
    local cmake_file="$1"
    local backup_dir="$2"
    
    if [[ ! -f "$cmake_file" ]]; then
        return 1
    fi
    
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/CMakeLists.txt.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$cmake_file" "$backup_file"
    printf '%s' "$backup_file"
}

restore_cmake_file() {
    local backup_file="$1"
    local cmake_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        return 1
    fi
    
    cp "$backup_file" "$cmake_file"
    success "Restored CMakeLists.txt from backup"
}

# --- Main CMake operations function -----------------------------------------
perform_cmake_operations() {
    local cmake_file="$1"
    local new_version="$2"
    local update_cmake="$3"
    local dry_run="$4"
    
    if [[ "$update_cmake" != "true" ]]; then
        warn "Skipped CMakeLists.txt update (--no-cmake)"
        return 0
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        simulate_cmake_update "$cmake_file" "$new_version"
        return 0
    fi
    
    update_cmake_version "$cmake_file" "$new_version"
}

# --- Standalone usage --------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize colors
    init_colors "${NO_COLOR:-false}"
    
    case "${1:-}" in
        "update")
            if [[ $# -lt 3 ]]; then
                die "Usage: $0 update <cmake_file> <new_version> [ALLOW_PRERELEASE_IN_CMAKE=true]"
            fi
            shift
            cmake_file="$1"
            new_ver="$2"
            shift 2 || true
            # allow inline override: $0 update file 1.2.3 ALLOW_PRERELEASE_IN_CMAKE=true
            for arg in "$@"; do
                case "$arg" in
                    ALLOW_PRERELEASE_IN_CMAKE=true) ALLOW_PRERELEASE_IN_CMAKE=true ;;
                esac
            done
            update_cmake_version "$cmake_file" "$new_ver"
            ;;
        "detect")
            if [[ $# -lt 2 ]]; then
                die "Usage: $0 detect <cmake_file>"
            fi
            format=$(detect_cmake_version_format "$2")
            printf '%s\n' "$format"
            ;;
        "extract")
            if [[ $# -lt 2 ]]; then
                die "Usage: $0 extract <cmake_file>"
            fi
            extract_cmake_version "$2" || die "Could not extract version"
            ;;
        "validate")
            if [[ $# -lt 2 ]]; then
                die "Usage: $0 validate <cmake_file>"
            fi
            if validate_cmake_file "$2"; then
                success "CMakeLists.txt is valid"
            else
                die "CMakeLists.txt validation failed"
            fi
            ;;
        "simulate")
            if [[ $# -lt 3 ]]; then
                die "Usage: $0 simulate <cmake_file> <new_version>"
            fi
            simulate_cmake_update "$2" "$3"
            ;;
        *)
            cat << 'EOF'
Usage: $0 <command> [args...]

Commands:
  update <cmake_file> <new_version> [ALLOW_PRERELEASE_IN_CMAKE=true]
      Update CMakeLists.txt version.

  detect <cmake_file>
      Detect version format (variable|inline|set|split|none).

  extract <cmake_file>
      Extract version from CMakeLists.txt (inline/set/split).

  validate <cmake_file>
      Basic check: file exists and has a non-commented project().

  simulate <cmake_file> <new_version>
      Dry-run: print the action that would be taken.

Env:
  ALLOW_PRERELEASE_IN_CMAKE=true   Allow writing pre-release versions into CMake.

Examples:
  $0 update CMakeLists.txt 1.0.1
  $0 detect CMakeLists.txt
  $0 extract CMakeLists.txt
  $0 validate CMakeLists.txt
  ALLOW_PRERELEASE_IN_CMAKE=true $0 simulate CMakeLists.txt v1.2.3-rc.1
EOF
            exit 1
            ;;
    esac
fi 