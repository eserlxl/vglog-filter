#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Semantic Version Analyzer v2 for vglog-filter
# Orchestrates modular components for version analysis

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Avoid pagers and unnecessary repo locks for speed.
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=0

# ----------------------------- help / ui --------------------------------------
show_help() {
  cat << 'EOF'
Semantic Version Analyzer v2 for vglog-filter

Usage: semantic-version-analyzer [options]

Options:
  --since <tag>            Analyze changes since specific tag (default: last tag)
  --since-tag <tag>        Alias for --since
  --since-commit <hash>    Analyze changes since specific commit
  --since-date <date>      Analyze changes since specific date (YYYY-MM-DD)
  --base <ref>             Set base reference for comparison (default: auto-detected)
  --target <ref>           Set target reference for comparison (default: HEAD)
  --repo-root <path>       Set repository root directory for analysis
  --no-merge-base          Disable automatic merge-base detection for disjoint branches
  --only-paths <globs>     Restrict analysis to comma-separated path globs
  --ignore-whitespace      Ignore whitespace changes in diff analysis
  --verbose                Show detailed progress and debug lines on stderr
  --machine                Output machine-readable key=value (top-level result)
  --json                   Output machine-readable JSON (top-level result)
  --suggest-only           Output only the suggestion (major/minor/patch/none)
  --strict-status          Use strict exit codes even with --suggest-only
  --help, -h               Show this help

Examples:
  semantic-version-analyzer --since v1.1.0
  semantic-version-analyzer --since-date 2025-01-01
  semantic-version-analyzer --base HEAD~5 --target HEAD
  semantic-version-analyzer --only-paths "src/**,include/**"
  semantic-version-analyzer --verbose
  semantic-version-analyzer --json

Exit codes:
  10 = major suggestion
  11 = minor suggestion
  12 = patch suggestion
  20 = none
  0  = success for non-strict --suggest-only
EOF
}

# ----------------------------- args -------------------------------------------
SINCE_TAG=""
SINCE_COMMIT=""
SINCE_DATE=""
BASE_REF=""
TARGET_REF=""
REPO_ROOT=""
NO_MERGE_BASE=false
ONLY_PATHS=""
IGNORE_WHITESPACE=false
VERBOSE=false
MACHINE_OUTPUT=false
JSON_OUTPUT=false
SUGGEST_ONLY=false
STRICT_STATUS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --since|--since-tag)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --since requires a value\n' >&2; exit 1; }
      SINCE_TAG="$2"; shift 2;;
    --since-commit)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --since-commit requires a value\n' >&2; exit 1; }
      SINCE_COMMIT="$2"; shift 2;;
    --since-date)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --since-date requires a value\n' >&2; exit 1; }
      SINCE_DATE="$2"; shift 2;;
    --base)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --base requires a value\n' >&2; exit 1; }
      BASE_REF="$2"; shift 2;;
    --target)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --target requires a value\n' >&2; exit 1; }
      TARGET_REF="$2"; shift 2;;
    --repo-root)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --repo-root requires a value\n' >&2; exit 1; }
      REPO_ROOT="$2"; shift 2;;
    --no-merge-base) NO_MERGE_BASE=true; shift;;
    --only-paths)
      [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --only-paths requires a comma-separated globs list\n' >&2; exit 1; }
      ONLY_PATHS="$2"; shift 2;;
    --ignore-whitespace) IGNORE_WHITESPACE=true; shift;;
    --verbose) VERBOSE=true; shift;;
    --machine) MACHINE_OUTPUT=true; shift;;
    --json) JSON_OUTPUT=true; shift;;
    --suggest-only) SUGGEST_ONLY=true; shift;;
    --strict-status) STRICT_STATUS=true; shift;;
    --help|-h) show_help; exit 0;;
    *) printf 'Error: Unknown option: %s\n' "$1" >&2; show_help; exit 1;;
  esac
done

