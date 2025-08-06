#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Version validator for vglog-filter
# Handles version format validation and related checks

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Prevent pagers/locks in CI for speed and determinism
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=0

# Source utilities
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/version-utils.sh"

# Initialize colors only for standalone usage; library users can call directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_colors "${NO_COLOR:-false}"
fi

# --- SemVer parsing and comparison helpers -----------------------------------
# Strip build metadata: 1.2.3-rc.1+abc -> 1.2.3-rc.1
strip_build_meta() {
    local v="$1"
    printf '%s' "${v%%+*}"
}

# --- Version validation -------------------------------------------------------
validate_version_format() {
    local version="$1"
    local allow_prerelease="$2"

    if [[ "$allow_prerelease" == "true" ]]; then
        if ! _is_semver_with_prerelease "$version"; then
            _die "Invalid version format: $version"
            printf '%s\n' "${YELLOW}Expected: MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-PRERELEASE (e.g., 1.0.0 or 1.0.0-rc.1)${RESET}" >&2
            printf '%s\n' "${YELLOW}Note: Leading zeros are not allowed${RESET}" >&2
        fi
    else
        if ! _is_semver_core "$version"; then
            _die "Invalid version format: $version"
            printf '%s\n' "${YELLOW}Expected: MAJOR.MINOR.PATCH (e.g., 1.0.0)${RESET}" >&2
            printf '%s\n' "${YELLOW}Note: Leading zeros are not allowed${RESET}" >&2
            printf '%s\n' "${YELLOW}Note: Pre-releases require --allow-prerelease with --set${RESET}" >&2
        fi
    fi
}

