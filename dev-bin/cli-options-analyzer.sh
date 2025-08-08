#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# CLI options analyzer for vglog-filter
# Analyzes CLI/API breaking changes in git diffs

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/version-utils.sh"

# Initialize colors
init_colors

# --- utils -------------------------------------------------------------------

# die() function is now sourced from version-utils.sh
note() { :; } # overwritten by --verbose

boolstr() { [[ "$1" == true ]] && printf 'true' || printf 'false'; }

# json_escape() function is now sourced from version-utils.sh

trim_spaces() {
  # trim leading/trailing ASCII and Unicode spaces
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

one_line() {  # turn a newline-separated list into space-separated one line
  paste -sd' ' -
}

join_by() { local IFS="$1"; shift; printf '%s' "$*"; }

# require_cmd() function is now sourced from version-utils.sh

have_git() { command -v git >/dev/null 2>&1; }

verify_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repository"
}

# verify_ref() function is now sourced from version-utils.sh

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
require_cmd
have_git || die "git command not found"

# Change to repo root if specified
if [[ -n "$REPO_ROOT" ]]; then
  cd "$REPO_ROOT" || die "Cannot cd into $REPO_ROOT"
fi
verify_git_repo
verify_ref "$BASE_REF"
verify_ref "$TARGET_REF"

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



# --- extraction functions ----------------------------------------------------

# Parse short options from getopt()/getopt_long() call sites.
extract_short_opts() {
  # Concatenate optstrings found in quotes in getopt calls, then uniq.
  grep -Ea 'getopt(_long)?[[:space:]]*\(' -a \
  | grep -Eo '"[^"]*"' -a \
  | tr -d '"' \
  | LC_ALL=C sort -u \
  | tr -d '\n'
}

# Parse long options from struct option arrays:
#  - classic initializer: { "name", has_arg, flag, val }
#  - designated initializer: { .name = "name", ... }
extract_long_opts() {
  awk '
    /struct[[:space:]]+option/ { inblk=1 }
    inblk && /};/             { inblk=0 }
    inblk {
      # capture first quoted token inside braces
      if (match($0, /{\s*"([^"]+)"/, a)) print a[1];
      # capture designated initializer .name = "xxx"
      if (match($0, /\.name[[:space:]]*=[[:space:]]*"([^"]+)"/, b)) print b[1];
    }
  ' \
  | sed '/^$/d' \
  | LC_ALL=C sort -u \
  | paste -sd',' -
}

