#!/usr/bin/env bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# CLI Options Analyzer
# Detects and analyzes CLI option changes in C/C++ source files

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Prevent any pager and avoid unnecessary repo locks for better performance.
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=0

# --- utils -------------------------------------------------------------------

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
note() { :; } # overwritten by --verbose
json_escape() { # naive escape for simple strings
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

trim_spaces() {
  # trim leading/trailing ASCII and Unicode spaces
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

join_by() { local IFS="$1"; shift; printf '%s' "$*"; }

have_git() { command -v git >/dev/null 2>&1; }

# comm requires sorted input
set_diff_counts() {
  # args: before_list after_list; outputs: REM= count, ADD= count to named vars
  local before="$1" after="$2" _rem _add
  _rem=$(comm -23 <(printf '%s\n' "$before" | LC_ALL=C sort -u) <(printf '%s\n' "$after" | LC_ALL=C sort -u) | wc -l | tr -d ' ')
  _add=$(comm -13 <(printf '%s\n' "$before" | LC_ALL=C sort -u) <(printf '%s\n' "$after" | LC_ALL=C sort -u) | wc -l | tr -d ' ')
  printf '%s %s\n' "$_rem" "$_add"
}

# --- help --------------------------------------------------------------------

show_help() {
    cat << EOF
CLI Options Analyzer

Usage: $(basename "$0") [options]

Options:
  --base <ref>             Base reference for comparison (required)
  --target <ref>           Target reference for comparison (default: HEAD)
  --repo-root <path>       Set repository root directory
  --only-paths <globs>     Comma-separated glob pathspecs (git-style). Example:
                           ":(glob)src/**,:(glob)include/**"
  --ignore-whitespace      Ignore whitespace changes in diff analysis
  --machine                Output machine-readable key=value format
  --json                   Output machine-readable JSON
  --fail-on-breaking       Exit with code 2 if breaking CLI/API detected
  --verbose                Print progress to stderr
  --help, -h               Show this help

Examples:
  $(basename "$0") --base v1.0.0 --target HEAD
  $(basename "$0") --base HEAD~5 --target HEAD --machine
  $(basename "$0") --base v1.0.0 --target v1.1.0 --json
EOF
}

# --- args --------------------------------------------------------------------

BASE_REF=""
TARGET_REF="HEAD"
REPO_ROOT=""
ONLY_PATHS=""
IGNORE_WHITESPACE=false
MACHINE_OUTPUT=false
JSON_OUTPUT=false
FAIL_ON_BREAKING=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --base)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--base requires a value"
            BASE_REF="$2"; shift 2;;
        --target)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--target requires a value"
            TARGET_REF="$2"; shift 2;;
        --repo-root)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--repo-root requires a value"
            REPO_ROOT="$2"; shift 2;;
        --only-paths)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--only-paths requires a comma-separated globs list"
            ONLY_PATHS="$2"; shift 2;;
        --ignore-whitespace) IGNORE_WHITESPACE=true; shift;;
        --machine) MACHINE_OUTPUT=true; shift;;
        --json) JSON_OUTPUT=true; shift;;
        --fail-on-breaking) FAIL_ON_BREAKING=true; shift;;
        --verbose) VERBOSE=true; shift;;
        --help|-h) show_help; exit 0;;
        *) show_help; die "Unknown option: $1";;
    esac
done

$VERBOSE && note() { printf '[cli-analyzer] %s\n' "$*" >&2; }

[[ -n "$BASE_REF" ]] || die "--base is required"
have_git || die "git command not found"

# Change to repo root if specified
if [[ -n "$REPO_ROOT" ]]; then
  cd "$REPO_ROOT" || die "Cannot cd into $REPO_ROOT"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not in a git repository at $REPO_ROOT"
fi

# --- pathspecs ---------------------------------------------------------------

declare -a PATHSPEC
if [[ -n "$ONLY_PATHS" ]]; then
  IFS=',' read -r -a _paths <<< "$ONLY_PATHS"
  for p in "${!_paths[@]}"; do
    _paths[p]=$(trim_spaces "${_paths[$p]}")
  done
  # pass through verbatim; caller can use :(glob) or plain
  for p in "${_paths[@]}"; do [[ -n "$p" ]] && PATHSPEC+=("$p"); done