validate_version_file() {
    local version_file="$1"
    local project_root="$2"
    
    if [[ ! -f "$version_file" ]]; then
        return 1
    fi
    
    validate_version_file_path "$version_file" "$project_root"
    
    local current_version
    current_version=$(read_version_file "$version_file")
    if [[ ! "$current_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
        _die "Invalid version format in VERSION: $current_version"
        printf '%s\n' "${YELLOW}Expected: MAJOR.MINOR.PATCH${RESET}" >&2
    fi
    
    printf '%s' "$current_version"
}

# --- Version comparison -------------------------------------------------------
# Public: compare two versions using full SemVer. echo -1|0|1
compare_versions() {
    local v1="$1" v2="$2"
    
    # For now, use a simpler approach that works with the existing validation
    # Strip any build metadata first
    local clean_v1="${v1%%+*}" clean_v2="${v2%%+*}"
    
    # Split into main version and prerelease
    local m1="${clean_v1%%-*}" pr1="${clean_v1#*-}"
    local m2="${clean_v2%%-*}" pr2="${clean_v2#*-}"
    
    # If no prerelease, set to empty
    [[ "$pr1" == "$m1" ]] && pr1=""
    [[ "$pr2" == "$m2" ]] && pr2=""
    
    # Parse main versions
    local v1_major v1_minor v1_patch v2_major v2_minor v2_patch
    
    IFS='.' read -r v1_major v1_minor v1_patch <<< "$m1"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "$m2"
    
    # Compare major
    if (( v1_major < v2_major )); then
        printf '%s' "-1"
    elif (( v1_major > v2_major )); then
        printf '%s' "1"
    else
        # Compare minor
        if (( v1_minor < v2_minor )); then
            printf '%s' "-1"
        elif (( v1_minor > v2_minor )); then
            printf '%s' "1"
        else
            # Compare patch
            if (( v1_patch < v2_patch )); then
                printf '%s' "-1"
            elif (( v1_patch > v2_patch )); then
                printf '%s' "1"
            else
                # Versions are equal, compare prereleases
                if [[ -z "$pr1" && -z "$pr2" ]]; then
                    printf '%s' "0"
                elif [[ -z "$pr1" && -n "$pr2" ]]; then
                    printf '%s' "1"
                elif [[ -n "$pr1" && -z "$pr2" ]]; then
                    printf '%s' "-1"
                else
                    # Both have prereleases, compare lexicographically for now
                    if [[ "$pr1" < "$pr2" ]]; then
                        printf '%s' "-1"
                    elif [[ "$pr1" > "$pr2" ]]; then
                        printf '%s' "1"
                    else
                        printf '%s' "0"
                    fi
                fi
            fi
        fi
    fi
}

is_version_greater() {
    local new_version="$1"
    local last_version="$2"
    
    [[ "$(compare_versions "$new_version" "$last_version")" == "1" ]]
}

# --- Version order validation -------------------------------------------------
# Only check monotonicity for *stable* target (skip if new is prerelease)
check_version_order() {
    local new_version="$1"
    local tag_prefix="$2"
    local allow_nonmonotonic="$3"
    
    if [[ "$new_version" == *-* ]]; then
        return 0
    fi
    
    local last_tag
    last_tag="$(last_tag_for_prefix "$tag_prefix" || true)"

    if [[ -n "$last_tag" ]]; then
        local last_version="${last_tag:${#tag_prefix}}"
        # If last tag isn't strict semver, we don't enforce
        if ! _is_semver_core "$last_version"; then
            return 0
        fi

        if ! is_version_greater "$new_version" "$last_version"; then
            _warn "New version $new_version is not greater than last tag $last_tag"
            if [[ -n "${GITHUB_ACTIONS:-}" && "$allow_nonmonotonic" != "true" ]]; then
                _die "NEW_VERSION ($new_version) must be greater than last tag ($last_tag)"
                printf '%s\n' "${YELLOW}Use --allow-nonmonotonic-tag to override in CI.${RESET}" >&2
            fi
        fi
    fi
}

# --- Version parsing ---------------------------------------------------------
parse_version_components() {
    local version="$1"
    local major minor patch
    
    # Strip build metadata and prerelease
    local main_version="${version%%+*}"
    main_version="${main_version%%-*}"
    
    IFS='.' read -r major minor patch <<< "$main_version"
    printf '%s\n%s\n%s' "$major" "$minor" "$patch"
}

# --- Pre-release validation --------------------------------------------------
is_prerelease() {
    local version="$1"
    [[ "$(strip_build_meta "$version")" == *-* ]]
}

validate_prerelease_format() {
    local version="$1"
    if is_prerelease "$version"; then
        if ! _is_semver_with_prerelease "$version"; then
            _die "Invalid pre-release format: $version"
            printf '%s\n' "${YELLOW}Expected: MAJOR.MINOR.PATCH-PRERELEASE (e.g., 1.0.0-rc.1)${RESET}" >&2
        fi
    fi
}

# --- Main validation function -------------------------------------------------
validate_version_input() {
    local version="$1"
    local allow_prerelease="$2"
    local tag_prefix="$3"
    local allow_nonmonotonic="$4"
    
    # Validate format
    validate_version_format "$version" "$allow_prerelease"
    
    # Check version order if not a pre-release
    if ! is_prerelease "$version"; then
        check_version_order "$version" "$tag_prefix" "$allow_nonmonotonic"
    fi
}

# --- CLI usage ---------------------------------------------------------------
usage() {
    cat <<'EOF'
Usage: version-validator <command> [args...]

Commands:
  validate <version> [allow_prerelease]   Validate version format
  compare <version1> <version2>           Compare two versions (-1|0|1) with full SemVer precedence
  parse <version>                          Print MAJOR NEWLINE MINOR NEWLINE PATCH
  is-prerelease <version>                  Print true/false; exits 0 for true, 1 for false

Extras (optional):
  validate-file <path> <project_root>      Validate VERSION file (strict MAJOR.MINOR.PATCH)
  order-check <version> <tag_prefix> [allow_nonmonotonic=true|false]
                                           Enforce monotonic increase vs last tag (stable only)

Notes:
- Pre-release precedence is implemented per SemVer 2.0.0 (numeric < alphanumeric, field-wise compare).
- Build metadata (+meta) is ignored in precedence checks, as per spec.
EOF
}

# --- Standalone usage --------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-}"; shift || true
    case "$cmd" in
        "validate")
            if [[ $# -lt 1 ]]; then
                _die "Usage: $0 validate <version> [allow_prerelease]"
            fi
            validate_version_format "$1" "${2:-false}"
            _ok "Version format is valid"
            ;;
        "compare")
            if [[ $# -lt 2 ]]; then
                _die "Usage: $0 compare <version1> <version2>"
            fi
            result=$(compare_versions "$1" "$2")
            printf '%s\n' "$result"
            ;;
        "parse")
            if [[ $# -lt 1 ]]; then
                _die "Usage: $0 parse <version>"
            fi
            parse_version_components "$1"
            ;;
        "is-prerelease")
            if [[ $# -lt 1 ]]; then
                _die "Usage: $0 is-prerelease <version>"
            fi
            if is_prerelease "$1"; then
                printf '%s\n' "true"
                exit 0
            else
                printf '%s\n' "false"
                exit 1
            fi
            ;;
        "validate-file")
            if [[ $# -lt 2 ]]; then
                _die "Usage: $0 validate-file <path> <project_root>"
            fi
            validate_version_file "$1" "$2" >/dev/null
            _ok "VERSION file is valid"
            ;;
        "order-check")
            if [[ $# -lt 2 ]]; then
                _die "Usage: $0 order-check <version> <tag_prefix> [allow_nonmonotonic=true|false]"
            fi
            check_version_order "$1" "$2" "${3:-false}"
            ;;
        -h|--help|help|"")
            usage
            ;;
        *)
            _die "Unknown command: $cmd" "$(usage)"
            ;;
    esac
fi 