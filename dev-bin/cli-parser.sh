#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# CLI parser for vglog-filter
# Handles command line argument parsing for version management scripts

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/version-utils.sh"

# --- Default option values ---------------------------------------------------
declare -A DEFAULT_OPTIONS=(
    ["COMMIT_MSG"]=""
    ["ALLOW_DIRTY"]="false"
    ["ANNOTATED_TAG"]="true"
    ["SIGNED_TAG"]="false"
    ["COMMIT_SIGN"]="false"
    ["NO_VERIFY"]="false"
    ["UPDATE_CMAKE"]="true"
    ["TAG_PREFIX"]="${TAG_PREFIX:-v}"
    ["SET_VERSION"]=""
    ["NO_COLOR"]="false"
    ["DO_PUSH"]="false"
    ["PUSH_TAGS"]="false"
    ["ALLOW_NONMONOTONIC_TAG"]="false"
    ["ALLOW_PRERELEASE"]="false"
    ["REPO_ROOT"]=""
    ["REMOTE"]="${REMOTE:-origin}"
    ["BUMP_TYPE"]=""
    ["DO_COMMIT"]="false"
    ["DO_TAG"]="false"
    ["DRY_RUN"]="false"
    ["PRINT_ONLY"]="false"
)

# Stable print order (purely cosmetic)
ORDERED_KEYS=(
    BUMP_TYPE SET_VERSION ALLOW_PRERELEASE
    DO_COMMIT DO_TAG COMMIT_SIGN SIGNED_TAG ANNOTATED_TAG NO_VERIFY
    DO_PUSH PUSH_TAGS REMOTE
    ALLOW_DIRTY UPDATE_CMAKE TAG_PREFIX
    DRY_RUN PRINT_ONLY NO_COLOR
    REPO_ROOT COMMIT_MSG
    ALLOW_NONMONOTONIC_TAG
)

# --- Helper functions --------------------------------------------------------
_semver_prere='-([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)'
_semver_re='^[0-9]+(\.[0-9]+){2}('"$_semver_prere"')?$'

require_value() {
    # echo the next arg or fail; usage: VAR="$(require_value --opt)"
    local opt="$1"
    if (( i + 1 >= ${#args[@]} )); then
        die "$opt requires a value"
    fi
    i=$((i + 1))
    printf '%s' "${args[$i]}"
    # Debug: echo "require_value: $opt = ${args[$i]}, i = $i" >&2
}

normalize_bool() {
    case "${1,,}" in
        1|true|yes|on)  printf 'true' ;;
        0|false|no|off) printf 'false' ;;
        *)              printf '%s' "$1" ;;
    esac
}

is_prerelease() {
    [[ "$1" == *-* ]]
}