# ----------------------------- helpers ----------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

log()   { printf '%s\n' "$*" >&2; }
debug() { [[ "$VERBOSE" == "true" ]] && printf 'Debug: %s\n' "$*" >&2; }

check_binary() {
  local path="$1"
  if [[ -x "$path" ]]; then return 0; fi
  # Fallback to PATH by basename to be forgiving
  local base; base="$(basename -- "$path")"
  if command -v -- "$base" >/dev/null 2>&1; then return 0; fi
  printf 'Error: Required binary not found: %s\n' "$path" >&2
  exit 1
}

# nameref-based key=value parser into associative array
# usage: parse_kv_into assoc_name <<< "$output"
parse_kv_into() {
  local -n __dst="$1"
  local k v
  while IFS='=' read -r k v; do
    [[ -z "${k// }" ]] && continue
    __dst["$k"]="$v"
  done
}

# Integer coercion with default
int_or_default() {
  local v="${1:-}"; local def="${2:-0}"
  if [[ "$v" =~ ^-?[0-9]+$ ]]; then printf '%s' "$v"; else printf '%s' "$def"; fi
}

# Minimal JSON string escaper (for refs/versions; conservative)
json_escape() {
  local s=${1:-}
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

# Build common argv for analyzers (array via nameref)
build_common_argv() {
  local -n _out="$1"; _out=()
  [[ -n "$BASE_REF" ]]     && _out+=(--base "$BASE_REF")
  [[ -n "$TARGET_REF" ]]   && _out+=(--target "$TARGET_REF")
  [[ -n "$REPO_ROOT" ]]    && _out+=(--repo-root "$REPO_ROOT")
  [[ -n "$ONLY_PATHS" ]]   && _out+=(--only-paths "$ONLY_PATHS")
  [[ "$IGNORE_WHITESPACE" == "true" ]] && _out+=(--ignore-whitespace)
  _out+=(--machine) # force machine for internal components
}

# Build ref-resolver argv (array via nameref)
build_ref_argv() {
  local -n _out="$1"; _out=()
  [[ -n "$SINCE_TAG"    ]] && _out+=(--since "$SINCE_TAG")
  [[ -n "$SINCE_COMMIT" ]] && _out+=(--since-commit "$SINCE_COMMIT")
  [[ -n "$SINCE_DATE"   ]] && _out+=(--since-date "$SINCE_DATE")
  [[ -n "$BASE_REF"     ]] && _out+=(--base "$BASE_REF")
  [[ -n "$TARGET_REF"   ]] && _out+=(--target "$TARGET_REF")
  [[ -n "$REPO_ROOT"    ]] && _out+=(--repo-root "$REPO_ROOT")
  [[ "$NO_MERGE_BASE" == "true" ]] && _out+=(--no-merge-base)
  _out+=(--machine) # always machine for parsing
}

# Run a component and capture stdout in a variable name (nameref)
run_cmd_capture() {
  local -n _dst="$1"; shift
  local out
  if ! out="$("$@")"; then
    # Special handling for security-keyword-analyzer which may return exit code 2 for "no issues found"
    if [[ "$*" == *"security-keyword-analyzer"* ]]; then
      _dst="SECURITY_KEYWORDS=0
SECURITY_PATTERNS=0
CVE_PATTERNS=0
MEMORY_SAFETY_ISSUES=0
CRASH_FIXES=0
TOTAL_SECURITY_SCORE=0
WEIGHT_COMMITS=1
WEIGHT_DIFF_SEC=1
WEIGHT_CVE=3
WEIGHT_MEMORY=2
WEIGHT_CRASH=1"
      return 0
    fi
    printf 'Error: Command failed: %s\n' "$*" >&2
    exit 1
  fi
  _dst="$out"
}

# ----------------------------- binary checks ----------------------------------
check_binary "$SCRIPT_DIR/ref-resolver"
check_binary "$SCRIPT_DIR/version-config-loader"
check_binary "$SCRIPT_DIR/file-change-analyzer"
check_binary "$SCRIPT_DIR/cli-options-analyzer"
check_binary "$SCRIPT_DIR/security-keyword-analyzer"
check_binary "$SCRIPT_DIR/keyword-analyzer"
check_binary "$SCRIPT_DIR/version-calculator"

# ----------------------------- main -------------------------------------------
main() {
  # If a repo root is specified, temporarily cd there to keep relative file reads consistent.
  local did_pushd=false
  if [[ -n "$REPO_ROOT" ]]; then
    pushd "$REPO_ROOT" >/dev/null
    did_pushd=true
    trap '[[ "$did_pushd" == "true" ]] && popd >/dev/null || true' EXIT
  fi

  # 1) Resolve refs
  debug "Resolving git references..."
  local ref_argv=(); build_ref_argv ref_argv
  local ref_raw; run_cmd_capture ref_raw "$SCRIPT_DIR/ref-resolver" "${ref_argv[@]}"
  declare -A REF=(); parse_kv_into REF <<<"$ref_raw"

  # Early-outs on trivial repos
  if [[ "${REF[SINGLE_COMMIT_REPO]:-false}" == "true" || "${REF[HAS_COMMITS]:-true}" == "false" ]]; then
    if [[ "$SUGGEST_ONLY" == "true" ]]; then
      printf 'none\n'
      exit 0
    fi
    if [[ "$JSON_OUTPUT" == "true" ]]; then
      printf '{ "suggestion": "none" }\n'
    elif [[ "$MACHINE_OUTPUT" == "true" ]]; then
      printf 'SUGGESTION=none\n'
    else
      printf '=== Semantic Version Analysis v2 ===\nNo meaningful history; suggestion: NONE\n'
    fi
    exit 20
  fi

  BASE_REF="${REF[BASE_REF]:-$BASE_REF}"
  TARGET_REF="${REF[TARGET_REF]:-${TARGET_REF:-HEAD}}"

  # 2) Load config (key=value)
  debug "Loading version configuration..."
  local cfg_raw; run_cmd_capture cfg_raw "$SCRIPT_DIR/version-config-loader" --machine
  declare -A CFG=(); parse_kv_into CFG <<<"$cfg_raw"

  # 3) Analyze file changes
  debug "Analyzing file changes..."
  local common_argv=(); build_common_argv common_argv
  local file_raw; run_cmd_capture file_raw "$SCRIPT_DIR/file-change-analyzer" "${common_argv[@]}"
  declare -A FILE=(); parse_kv_into FILE <<<"$file_raw"

  # 4) Analyze CLI options
  debug "Analyzing CLI options..."
  local cli_raw; run_cmd_capture cli_raw "$SCRIPT_DIR/cli-options-analyzer" "${common_argv[@]}"
  declare -A CLI=(); parse_kv_into CLI <<<"$cli_raw"

  # 5) Security keywords
  debug "Analyzing security keywords..."
  local sec_raw; run_cmd_capture sec_raw "$SCRIPT_DIR/security-keyword-analyzer" "${common_argv[@]}"
  declare -A SEC=(); parse_kv_into SEC <<<"$sec_raw"

  # 6) General keyword analysis
  debug "Analyzing breaking-change keywords..."
  local kw_raw; run_cmd_capture kw_raw "$SCRIPT_DIR/keyword-analyzer" "${common_argv[@]}"
  declare -A KW=(); parse_kv_into KW <<<"$kw_raw"

  # 7) Bonus calculation -------------------------------------------------------
  local TOTAL_BONUS=0

  debug "Keyword flags: HAS_CLI_BREAKING=${KW[HAS_CLI_BREAKING]:-false}, HAS_API_BREAKING=${KW[HAS_API_BREAKING]:-false}, TOTAL_SECURITY=${KW[TOTAL_SECURITY]:-0}"

  # Breaking via keywords > CLI analyzers
  if [[ "${KW[HAS_CLI_BREAKING]:-false}" == "true" || "${CLI[BREAKING_CLI_CHANGES]:-false}" == "true" ]]; then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_BREAKING_CLI_BONUS]}" 2) ))
  fi
  if [[ "${KW[HAS_API_BREAKING]:-false}" == "true" || "${CLI[API_BREAKING]:-false}" == "true" ]]; then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_API_BREAKING_BONUS]}" 3) ))
  fi

  # Security keywords (both sources)
  local security_keywords=$(int_or_default "${SEC[SECURITY_KEYWORDS]}" 0)
  local keyword_security=$(int_or_default "${KW[TOTAL_SECURITY]}" 0)
  local total_security=$(( security_keywords + keyword_security ))
  if (( total_security > 0 )); then
    TOTAL_BONUS=$(( TOTAL_BONUS + total_security * $(int_or_default "${CFG[VERSION_SECURITY_BONUS]}" 2) ))
  fi

  # Feature additions
  if [[ "${CLI[CLI_CHANGES]:-false}" == "true" ]]; then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_CLI_CHANGES_BONUS]}" 2) ))
  fi
  if [[ "${CLI[MANUAL_CLI_CHANGES]:-false}" == "true" ]]; then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_MANUAL_CLI_BONUS]}" 1) ))
  fi
  if (( $(int_or_default "${FILE[NEW_SOURCE_FILES]}" 0) > 0 )); then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_NEW_SOURCE_BONUS]}" 1) ))
  fi
  if (( $(int_or_default "${FILE[NEW_TEST_FILES]}" 0) > 0 )); then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_NEW_TEST_BONUS]}" 1) ))
  fi
  if (( $(int_or_default "${FILE[NEW_DOC_FILES]}" 0) > 0 )); then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_NEW_DOC_BONUS]}" 1) ))
  fi

  # Removed options (both sources)
  local cli_removed=$(( $(int_or_default "${CLI[REMOVED_SHORT_COUNT]}" 0) + $(int_or_default "${CLI[REMOVED_LONG_COUNT]}" 0) ))
  local kw_removed=$(int_or_default "${KW[REMOVED_OPTIONS_KEYWORDS]}" 0)
  local total_removed=$(( cli_removed + kw_removed ))
  if (( total_removed > 0 )); then
    TOTAL_BONUS=$(( TOTAL_BONUS + $(int_or_default "${CFG[VERSION_REMOVED_OPTION_BONUS]}" 1) ))
  fi

  debug "Final TOTAL_BONUS=$TOTAL_BONUS"

  # 8) Suggestion thresholds
  local major_th=$(int_or_default "${CFG[MAJOR_BONUS_THRESHOLD]}" 8)
  local minor_th=$(int_or_default "${CFG[MINOR_BONUS_THRESHOLD]}" 4)
  local patch_th=$(int_or_default "${CFG[PATCH_BONUS_THRESHOLD]}" 0)

  local suggestion="none"
  if   (( TOTAL_BONUS >= major_th )); then suggestion="major"
  elif (( TOTAL_BONUS >= minor_th )); then suggestion="minor"
  elif (( TOTAL_BONUS >= patch_th )); then suggestion="patch"
  fi

  # 9) Current version (from VERSION file if present)
  local current_version="0.0.0"
  if [[ -f "VERSION" ]]; then
    current_version="$(tr -d '[:space:]' < VERSION 2>/dev/null || true)"
    [[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || current_version="0.0.0"
  fi

  # 10) Next version (via version-calculator)
  local next_version=""
  if [[ "$suggestion" != "none" ]]; then
    local vc_argv=( --current-version "$current_version" --bump-type "$suggestion"
                    --loc "$(int_or_default "${FILE[DIFF_SIZE]}" 0)"
                    --bonus "$TOTAL_BONUS" --machine )
    local vc_raw; run_cmd_capture vc_raw "$SCRIPT_DIR/version-calculator" "${vc_argv[@]}"
    declare -A VC=(); parse_kv_into VC <<<"$vc_raw"
    next_version="${VC[NEXT_VERSION]:-}"
  fi

  # 11) Output formats ---------------------------------------------------------
  debug "Output section reached, SUGGEST_ONLY=$SUGGEST_ONLY, suggestion=$suggestion"
  if [[ "$SUGGEST_ONLY" == "true" ]]; then
    echo "TEST OUTPUT: $suggestion" >&2
    echo "$suggestion"
  elif [[ "$JSON_OUTPUT" == "true" ]]; then
    # Ask calculator for deltas (patch/minor/major) with machine, convert totals
    local loc="$(int_or_default "${FILE[DIFF_SIZE]}" 0)"

    local pd_raw; run_cmd_capture pd_raw "$SCRIPT_DIR/version-calculator" --current-version "$current_version" --bump-type patch --loc "$loc" --bonus "$TOTAL_BONUS" --machine
    declare -A PD=(); parse_kv_into PD <<<"$pd_raw"
    local md_raw; run_cmd_capture md_raw "$SCRIPT_DIR/version-calculator" --current-version "$current_version" --bump-type minor --loc "$loc" --bonus "$TOTAL_BONUS" --machine
    declare -A MD=(); parse_kv_into MD <<<"$md_raw"
    local jd_raw; run_cmd_capture jd_raw "$SCRIPT_DIR/version-calculator" --current-version "$current_version" --bump-type major --loc "$loc" --bonus "$TOTAL_BONUS" --machine
    declare -A JD=(); parse_kv_into JD <<<"$jd_raw"

    printf '{\n'
    printf '  "suggestion": "%s",\n' "$(json_escape "$suggestion")"
    printf '  "current_version": "%s",\n' "$(json_escape "$current_version")"
    if [[ -n "$next_version" ]]; then
      printf '  "next_version": "%s",\n' "$(json_escape "$next_version")"
    fi
    printf '  "total_bonus": %s,\n' "$TOTAL_BONUS"
    printf '  "base_ref": "%s",\n' "$(json_escape "$BASE_REF")"
    printf '  "target_ref": "%s",\n' "$(json_escape "$TARGET_REF")"
    printf '  "loc_delta": {\n'
    printf '    "patch_delta": %s,\n' "$(int_or_default "${PD[total_delta]}" 1)"
    printf '    "minor_delta": %s,\n' "$(int_or_default "${MD[total_delta]}" 5)"
    printf '    "major_delta": %s\n'   "$(int_or_default "${JD[total_delta]}" 10)"
    printf '  }\n'
    printf '}\n'
  elif [[ "$MACHINE_OUTPUT" == "true" ]]; then
    printf 'SUGGESTION=%s\n' "$suggestion"
  else
    printf '=== Semantic Version Analysis v2 ===\n'
    printf 'Analyzing changes: %s -> %s\n' "$BASE_REF" "$TARGET_REF"
    printf '\nCurrent version: %s\n' "$current_version"
    printf 'Total bonus points: %s\n' "$TOTAL_BONUS"
    printf '\nSuggested bump: %s\n' "$(tr '[:lower:]' '[:upper:]' <<<"$suggestion")"
    if [[ -n "$next_version" ]]; then
      printf 'Next version: %s\n' "$next_version"
    fi
    printf '\nSUGGESTION=%s\n' "$suggestion"
  fi

  # 12) Exit code policy -------------------------------------------------------
  if [[ "$SUGGEST_ONLY" == "true" && "$STRICT_STATUS" != "true" ]]; then
    exit 0
  fi
  case "$suggestion" in
    major) exit 10 ;;
    minor) exit 11 ;;
    patch) exit 12 ;;
    none)  exit 20 ;;
    *)     exit 0 ;;
  esac
}

main "$@"
