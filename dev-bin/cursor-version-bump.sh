#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# cursor-version-bump: Interactive wrapper for mathematical-version-bump
# ------------------------------------------------------------
# Purpose:
# - Provide a friendly interactive menu for Cursor IDE users.
# - Delegate all real work to the mathematical-version-bump script.
#
# Behavior:
# - If arguments are given, forward them verbatim to mathematical-version-bump.
# - If no arguments are given, show a menu and build a simple command,
#   optionally appending extra args you type (e.g., --sign --push).
#
# It does NOT validate or reinterpret flags; mathematical-version-bump stays the single
# source of truth for versioning logic and options.

set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

# --------------- appearance ---------------
is_tty=0
[[ -t 1 ]] && is_tty=1

if (( is_tty )) && [[ -z "${NO_COLOR:-}" ]]; then
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    RED=$'\033[0;31m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    GREEN=''; YELLOW=''; CYAN=''; RED=''; BOLD=''; RESET=''
fi

info()  { printf '%s[*]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$YELLOW" "$RESET" "$*"; }
error() { printf '%s[x]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()   { error "$@"; exit 1; }

# --------------- locate project + VERSION ---------------
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Prefer Git repo root if available, else parent of script directory.
if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

VERSION_FILE="${PROJECT_ROOT}/VERSION"
[[ -f "$VERSION_FILE" ]] || die "VERSION file not found at: $VERSION_FILE"

# Trim whitespace newlines etc.
CURRENT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" || true)"

# --------------- version helpers ---------------
MAJOR='' MINOR='' PATCH=''

parse_version() {
    # Parse X.Y.Z into MAJOR MINOR PATCH (globals) — return 0 on success
    local v="$1"
    if [[ $v =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"
        return 0
    fi
    return 1
}

fmt_next_versions() {
    # Echo computed next versions or "N/A" if invalid.
    if parse_version "$CURRENT_VERSION"; then
        printf '%s' \
            "$((MAJOR)).$((MINOR)).$((PATCH+1))" \
            "$((MAJOR)).$((MINOR+1)).0" \
            "$((MAJOR+1)).0.0"
    else
        printf '%s' "N/A" "N/A" "N/A"
    fi
}

# --------------- locate mathematical-version-bump ---------------
# Optional override: export BUMP_VERSION_BIN=/custom/path/mathematical-version-bump
BUMP_VERSION_BIN="${BUMP_VERSION_BIN:-}"

resolve_bump_bin() {
    local cand
    if [[ -n "$BUMP_VERSION_BIN" && -x "$BUMP_VERSION_BIN" ]]; then
        printf '%s\n' "$BUMP_VERSION_BIN"; return
    fi
    # Try project dev-bin then script dev-bin
    for cand in \
            "$PROJECT_ROOT/dev-bin/mathematical-version-bump.sh" \
    "$SCRIPT_DIR/dev-bin/mathematical-version-bump.sh"
    do
        if [[ -x "$cand" ]]; then printf '%s\n' "$cand"; return; fi
    done
    if command -v mathematical-version-bump >/dev/null 2>&1; then
        command -v mathematical-version-bump; return
    fi
    die "Could not find 'mathematical-version-bump'. Set BUMP_VERSION_BIN or place it at \
'$PROJECT_ROOT/dev-bin/mathematical-version-bump.sh' (or in PATH)."
}

print_help() {
    cat <<'EOF'
cursor-version-bump — interactive wrapper for mathematical-version-bump

Usage:
  cursor-version-bump                # interactive menu (requires TTY)
  cursor-version-bump -- ...         # forward everything after -- to mathematical-version-bump
  cursor-version-bump [args...]      # forward args verbatim to mathematical-version-bump

Notes:
- This wrapper does not reinterpret flags. Whatever you pass goes to mathematical-version-bump.
- Interactive mode builds a simple command (major|minor|patch|auto|set X.Y.Z),
  then optionally appends any extra text you type (e.g., "--sign --push").
- For non-TTY (CI, scripts), pass arguments explicitly.

Env:
  BUMP_VERSION_BIN=/path/to/mathematical-version-bump  # optional override
  NO_COLOR=1                               # disable colored output
EOF
}

confirm() {
    local prompt="${1:-Proceed?} [y/N] "
    local ans=""
    read -r -p "${YELLOW}${prompt}${RESET}" ans || true
    case "$ans" in
        y|Y|yes|YES|Yes) return 0 ;;
        *)               return 1 ;;
    esac
}

interactive_menu() {
    (( is_tty )) || die "Interactive mode requires a TTY. Use arguments or --help."

    local p m j
    read -r p m j <<<"$(fmt_next_versions)"

    printf '%svglog-filter Version Bump Helper%s\n' "$CYAN" "$RESET"
    printf '%sCurrent version:%s %s%s%s\n\n' "$CYAN" "$RESET" "$GREEN" "$CURRENT_VERSION" "$RESET"

    echo "Select version bump type:"
    echo "1) Patch (bug fixes)       - $CURRENT_VERSION → $p"
    echo "2) Minor (new features)    - $CURRENT_VERSION → $m"
    echo "3) Major (breaking change) - $CURRENT_VERSION → $j"
            echo "4) Auto (let mathematical-version-bump decide)"
    echo "5) Set exact version (X.Y.Z)"
    echo "6) Cancel"
    echo ""

    local choice=""
    read -r -p "Enter choice (1-6): " choice || true

    local base_cmd=()
    case "$choice" in
        1)
            parse_version "$CURRENT_VERSION" || die "Cannot bump: invalid VERSION '$CURRENT_VERSION'. Use option 5 to set a valid X.Y.Z first."
            echo -e "${YELLOW}Bumping patch version...${RESET}"
            base_cmd=(patch)
            ;;
        2)
            parse_version "$CURRENT_VERSION" || die "Cannot bump: invalid VERSION '$CURRENT_VERSION'. Use option 5 to set a valid X.Y.Z first."
            echo -e "${YELLOW}Bumping minor version...${RESET}"
            base_cmd=(minor)
            ;;
        3)
            parse_version "$CURRENT_VERSION" || die "Cannot bump: invalid VERSION '$CURRENT_VERSION'. Use option 5 to set a valid X.Y.Z first."
            echo -e "${YELLOW}Bumping major version...${RESET}"
            base_cmd=(major)
            ;;
        4)
            echo -e "${YELLOW}Using auto detection...${RESET}"
            base_cmd=(auto)
            ;;
        5)
            local v=""
            read -r -p "Enter version (X.Y.Z): " v || true
            [[ -n "$v" ]] || die "Empty version."
            [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid version format: '$v' (expected X.Y.Z)."
            base_cmd=(set "$v")
            ;;
        6)
            warn "Cancelled."
            exit 0
            ;;
        *)
            die "Invalid choice."
            ;;
    esac

    echo ""
            echo "Optionally type extra args for mathematical-version-bump (or press Enter):"
        echo "  e.g., --commit --tag --sign --push   (or any flags your mathematical-version-bump supports)"
    local extra=""
    read -r -p "Extra args: " extra || true

    # Build final argv: base_cmd + extra (intentional word splitting for user input)
    local final_cmd=( "${base_cmd[@]}" )
    if [[ -n "$extra" ]]; then
        # shellcheck disable=SC2086,SC2206 # allow user-intended word splitting/quotes
        final_cmd=( "${final_cmd[@]}" $extra )
    fi

    echo ""
    printf 'Will run: %smathematical-version-bump %s%s\n' "$BOLD" "${final_cmd[*]}" "$RESET"
    if confirm "Run now?"; then
        local bin; bin="$(resolve_bump_bin)"
        exec "$bin" "${final_cmd[@]}"
    else
        warn "Cancelled."
        exit 0
    fi
}

main() {
    case "${1:-}" in
        -h|--help) print_help; exit 0 ;;
        *) : ;;
    esac

    local bin; bin="$(resolve_bump_bin)"

    # With args:
    # - If the first arg is "--", drop it and forward the rest verbatim.
    # - Otherwise, forward all args verbatim (no changes).
    if (( $# > 0 )); then
        if [[ "${1:-}" == "--" ]]; then
            shift || true
        fi
        exec "$bin" "$@"
    fi

    # No args => interactive
    interactive_menu
}

main "$@"