# --- Option parsing ---------------------------------------------------------
parse_bump_version_args() {
    local args=("$@")
    local i=0
    local skip_increment=false
    
    # Initialize options with defaults
    for key in "${!DEFAULT_OPTIONS[@]}"; do
        eval "$key=\"${DEFAULT_OPTIONS[$key]}\""
    done
    
    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"
        skip_increment=false
        
        case "$arg" in
            --)  # end-of-options (no positional args expected beyond this point)
                if (( i + 1 < ${#args[@]} )); then
                    die "Unexpected arguments after --: ${args[*]:$((i+1))}"
                fi
                ;;
            major|minor|patch)
                if [[ -n "$BUMP_TYPE" ]]; then
                    die "Multiple bump types specified"
                fi
                BUMP_TYPE="$arg"
                ;;
            --commit)
                DO_COMMIT="true"
                ;;
            --tag)
                DO_TAG="true"
                ;;
            --dry-run)
                DRY_RUN="true"
                ;;
            --print)
                PRINT_ONLY="true"
                ;;
            --message)
                COMMIT_MSG="$(require_value --message)"
                skip_increment=true
                ;;
            --allow-dirty)
                ALLOW_DIRTY="true"
                ;;
            --lightweight-tag)
                ANNOTATED_TAG="false"
                SIGNED_TAG="false"
                ;;
            --signed-tag)
                # Signed tag is by definition annotated; do NOT mark as lightweight.
                SIGNED_TAG="true"
                ANNOTATED_TAG="true"
                ;;
            --sign-commit)
                COMMIT_SIGN="true"
                ;;
            --no-verify)
                NO_VERIFY="true"
                ;;
            --no-cmake)
                UPDATE_CMAKE="false"
                ;;
            --tag-prefix)
                TAG_PREFIX="$(require_value --tag-prefix)"
                skip_increment=true
                ;;
            --set)
                SET_VERSION="$(require_value --set)"
                skip_increment=true
                ;;
            --no-color)
                NO_COLOR="true"
                ;;
            --push)
                DO_PUSH="true"
                ;;
            --push-tags)
                PUSH_TAGS="true"
                ;;
            --allow-nonmonotonic-tag)
                ALLOW_NONMONOTONIC_TAG="true"
                ;;
            --allow-prerelease)
                ALLOW_PRERELEASE="true"
                ;;
            --repo-root)
                REPO_ROOT="$(require_value --repo-root)"
                skip_increment=true
                ;;
            --remote)
                REMOTE="$(require_value --remote)"
                if [[ -z "$REMOTE" ]]; then
                    die "--remote requires a non-empty value"
                fi
                skip_increment=true
                ;;
            -h|--help|help)
                show_usage
                exit 0
                ;;
            -*)
                die "Unknown option '$arg'"
                ;;
            *)
                die "Unknown argument '$arg'"
                ;;
        esac
        if [[ "$skip_increment" != "true" ]]; then
            i=$((i + 1))
        fi
    done
    
    # Validate TAG_PREFIX content
    if [[ "$TAG_PREFIX" == *$'\n'* || "$TAG_PREFIX" == *$'\r'* ]]; then
        die "TAG_PREFIX contains newline characters"
    fi
    
    # Normalize boolean-ish env/values (defensive)
    for key in ALLOW_DIRTY ANNOTATED_TAG SIGNED_TAG COMMIT_SIGN NO_VERIFY \
               UPDATE_CMAKE NO_COLOR DO_PUSH PUSH_TAGS ALLOW_NONMONOTONIC_TAG \
               ALLOW_PRERELEASE DO_COMMIT DO_TAG DRY_RUN PRINT_ONLY; do
        eval "$key=\"$(normalize_bool "${!key}")\""
    done
    
    # Early exclusivity/cross checks
    if [[ "$DRY_RUN" == "true" && "$PRINT_ONLY" == "true" ]]; then
        die "--dry-run and --print cannot be used together"
    fi
    if [[ "$PRINT_ONLY" == "true" ]] && \
       { [[ "$DO_COMMIT" == "true" ]] || [[ "$DO_TAG" == "true" ]] || \
         [[ "$DO_PUSH" == "true" ]] || [[ "$PUSH_TAGS" == "true" ]]; }; then
        die "--print cannot be combined with commit/tag/push actions"
    fi
    if [[ "$DRY_RUN" == "true" ]] && \
       { [[ "$DO_PUSH" == "true" ]] || [[ "$PUSH_TAGS" == "true" ]]; }; then
        die "--dry-run cannot push"
    fi
    
    # Must specify either a bump type or --set
    if [[ -z "$BUMP_TYPE" && -z "$SET_VERSION" ]]; then
        die "No bump type specified (choose major|minor|patch) or provide --set"
    fi
    if [[ -n "$BUMP_TYPE" && -n "$SET_VERSION" ]]; then
        die "Cannot specify both a bump type and --set"
    fi
    
    # --set validation (SemVer + prerelease gate)
    if [[ -n "$SET_VERSION" ]]; then
        if ! [[ "$SET_VERSION" =~ $_semver_re ]]; then
            die "--set expects SemVer (X.Y.Z) with optional prerelease (e.g., 1.2.3-rc.1)"
        fi
        if is_prerelease "$SET_VERSION" && [[ "$ALLOW_PRERELEASE" != "true" ]]; then
            die "Pre-release versions require --allow-prerelease with --set"
        fi
        # Behavior note states prereleases are not written/tagged; enforce here
        if is_prerelease "$SET_VERSION" && { [[ "$DO_TAG" == "true" ]] || [[ "$DO_COMMIT" == "true" ]]; }; then
            die "Pre-release set via --set cannot be committed or tagged; use --print to inspect"
        fi
    else
        # bump path: forbid prerelease-only flags without effect
        if [[ "$ALLOW_PRERELEASE" == "true" ]]; then
            warn "--allow-prerelease has no effect without --set"
        fi
    fi
    
    # Warn about tag switches without --tag
    if { [[ "$SIGNED_TAG" == "true" ]] || [[ "$ANNOTATED_TAG" == "false" ]]; } && [[ "$DO_TAG" != "true" ]]; then
        warn "Tag options provided without --tag; they will have no effect"
    fi
}