else
  # default: common recursive C/C++ sources and headers
  PATHSPEC+=(":(glob)**/*.c" ":(glob)**/*.cc" ":(glob)**/*.cpp" ":(glob)**/*.cxx")
  PATHSPEC+=(":(glob)**/*.h" ":(glob)**/*.hh" ":(glob)**/*.hpp")
fi

# --- diff flags --------------------------------------------------------------

DIFF_FLAGS=(-M -C --unified=0)
$IGNORE_WHITESPACE && DIFF_FLAGS+=(-w)

# Validate git references
verify_ref() {
    local ref="$1"
    git -c color.ui=false rev-parse -q --verify "$ref^{commit}" >/dev/null || die "Invalid reference: $ref"
}

verify_ref "$BASE_REF"
verify_ref "$TARGET_REF"

# --- gather changes ----------------------------------------------------------

note "Collecting changed files…"
# Use -z to be robust to spaces/newlines; include renames/copies.
mapfile -d '' CHANGED_FILES < <(git -c color.ui=false -c core.quotepath=false diff -z -M -C --name-only "$BASE_REF".."$TARGET_REF" -- "${PATHSPEC[@]}" || true)

if (( ${#CHANGED_FILES[@]} == 0 )); then
  # no relevant files changed → consistent zero output
  if $JSON_OUTPUT; then
    printf '%s\n' '{ "cli_changes": false, "breaking_cli_changes": false, "api_breaking": false, "manual_cli_changes": false, "manual_added_long_count": 0, "manual_removed_long_count": 0, "removed_short_count": 0, "added_short_count": 0, "removed_long_count": 0, "added_long_count": 0, "getopt_changes": 0, "arg_parsing_changes": 0, "help_text_changes": 0, "main_signature_changes": 0, "enhanced_cli_patterns": 0, "removed_short_list": [], "added_short_list": [], "removed_long_list": [], "added_long_list": [] }'
  elif $MACHINE_OUTPUT; then
    cat <<EOF
CLI_CHANGES=false
BREAKING_CLI_CHANGES=false
API_BREAKING=false
MANUAL_CLI_CHANGES=false
MANUAL_ADDED_LONG_COUNT=0
MANUAL_REMOVED_LONG_COUNT=0
REMOVED_SHORT_COUNT=0
ADDED_SHORT_COUNT=0
REMOVED_LONG_COUNT=0
ADDED_LONG_COUNT=0
EOF
  else
    printf '=== CLI Options Analysis ===\nNo relevant source/header changes between %s..%s\n' "$BASE_REF" "$TARGET_REF"
  fi
  exit 0
fi

# Pre-fetch contents (avoid repeated git show)
declare -A BEFORE AFTER
for f in "${CHANGED_FILES[@]}"; do
  BEFORE["$f"]=$(git -c color.ui=false show "$BASE_REF:$f" 2>/dev/null || true)
  AFTER["$f"]=$(git -c color.ui=false show "$TARGET_REF:$f" 2>/dev/null || true)
done

# Combined diffs (once)
note "Computing diffs…"
SRC_DIFF=$(git -c color.ui=false diff "${DIFF_FLAGS[@]}" "$BASE_REF".."$TARGET_REF" -- "${CHANGED_FILES[@]}" || true)
CPP_DIFF=$(git -c color.ui=false diff "${DIFF_FLAGS[@]}" "$BASE_REF".."$TARGET_REF" -- "${PATHSPEC[@]}" || true)

# --- extract option sets -----------------------------------------------------

short_before_all="" ; short_after_all=""
long_before_all=""  ; long_after_all=""

for f in "${CHANGED_FILES[@]}"; do
  # Extract optstrings from getopt()/getopt_long() calls: "abc:d:"
  short_before_all+=$(printf '%s' "${BEFORE[$f]}" | grep -E 'getopt(_long)?\s*\(' -a || true | grep -o '"[^"]*"' -a | tr -d '"' || true)
  short_after_all+=$(printf '%s' "${AFTER[$f]}"  | grep -E 'getopt(_long)?\s*\(' -a || true | grep -o '"[^"]*"' -a | tr -d '"' || true)

  # Extract long options from struct option arrays: { "name", …
  long_before_all+=$(printf '%s' "${BEFORE[$f]}" | awk '/struct[[:space:]]+option/,/};/' | grep -o '"[^"]\+"' -a | tr -d '"' | tr '\n' ',' || true)
  long_after_all+=$(printf '%s' "${AFTER[$f]}"  | awk '/struct[[:space:]]+option/,/};/' | grep -o '"[^"]\+"' -a | tr -d '"' | tr '\n' ',' || true)
done

short_before=$(printf '%s' "$short_before_all" | LC_ALL=C sort -u | tr -d '\n')
short_after=$( printf '%s' "$short_after_all"  | LC_ALL=C sort -u | tr -d '\n')

long_before=$( printf '%s' "$long_before_all" | tr ',' '\n' | sed '/^$/d' | LC_ALL=C sort -u | tr '\n' ',' | sed 's/,$//')
long_after=$(  printf '%s' "$long_after_all"  | tr ',' '\n' | sed '/^$/d' | LC_ALL=C sort -u | tr '\n' ',' | sed 's/,$//')

# Build lists for diff
short_before_list=$(printf '%s' "$short_before" | tr -d ':' | fold -w1 | sed '/^$/d' | LC_ALL=C sort -u)
short_after_list=$( printf '%s' "$short_after"  | tr -d ':' | fold -w1 | sed '/^$/d' | LC_ALL=C sort -u)
long_before_list=$(  printf '%s' "$long_before" | tr ',' '\n' | sed '/^$/d' | LC_ALL=C sort -u)
long_after_list=$(   printf '%s' "$long_after"  | tr ',' '\n' | sed '/^$/d' | LC_ALL=C sort -u)

# Compute removed/added lists
removed_short_list=$(comm -23 <(printf '%s\n' "$short_before_list") <(printf '%s\n' "$short_after_list") || true)
added_short_list=$(  comm -13 <(printf '%s\n' "$short_before_list") <(printf '%s\n' "$short_after_list") || true)
removed_long_list=$( comm -23 <(printf '%s\n' "$long_before_list")  <(printf '%s\n' "$long_after_list")  || true)
added_long_list=$(   comm -13 <(printf '%s\n' "$long_before_list")  <(printf '%s\n' "$long_after_list")  || true)

# Counts
read -r removed_short_count added_short_count < <(set_diff_counts "$short_before_list" "$short_after_list")
read -r removed_long_count  added_long_count  < <(set_diff_counts "$long_before_list"  "$long_after_list")

# --- raw diff heuristics -----------------------------------------------------

removed_cases=$(printf '%s' "$SRC_DIFF" | grep -E '^-+[[:space:]]*case[[:space:]]' -a | sed 's/^-[[:space:]]*case[[:space:]]*//' | LC_ALL=C sort -u || true)
added_cases=$(  printf '%s' "$SRC_DIFF" | grep -E '^\++[[:space:]]*case[[:space:]]' -a | sed 's/^\+[[:space:]]*case[[:space:]]*//' | LC_ALL=C sort -u || true)
missing_cases=$(comm -23 <(printf '%s\n' "$removed_cases") <(printf '%s\n' "$added_cases") || true)
breaking_cli_changes=false
[[ -n "$missing_cases" ]] && breaking_cli_changes=true

# Header API change hint (removed prototypes)
header_diff=$(git -c color.ui=false diff "${DIFF_FLAGS[@]}" "$BASE_REF".."$TARGET_REF" -- \
  ":(glob)**/*.h" ":(glob)**/*.hh" ":(glob)**/*.hpp" 2>/dev/null || true)
removed_prototypes=$(printf '%s' "$header_diff" | awk '/^-[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/ && /\);[[:space:]]*$/ && !/^-[[:space:]]*(typedef|#)/' | wc -l | tr -d ' ' || printf '0')
api_breaking=false
(( removed_prototypes > 0 )) && api_breaking=true

# Manual/heuristic long option detection limited to C/C++
added_long_opts=$(printf '%s' "$CPP_DIFF" | awk '/^\+.*--[a-zA-Z0-9-]+/ && !/^\+.*["\x27].*--[a-zA-Z0-9-]+/ { if (match($0, /--([a-zA-Z0-9-]+)/, a)) print "--" a[1] }' | LC_ALL=C sort -u || true)
removed_long_opts=$(printf '%s' "$CPP_DIFF" | awk '/^-.*--[a-zA-Z0-9-]+/ && !/^-.*["\x27].*--[a-zA-Z0-9-]+/ { if (match($0, /--([a-zA-Z0-9-]+)/, a)) print "--" a[1] }' | LC_ALL=C sort -u || true)
manual_added_long_count=$(printf '%s\n' "$added_long_opts" | sed '/^$/d' | wc -l | tr -d ' ' || printf '0')
manual_removed_long_count=$(printf '%s\n' "$removed_long_opts" | sed '/^$/d' | wc -l | tr -d ' ' || printf '0')
manual_cli_changes=false
(( manual_added_long_count > 0 || manual_removed_long_count > 0 )) && manual_cli_changes=true

getopt_changes=$(printf '%s' "$CPP_DIFF" | grep -c -E '(getopt_long|getopt)' -a || printf '0')
arg_parsing_changes=$(printf '%s' "$CPP_DIFF" | awk '/^\+[[:space:]]*if[[:space:]]*\([[:space:]]*argc|^\+[[:space:]]*while[[:space:]]*\([[:space:]]*argc|^\+[[:space:]]*for[[:space:]]*\([[:space:]]*argc|^\+[[:space:]]*switch[[:space:]]*\([[:space:]]*argv/ {print}' | wc -l | tr -d ' ' || printf '0')
help_text_changes=$(printf '%s' "$CPP_DIFF" | grep -i -c -E '(^\+.*(usage|help|option|argument))' -a || printf '0')
main_signature_changes=$(printf '%s' "$CPP_DIFF" | awk '/^\+[[:space:]]*int[[:space:]]+main[[:space:]]*\(/ {print}' | wc -l | tr -d ' ' || printf '0')

enhanced_cli_patterns=$(printf '%s' "$CPP_DIFF" | awk '
  /^\+[[:space:]]*[^/#!].*-[[:alpha:]]/ {print "short_option_change"}
  /^\+[[:space:]]*[^/#!].*--[[:alnum:]-]+/ {print "long_option_change"}
  /^\+[[:space:]]*.*argc[[:space:]]*[<>=!]/ {print "argc_check_change"}
  /^\+[[:space:]]*.*argv\[/ {print "argv_access_change"}
' | LC_ALL=C sort -u | wc -l | tr -d ' ' || printf '0')

# Composite CLI change flags
cli_changes=false
if [[ -n "$short_after" && "$short_after" != "$short_before" ]]; then
  cli_changes=true
  [[ -n "$removed_short_list" ]] && breaking_cli_changes=true
fi
if [[ -n "$long_after" && "$long_after" != "$long_before" ]]; then
  cli_changes=true
  [[ -n "$removed_long_list" ]] && breaking_cli_changes=true
fi
(( getopt_changes + arg_parsing_changes + help_text_changes + main_signature_changes + enhanced_cli_patterns > 0 )) && manual_cli_changes=true

# --- output ------------------------------------------------------------------

if $JSON_OUTPUT; then
  printf '{\n'
  printf '  "cli_changes": %s,\n' "$($cli_changes && echo true || echo false)"
  printf '  "breaking_cli_changes": %s,\n' "$($breaking_cli_changes && echo true || echo false)"
  printf '  "api_breaking": %s,\n' "$($api_breaking && echo true || echo false)"
  printf '  "manual_cli_changes": %s,\n' "$($manual_cli_changes && echo true || echo false)"
  printf '  "manual_added_long_count": %d,\n' "$manual_added_long_count"
  printf '  "manual_removed_long_count": %d,\n' "$manual_removed_long_count"
  printf '  "removed_short_count": %d,\n' "$removed_short_count"
  printf '  "added_short_count": %d,\n' "$added_short_count"
  printf '  "removed_long_count": %d,\n' "$removed_long_count"
  printf '  "added_long_count": %d,\n' "$added_long_count"
  printf '  "getopt_changes": %d,\n' "$getopt_changes"
  printf '  "arg_parsing_changes": %d,\n' "$arg_parsing_changes"
  printf '  "help_text_changes": %d,\n' "$help_text_changes"
  printf '  "main_signature_changes": %d,\n' "$main_signature_changes"
  printf '  "enhanced_cli_patterns": %d,\n' "$enhanced_cli_patterns"

  # Lists as arrays
  printf '  "removed_short_list": ['
  first=true; for s in $removed_short_list; do
    $first || printf ', '; first=false; printf '"%s"' "$(json_escape "$s")"
  done; printf '],\n'

  printf '  "added_short_list": ['
  first=true; for s in $added_short_list; do
    $first || printf ', '; first=false; printf '"%s"' "$(json_escape "$s")"
  done; printf '],\n'

  printf '  "removed_long_list": ['
  first=true; while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    $first || printf ', '; first=false; printf '"%s"' "$(json_escape "$s")"
  done <<< "$removed_long_list"; printf '],\n'

  printf '  "added_long_list": ['
  first=true; while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    $first || printf ', '; first=false; printf '"%s"' "$(json_escape "$s")"
  done <<< "$added_long_list"; printf ']\n'
  printf '}\n'

elif $MACHINE_OUTPUT; then
  cat <<EOF
CLI_CHANGES=$($cli_changes && echo true || echo false)
BREAKING_CLI_CHANGES=$($breaking_cli_changes && echo true || echo false)
API_BREAKING=$($api_breaking && echo true || echo false)
MANUAL_CLI_CHANGES=$($manual_cli_changes && echo true || echo false)
MANUAL_ADDED_LONG_COUNT=$manual_added_long_count
MANUAL_REMOVED_LONG_COUNT=$manual_removed_long_count
REMOVED_SHORT_COUNT=$removed_short_count
ADDED_SHORT_COUNT=$added_short_count
REMOVED_LONG_COUNT=$removed_long_count
ADDED_LONG_COUNT=$added_long_count
GETOPT_CHANGES=$getopt_changes
ARG_PARSING_CHANGES=$arg_parsing_changes
HELP_TEXT_CHANGES=$help_text_changes
MAIN_SIGNATURE_CHANGES=$main_signature_changes
ENHANCED_CLI_PATTERNS=$enhanced_cli_patterns
EOF

else
    printf '=== CLI Options Analysis ===\n'
    printf 'Base reference:   %s\n' "$BASE_REF"
    printf 'Target reference: %s\n' "$TARGET_REF"
    printf '\nCLI Changes:\n'
    printf '  CLI interface changes: %s\n' "$($cli_changes && echo true || echo false)"
    printf '  Breaking CLI changes:  %s\n' "$($breaking_cli_changes && echo true || echo false)"
    printf '  Manual CLI changes:    %s\n' "$($manual_cli_changes && echo true || echo false)"
    printf '  API breaking changes:  %s\n' "$($api_breaking && echo true || echo false)"
    printf '\nOption Counts:\n'
    printf '  Removed short options: %d\n' "$removed_short_count"
    printf '  Added short options:   %d\n' "$added_short_count"
    printf '  Removed long options:  %d\n' "$removed_long_count"
    printf '  Added long options:    %d\n' "$added_long_count"
    printf '  Manual added long:     %d\n' "$manual_added_long_count"
    printf '  Manual removed long:   %d\n' "$manual_removed_long_count"
    if [[ -n "$removed_short_list$added_short_list$removed_long_list$added_long_list" ]]; then
        printf '\nOption Lists:\n'
        [[ -n "$removed_short_list" ]] && printf '  - Removed short: %s\n' "$(join_by ' ' "$removed_short_list")"
        [[ -n "$added_short_list"   ]] && printf '  - Added short:   %s\n' "$(join_by ' ' "$added_short_list")"
        [[ -n "$removed_long_list"  ]] && printf '  - Removed long:  %s\n' "$(echo "$removed_long_list" | paste -sd' ' -)"
        [[ -n "$added_long_list"    ]] && printf '  - Added long:    %s\n' "$(echo "$added_long_list" | paste -sd' ' -)"
    fi
    printf '\nPattern Analysis:\n'
    printf '  getopt changes:         %d\n' "$getopt_changes"
    printf '  argument parsing diff:  %d\n' "$arg_parsing_changes"
    printf '  help/usage text diff:   %d\n' "$help_text_changes"
    printf '  main signature changes: %d\n' "$main_signature_changes"
    printf '  enhanced CLI patterns:  %d\n' "$enhanced_cli_patterns"
fi

# --- exit policy -------------------------------------------------------------

if $FAIL_ON_BREAKING && { $breaking_cli_changes || $api_breaking; }; then
  note "Failing due to breaking changes (--fail-on-breaking)"
  exit 2
fi