# Count removed prototypes in headers as API break indicator.
count_removed_prototypes() {
  awk '
    # minus lines only (handle line numbers from grep -n)
    /^[0-9]+:-/ || /^-/ {
      # crude prototype detector: ret name(args);
      if ($0 !~ /^[0-9]*:-[[:space:]]*(typedef|#)/ && $0 !~ /^-[[:space:]]*(typedef|#)/ &&
          ($0 ~ /^[0-9]*:-[[:space:]]*[A-Za-z_][A-Za-z0-9_[:space:]\*]+[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\([^;]*\)[[:space:]]*;[[:space:]]*$/ ||
           $0 ~ /^-[[:space:]]*[A-Za-z_][A-Za-z0-9_[:space:]\*]+[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\([^;]*\)[[:space:]]*;[[:space:]]*$/))
        print
    }
  ' | wc -l | tr -d ' '
}

# Manual diff-based long option detection on added/removed lines (avoid strings/comments roughly).
scan_manual_long_opts() {
  local sign="$1" # '+' or '-'
  awk -v s="$sign" '
    $0 ~ ("^" s) {
      line=$0
      # skip obvious comments and quoted strings (naive)
      if (line ~ /(^[+-]\s*\/\/)|(^[+-]\s*\/\*)|(^[+-].*["'\''].*--)/) next
      if (match(line, /--([A-Za-z0-9-]+)/, m)) print "--" m[1]
    }
  ' | LC_ALL=C sort -u
}

# Switch-case removed vs added (roughly ignore comments)
scan_case_labels() {
  local sign="$1" # '+' or '-'
  awk -v s="$sign" '
    $0 ~ ("^" s) {
      line=$0
      if (line ~ /(^[+-]\s*\/\/)|(^[+-]\s*\/\*)/) next
      if (match(line, /case[[:space:]]+([^:[:space:]]+)[[:space:]]*:/, m)) print m[1]
    }
  ' | LC_ALL=C sort -u
}

# --- output functions --------------------------------------------------------

emit_results_zero() {
  note "No relevant source/header changes"
  if $JSON_OUTPUT; then
    cat <<'JSON'
{
  "cli_changes": false,
  "breaking_cli_changes": false,
  "api_breaking": false,
  "manual_cli_changes": false,
  "manual_added_long_count": 0,
  "manual_removed_long_count": 0,
  "removed_short_count": 0,
  "added_short_count": 0,
  "removed_long_count": 0,
  "added_long_count": 0,
  "getopt_changes": 0,
  "arg_parsing_changes": 0,
  "help_text_changes": 0,
  "main_signature_changes": 0,
  "enhanced_cli_patterns": 0,
  "removed_short_list": [],
  "added_short_list": [],
  "removed_long_list": [],
  "added_long_list": []
}
JSON
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
GETOPT_CHANGES=0
ARG_PARSING_CHANGES=0
HELP_TEXT_CHANGES=0
MAIN_SIGNATURE_CHANGES=0
ENHANCED_CLI_PATTERNS=0
EOF
  else
    printf '=== CLI Options Analysis ===\nNo relevant source/header changes between %s..%s\n' "$BASE_REF" "$TARGET_REF"
  fi
}

# --- gather changes ----------------------------------------------------------

note "Collecting changed files…"
# Use -z to be robust to spaces/newlines; include renames/copies.
mapfile -d '' CHANGED_FILES < <(git -c color.ui=false -c core.quotepath=false diff -z -M -C --name-only "$BASE_REF".."$TARGET_REF" -- "${PATHSPEC[@]}" || true)

if (( ${#CHANGED_FILES[@]} == 0 )); then
  emit_results_zero
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

# Header-only diff subset for API analysis
HDR_DIFF=$(printf '%s' "$SRC_DIFF" | grep -E '^\+|^-|^diff --git|^index|^@@|/.*\.(h|hh|hpp)$' -n --color=never | sed -n 'p' || true)

# --- extract option sets -----------------------------------------------------

short_before_all="" ; short_after_all=""
long_before_all=""  ; long_after_all=""

for f in "${CHANGED_FILES[@]}"; do
  # Extract optstrings from getopt()/getopt_long() calls: "abc:d:"
  short_before_all+=$(printf '%s' "${BEFORE[$f]}" | extract_short_opts || true)
  short_after_all+=$(printf '%s' "${AFTER[$f]}"  | extract_short_opts || true)

  # Extract long options from struct option arrays: { "name", …
  long_before_all+=$(printf '%s' "${BEFORE[$f]}" | extract_long_opts || true)
  long_after_all+=$(printf '%s' "${AFTER[$f]}"  | extract_long_opts || true)
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
removed_short_count=$(printf '%s' "$removed_short_count" | tr -d ' ')
added_short_count=$(printf '%s' "$added_short_count" | tr -d ' ')
read -r removed_long_count  added_long_count  < <(set_diff_counts "$long_before_list"  "$long_after_list")
removed_long_count=$(printf '%s' "$removed_long_count" | tr -d ' ')
added_long_count=$(printf '%s' "$added_long_count" | tr -d ' ')

# --- raw diff heuristics -----------------------------------------------------

removed_cases=$(printf '%s' "$SRC_DIFF" | scan_case_labels '-')
added_cases=$(  printf '%s' "$SRC_DIFF" | scan_case_labels '+')
missing_cases=$(comm -23 <(printf '%s\n' "$removed_cases") <(printf '%s\n' "$added_cases") || true)
breaking_cli_changes=false
[[ -n "$missing_cases" ]] && breaking_cli_changes=true

# Header API change hint (removed prototypes)
removed_prototypes=$(printf '%s' "$HDR_DIFF" | count_removed_prototypes || printf '0')
api_breaking=false
(( removed_prototypes > 0 )) && api_breaking=true

# Debug: Show HDR_DIFF content (only in verbose mode)
$VERBOSE && note "Debug: removed_prototypes count: $removed_prototypes"

# Manual/heuristic long option detection limited to C/C++
added_long_opts=$(printf '%s' "$CPP_DIFF" | scan_manual_long_opts '+')
removed_long_opts=$(printf '%s' "$CPP_DIFF" | scan_manual_long_opts '-')
manual_added_long_count=$(printf '%s\n' "$added_long_opts" | sed '/^$/d' | wc -l | tr -d ' ' || printf '0')
manual_removed_long_count=$(printf '%s\n' "$removed_long_opts" | sed '/^$/d' | wc -l | tr -d ' ' || printf '0')
manual_cli_changes=false
(( manual_added_long_count > 0 || manual_removed_long_count > 0 )) && manual_cli_changes=true

getopt_changes=$(printf '%s' "$CPP_DIFF" | grep -c -E '(getopt_long|getopt)\s*\(' -a || printf '0')
arg_parsing_changes=$(printf '%s' "$CPP_DIFF" | grep -c -E '^\+.*\b(argc|argv)\b' -a || printf '0')
help_text_changes=$(printf '%s' "$CPP_DIFF" | grep -i -c -E '^\+.*\b(usage|help|option|argument)\b' -a || printf '0')
main_signature_changes=$(printf '%s' "$CPP_DIFF" | grep -c -E '^\+[^/]*\bint[[:space:]]+main[[:space:]]*\(' -a || printf '0')

enhanced_cli_patterns=$(printf '%s' "$CPP_DIFF" | awk '
  /^\+[^/#!].*-[[:alpha:]]/       {print "short_option_change"}
  /^\+[^/#!].*--[[:alnum:]-]+/    {print "long_option_change"}
  /^\+.*\bargc[[:space:]]*[<>=!]/ {print "argc_check_change"}
  /^\+.*\bargv\[/                 {print "argv_access_change"}
' | LC_ALL=C sort -u | wc -l | tr -d ' ' || printf '0')

# Ensure all variables are numeric for arithmetic expression
getopt_changes=${getopt_changes:-0}
arg_parsing_changes=${arg_parsing_changes:-0}
help_text_changes=${help_text_changes:-0}
main_signature_changes=${main_signature_changes:-0}
enhanced_cli_patterns=${enhanced_cli_patterns:-0}

# Ensure count variables are numeric for printf statements
removed_short_count=${removed_short_count:-0}
added_short_count=${added_short_count:-0}
removed_long_count=${removed_long_count:-0}
added_long_count=${added_long_count:-0}
manual_added_long_count=${manual_added_long_count:-0}
manual_removed_long_count=${manual_removed_long_count:-0}

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

# Use a more robust method for the arithmetic expression
total_patterns=0
[[ "$getopt_changes" =~ ^[0-9]+$ ]] && total_patterns=$((total_patterns + getopt_changes))
[[ "$arg_parsing_changes" =~ ^[0-9]+$ ]] && total_patterns=$((total_patterns + arg_parsing_changes))
[[ "$help_text_changes" =~ ^[0-9]+$ ]] && total_patterns=$((total_patterns + help_text_changes))
[[ "$main_signature_changes" =~ ^[0-9]+$ ]] && total_patterns=$((total_patterns + main_signature_changes))
[[ "$enhanced_cli_patterns" =~ ^[0-9]+$ ]] && total_patterns=$((total_patterns + enhanced_cli_patterns))
(( total_patterns > 0 )) && manual_cli_changes=true

# --- output functions --------------------------------------------------------

emit_results_zero() {
  note "No relevant source/header changes"
  if $JSON_OUTPUT; then
    cat <<'JSON'
{
  "cli_changes": false,
  "breaking_cli_changes": false,
  "api_breaking": false,
  "manual_cli_changes": false,
  "manual_added_long_count": 0,
  "manual_removed_long_count": 0,
  "removed_short_count": 0,
  "added_short_count": 0,
  "removed_long_count": 0,
  "added_long_count": 0,
  "getopt_changes": 0,
  "arg_parsing_changes": 0,
  "help_text_changes": 0,
  "main_signature_changes": 0,
  "enhanced_cli_patterns": 0,
  "removed_short_list": [],
  "added_short_list": [],
  "removed_long_list": [],
  "added_long_list": []
}
JSON
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
GETOPT_CHANGES=0
ARG_PARSING_CHANGES=0
HELP_TEXT_CHANGES=0
MAIN_SIGNATURE_CHANGES=0
ENHANCED_CLI_PATTERNS=0
EOF
  else
    printf '=== CLI Options Analysis ===\nNo relevant source/header changes between %s..%s\n' "$BASE_REF" "$TARGET_REF"
  fi
}

emit_json() {
  printf '{\n'
  printf '  "cli_changes": %s,\n' "$(boolstr "$cli_changes")"
  printf '  "breaking_cli_changes": %s,\n' "$(boolstr "$breaking_cli_changes")"
  printf '  "api_breaking": %s,\n' "$(boolstr "$api_breaking")"
  printf '  "manual_cli_changes": %s,\n' "$(boolstr "$manual_cli_changes")"
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
}

emit_machine() {
  cat <<EOF
CLI_CHANGES=$(boolstr "$cli_changes")
BREAKING_CLI_CHANGES=$(boolstr "$breaking_cli_changes")
API_BREAKING=$(boolstr "$api_breaking")
MANUAL_CLI_CHANGES=$(boolstr "$manual_cli_changes")
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
}

emit_human() {
    printf '=== CLI Options Analysis ===\n'
    printf 'Base reference:   %s\n' "$BASE_REF"
    printf 'Target reference: %s\n' "$TARGET_REF"
    printf '\nCLI Changes:\n'
    printf '  CLI interface changes: %s\n' "$(boolstr "$cli_changes")"
    printf '  Breaking CLI changes:  %s\n' "$(boolstr "$breaking_cli_changes")"
    printf '  Manual CLI changes:    %s\n' "$(boolstr "$manual_cli_changes")"
    printf '  API breaking changes:  %s\n' "$(boolstr "$api_breaking")"
    printf '\nOption Counts:\n'
    printf '  Removed short options: %d\n' "$removed_short_count"
    printf '  Added short options:   %d\n' "$added_short_count"
    printf '  Removed long options:  %d\n' "$removed_long_count"
    printf '  Added long options:    %d\n' "$added_long_count"
    printf '  Manual added long:     %d\n' "$manual_added_long_count"
    printf '  Manual removed long:   %d\n' "$manual_removed_long_count"
    if [[ -n "$removed_short_list$added_short_list$removed_long_list$added_long_list" ]]; then
        printf '\nOption Lists:\n'
        [[ -n "$removed_short_list" ]] && { printf '  - Removed short: '; printf '%s\n' "$(printf '%s\n' "$removed_short_list" | one_line)"; }
        [[ -n "$added_short_list"   ]] && { printf '  - Added short:   '; printf '%s\n' "$(printf '%s\n' "$added_short_list" | one_line)"; }
        [[ -n "$removed_long_list"  ]] && { printf '  - Removed long:  '; printf '%s\n' "$(printf '%s\n' "$removed_long_list" | one_line)"; }
        [[ -n "$added_long_list"    ]] && { printf '  - Added long:    '; printf '%s\n' "$(printf '%s\n' "$added_long_list" | one_line)"; }
    fi
    printf '\nPattern Analysis:\n'
    printf '  getopt changes:         %d\n' "$getopt_changes"
    printf '  argument parsing diff:  %d\n' "$arg_parsing_changes"
    printf '  help/usage text diff:   %d\n' "$help_text_changes"
    printf '  main signature changes: %d\n' "$main_signature_changes"
    printf '  enhanced CLI patterns:  %d\n' "$enhanced_cli_patterns"
}

# --- output ------------------------------------------------------------------

if $JSON_OUTPUT; then
  emit_json
elif $MACHINE_OUTPUT; then
  emit_machine
else
  emit_human
fi

# --- exit policy -------------------------------------------------------------

if $FAIL_ON_BREAKING && { $breaking_cli_changes || $api_breaking; }; then
  note "Failing due to breaking changes (--fail-on-breaking)"
  exit 2
fi