# --- Usage and help ---------------------------------------------------------
show_usage() {
    local help_version="N/A"
    if [[ -f "${VERSION_FILE:-}" ]]; then
        help_version=$(tr -d '[:space:]' < "${VERSION_FILE:-}" 2>/dev/null || printf 'N/A')
    fi
    
    cat << EOF
Usage: ./dev-bin/bump-version.sh [major|minor|patch] [--commit] [--tag] [--dry-run] [--message MSG] [--allow-dirty] [--lightweight-tag] [--signed-tag] [--no-verify] [--print] [--no-cmake] [--tag-prefix PREFIX] [--sign-commit] [--set VERSION] [--no-color] [--push] [--push-tags] [--allow-nonmonotonic-tag] [--allow-prerelease] [--repo-root PATH] [--remote REMOTE]

Bump the semantic version of vglog-filter

Requirements:
  GNU tools on Linux: realpath, sha1sum (or shasum), GNU sed, GNU grep
  macOS users: run in GNU coreutils + gsed environment (e.g., brew install coreutils gnu-sed)

Behavior notes:
  • Pre-releases (X.Y.Z-PRERELEASE) are supported only with --set.
    They are not written to VERSION and cannot be tagged.
  • --print computes the version and exits early without validations or git checks.
  • --dry-run prints actions and skips dirty-tree enforcement.
  • Commits only include VERSION and CMakeLists.txt (if updated).
  • --signed-tag implies an annotated, signed tag (not lightweight).
  • --print cannot be combined with commit/tag/push actions.
  • --dry-run cannot push.

File Tracking Requirements:
  • VERSION file must be tracked in git for version bumps
  • CMakeLists.txt is automatically updated if it contains a version field
  • Only tracked files are included in version bump commits

Arguments:
  major | minor | patch

Options:
  --commit                 Create a git commit with the version bump
  --tag                    Create a git tag for the new version
  --dry-run                Show actions without making changes
  --print                  Print the new version and exit
  --message MSG            Use MSG as the full commit message (overrides default)
  --allow-dirty            Allow committing/tagging with other changes present
  --lightweight-tag        Create a lightweight tag (default is annotated)
  --signed-tag             Create a signed tag (requires GPG config)
  --sign-commit            GPG-sign the commit (requires GPG config)
  --no-verify              Skip commit hooks
  --no-cmake               Skip updating CMakeLists.txt version
  --tag-prefix PREFIX      Tag prefix (default: v; empty allowed)
  --set VERSION            Set version to VERSION (format X.Y.Z or with --allow-prerelease)
  --no-color               Disable colored output
  --push                   Push current branch and, if tagged, the new tag
  --push-tags              Push all tags
  --allow-nonmonotonic-tag Allow setting a version lower/equal to the last tag
  --allow-prerelease       Allow prerelease with --set (e.g., 1.0.0-rc.1)
  --repo-root PATH         Use PATH as repository root
  --remote REMOTE          Git remote to push to (default: \$REMOTE or 'origin')

Environment:
  ANALYSIS_MESSAGE         Extra paragraph appended to default commit message
  TAG_PREFIX               Default tag prefix (overridden by --tag-prefix)
  REMOTE                   Default remote for push operations (overridden by --remote)
  VERSION_PATCH_LIMIT      Patch version limit before rollover (default: 100)
  VERSION_MINOR_LIMIT      Minor version limit before rollover (default: 100)
  VERSION_PATCH_DELTA      Patch delta formula (default: 1*(1+LOC/250))
  VERSION_MINOR_DELTA      Minor delta formula (default: 5*(1+LOC/500))
  VERSION_MAJOR_DELTA      Major delta formula (default: 10*(1+LOC/1000))

Examples:
  ./dev-bin/bump-version.sh patch
  ./dev-bin/bump-version.sh minor --commit
  ./dev-bin/bump-version.sh major --commit --tag
  ./dev-bin/bump-version.sh patch --dry-run
  ./dev-bin/bump-version.sh patch --print
  ANALYSIS_MESSAGE='…' ./dev-bin/bump-version.sh patch --commit
  ./dev-bin/bump-version.sh patch --signed-tag --tag
  ./dev-bin/bump-version.sh --set 2.1.0 --commit
  ./dev-bin/bump-version.sh --set 1.0.0-rc.1 --allow-prerelease --print

Current version: $help_version
EOF
}

# --- Option export ----------------------------------------------------------
export_parsed_options() {
    # Export all parsed options as environment variables
    for key in "${!DEFAULT_OPTIONS[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            export "$key"
        fi
    done
}

output_parsed_options() {
    # Print in a stable, readable order (shell-friendly KEY="VAL")
    for key in "${ORDERED_KEYS[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            printf '%s="%s"\n' "$key" "${!key}"
        fi
    done
    # Include any keys missing from ORDERED_KEYS
    for key in "${!DEFAULT_OPTIONS[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            local seen=0
            for k in "${ORDERED_KEYS[@]}"; do 
                if [[ "$k" == "$key" ]]; then 
                    seen=1
                    break
                fi
            done
            if (( ! seen )); then
                printf '%s="%s"\n' "$key" "${!key}"
            fi
        fi
    done
}

# --- Main parsing function --------------------------------------------------
parse_cli_args() {
    local args=("$@")
    
    # Parse arguments
    parse_bump_version_args "${args[@]}"
    
    # Export options for use by other modules
    export_parsed_options
    
    # Output options for sourcing
    output_parsed_options
}

# --- Standalone usage --------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize colors
    init_colors "${NO_COLOR:-false}"
    
    case "${1:-}" in
        "parse")
            shift
            parse_cli_args "$@"
            # Print parsed options for debugging
            for key in "${!DEFAULT_OPTIONS[@]}"; do
                printf '%s=%s\n' "$key" "${!key:-}"
            done
            ;;
        "validate")
            shift
            parse_cli_args "$@"
            success "CLI arguments are valid"
            ;;
        "help")
            show_usage
            ;;
        *)
            cat << EOF
Usage: $0 <command> [args...]

Commands:
  parse [args...]           Parse CLI arguments and export as environment variables
  validate [args...]        Validate CLI arguments
  help                      Show usage information

Examples:
  $0 parse patch --commit --tag
  $0 validate --set 1.0.0 --allow-prerelease
  $0 help
EOF
            exit 1
            ;;
    esac
fi 