#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Security Keyword Analyzer
# Detects security-related keywords in commit messages and code changes

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Prevent any pager and avoid unnecessary repo locks for better performance.
export GIT_PAGER=cat PAGER=cat GIT_OPTIONAL_LOCKS=0

# ------------- defaults -------------
BASE_REF=""
TARGET_REF="HEAD"
REPO_ROOT=""
ONLY_PATHS=""
IGNORE_WHITESPACE=false
ADDED_ONLY=false
NO_MERGES=false
MACHINE_OUTPUT=false
JSON_OUTPUT=false
TOP_COMMITS=10

# Weights (can be tuned via flags)
W_COMMITS=1           # security keywords in commits
W_DIFF_SEC=1          # generic security patterns in diff
W_CVE=3               # CVE references
W_MEM=2               # memory safety issues
W_CRASH=1             # crash/robustness fixes

# ------------- helpers -------------
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found"; }

show_help() {
    cat << EOF
Security Keyword Analyzer

Usage: $(basename "$0") [options]

Options:
  --base <ref>             Base reference for comparison (required)
  --target <ref>           Target reference for comparison (default: HEAD)
  --repo-root <path>       Set repository root directory
  --only-paths <globs>     Comma-separated path globs. Prefix with "!" to exclude.
                           Example: "src,include,!third_party/**"
  --ignore-whitespace      Ignore whitespace changes in diff analysis
  --added-only             Scan only added lines in diffs (skip context and removals)
  --no-merges              Ignore merge commits in commit-message scan
  --top <N>                Show up to N commit subjects in human output (default: 10)
  --machine                Output machine-readable key=value format
  --json                   Output machine-readable JSON

Weights:
  --w-commits <n>          Weight for commit keywords (default: $W_COMMITS)
  --w-diff-sec <n>         Weight for diff security patterns (default: $W_DIFF_SEC)
  --w-cve <n>              Weight for CVE matches (default: $W_CVE)
  --w-mem <n>              Weight for memory safety issues (default: $W_MEM)
  --w-crash <n>            Weight for crash/robustness fixes (default: $W_CRASH)

Examples:
  $(basename "$0") --base v1.0.0 --target HEAD
  $(basename "$0") --base HEAD~5 --target HEAD --machine
  $(basename "$0") --base v1.0.0 --target v1.1.0 --json
  $(basename "$0") --base v1.0.0 --target HEAD --only-paths "src,include,!vendor/**" --added-only
EOF
}

# Build pathspec array from ONLY_PATHS (supports excludes via :(!) and :/ syntax)
build_pathspec() {
    local spec="$1"
    local -a out=()
    [[ -z "$spec" ]] && { printf '%s\0' ""; return 0; }
    IFS=',' read -r -a _items <<<"$spec"
    for raw in "${_items[@]}"; do
        # trim spaces
        local g="${raw#"${raw%%[![:space:]]*}"}"
        g="${g%"${g##*[![:space:]]}"}"
        [[ -z "$g" ]] && continue
        if [[ "$g" == !* ]]; then
            g="${g#!}"
            out+=(":(exclude)$g")
        else
            out+=("$g")
        fi
    done
    printf '%s\0' "${out[@]}"
}

# Count occurrences of a regex in the given text (case-insensitive)
# Uses grep -Eo to count matches rather than matching lines.
count_occurrences() {
    local pattern="$1"
    # stdin required
    LC_ALL=C grep -Eio "$pattern" 2>/dev/null | wc -l | tr -cd '0-9'
}

# Sanitize integer
int_or_zero() { printf '%s' "${1:-0}" | tr -cd '0-9'; }

# Parse arguments
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
        --added-only) ADDED_ONLY=true; shift;;
        --no-merges) NO_MERGES=true; shift;;
        --top)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --top requires a number\n' >&2; exit 1; }
            TOP_COMMITS="$2"; shift 2;;
        --machine) MACHINE_OUTPUT=true; shift;;
        --json) JSON_OUTPUT=true; shift;;
        --w-commits)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --w-commits requires a number\n' >&2; exit 1; }
            W_COMMITS="$2"; shift 2;;
        --w-diff-sec)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --w-diff-sec requires a number\n' >&2; exit 1; }
            W_DIFF_SEC="$2"; shift 2;;
        --w-cve)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --w-cve requires a number\n' >&2; exit 1; }
            W_CVE="$2"; shift 2;;
        --w-mem)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --w-mem requires a number\n' >&2; exit 1; }
            W_MEM="$2"; shift 2;;
        --w-crash)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || { printf 'Error: --w-crash requires a number\n' >&2; exit 1; }
            W_CRASH="$2"; shift 2;;
        --help|-h) show_help; exit 0;;
        *) printf 'Error: Unknown option: %s\n' "$1" >&2; show_help; exit 1;;
    esac
done

# Validate required arguments
if [[ -z "$BASE_REF" ]]; then
    printf 'Error: --base is required\n' >&2
    exit 1
fi

# Check git command
need git

# Change to repo root if specified
if [[ -n "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        printf 'Error: Not in a git repository at %s\n' "$REPO_ROOT" >&2
        exit 1
    }
fi

# Build PATH_ARGS array from --only-paths
PATH_ARGS=()
if [[ -n "$ONLY_PATHS" ]]; then
    IFS=',' read -r -a tmp <<< "$ONLY_PATHS"
    PATH_ARGS+=(--)
    for g in "${tmp[@]}"; do
        # Trim surrounding spaces
        g="${g##+([[:space:]])}"
        g="${g%%+([[:space:]])}"
        [[ -n "$g" ]] && PATH_ARGS+=("$g")
    done
fi

# Validate git references
verify_ref() {
    local ref="$1"
    if ! git -c color.ui=false rev-parse -q --verify "$ref^{commit}" >/dev/null; then
        printf 'Error: Invalid reference: %s\n' "$ref" >&2
        exit 1
    fi
}

verify_ref "$BASE_REF"
verify_ref "$TARGET_REF"

# ------------- patterns (regex) -------------
# Notes:
# - Use \b word boundaries to avoid substrings.
# - Avoid "dos" matching "windows" (use \bdo[sz]\b).
# - CVE strictness: CVE-YYYY-NNNN... (4–7 digits for the sequence).
SEC_REGEX='
\b(
  security|vuln(?:erab\w*)?|exploit|breach|attack|threat
 |malware|virus|trojan|backdoor|rootkit|phishing|spam
 |ddos|\bdo[sz]\b
 |overflow|injection|xss|csrf|sqli|rce|ssrf|xxe
 |privilege|escalation|bypass|circumvent
 |mitigation|hardening|sandbox|policy
 |auth(?:entication|orization)?|session(?:\s*hijack\w*)?
 |crypto(?:graphy)?|encryption|decryption|tls|ssl|x\.509|certificate(?:\s*pinning)?
 |secret|token|leak|expos(?:e|ure)
 |path\s*traversal|directory\s*traversal
)\b'

CVE_REGEX='\bCVE-[0-9]{4}-[0-9]{4,7}\b'

MEM_REGEX='
\b(
  buffer[- _]?overflow|stack[- _]?overflow|heap[- _]?overflow
 |use[- _]?after[- _]?free|double[- _]?free
 |null[- _]?pointer|dangling[- _]?pointer|out[- _]?of[- _]?bounds|\boob\b
 |memory[- _]?leak|format[- _]?string|integer[- _]?overflow|signedness
 |race[- _]?condition|data[- _]?race|deadlock
)\b'

CRASH_REGEX='
\b(
  segfault|segmentation\s+fault|crash|abort|assert|panic
 |fatal(?:\s+error)?|core\s+dump|stack\s+trace
)\b'

# Analyze security keywords
analyze_security_keywords() {
    local base_ref="$1"
    local target_ref="$2"
    
    # Build git log command with options
    local log_cmd_array=("git" "-c" "color.ui=false" "log")
    if [[ "$NO_MERGES" = "true" ]]; then
        log_cmd_array+=("--no-merges")
    fi
    log_cmd_array+=("--format=%s %b")
    
    # Quick security keyword detection (fast path) - include commit bodies for CVEs
    local security_keywords
    security_keywords=$("${log_cmd_array[@]}" "$base_ref".."$target_ref" 2>/dev/null | \
        count_occurrences "$SEC_REGEX")
    
    # Ensure it's a valid integer
    security_keywords=$(int_or_zero "$security_keywords")
    
    # Check for specific security patterns in code changes
    local security_patterns=0
    local cve_patterns=0
    local memory_safety_issues=0
    local crash_fixes=0
    
    # Get diff for security pattern analysis
    local diff_cmd="git -c color.ui=false diff -M -C"
    if [[ "$IGNORE_WHITESPACE" = "true" ]]; then
        diff_cmd="$diff_cmd -w"
    fi
    if [[ "$ADDED_ONLY" = "true" ]]; then
        diff_cmd="$diff_cmd --diff-filter=A"
    fi
    
    local diff_content
    diff_content=$($diff_cmd "$base_ref".."$target_ref" "${PATH_ARGS[@]}" 2>/dev/null || true)
    
    # Count specific security patterns
    if [[ -n "$diff_content" ]]; then
        security_patterns=$(printf '%s' "$diff_content" | count_occurrences "$SEC_REGEX")
        cve_patterns=$(printf '%s' "$diff_content" | count_occurrences "$CVE_REGEX")
        memory_safety_issues=$(printf '%s' "$diff_content" | count_occurrences "$MEM_REGEX")
        crash_fixes=$(printf '%s' "$diff_content" | count_occurrences "$CRASH_REGEX")
    fi
    
    # Sanitize all counts to be integers
    security_patterns=$(int_or_zero "$security_patterns")
    cve_patterns=$(int_or_zero "$cve_patterns")
    memory_safety_issues=$(int_or_zero "$memory_safety_issues")
    crash_fixes=$(int_or_zero "$crash_fixes")
    
    # Calculate weighted total security score
    local total_security_score=$((security_keywords * W_COMMITS + security_patterns * W_DIFF_SEC + cve_patterns * W_CVE + memory_safety_issues * W_MEM + crash_fixes * W_CRASH))
    
    # Output results
    if [[ "$JSON_OUTPUT" = "true" ]]; then
        printf '{\n'
        printf '  "security_keywords": %s,\n' "$security_keywords"
        printf '  "security_patterns": %s,\n' "$security_patterns"
        printf '  "cve_patterns": %s,\n' "$cve_patterns"
        printf '  "memory_safety_issues": %s,\n' "$memory_safety_issues"
        printf '  "crash_fixes": %s,\n' "$crash_fixes"
        printf '  "total_security_score": %s,\n' "$total_security_score"
        printf '  "weights": {\n'
        printf '    "commits": %s,\n' "$W_COMMITS"
        printf '    "diff_security": %s,\n' "$W_DIFF_SEC"
        printf '    "cve": %s,\n' "$W_CVE"
        printf '    "memory": %s,\n' "$W_MEM"
        printf '    "crash": %s\n' "$W_CRASH"
        printf '  }\n'
        printf '}\n'
    elif [[ "$MACHINE_OUTPUT" = "true" ]]; then
        printf 'SECURITY_KEYWORDS=%s\n' "$security_keywords"
        printf 'SECURITY_PATTERNS=%s\n' "$security_patterns"
        printf 'CVE_PATTERNS=%s\n' "$cve_patterns"
        printf 'MEMORY_SAFETY_ISSUES=%s\n' "$memory_safety_issues"
        printf 'CRASH_FIXES=%s\n' "$crash_fixes"
        printf 'TOTAL_SECURITY_SCORE=%s\n' "$total_security_score"
        printf 'WEIGHT_COMMITS=%s\n' "$W_COMMITS"
        printf 'WEIGHT_DIFF_SEC=%s\n' "$W_DIFF_SEC"
        printf 'WEIGHT_CVE=%s\n' "$W_CVE"
        printf 'WEIGHT_MEMORY=%s\n' "$W_MEM"
        printf 'WEIGHT_CRASH=%s\n' "$W_CRASH"
    else
        printf '=== Security Keyword Analysis ===\n'
        printf 'Base reference: %s\n' "$base_ref"
        printf 'Target reference: %s\n' "$target_ref"
        printf '\nSecurity Analysis:\n'
        printf '  Security keywords in commits: %s (weight: %s)\n' "$security_keywords" "$W_COMMITS"
        printf '  Security patterns in code: %s (weight: %s)\n' "$security_patterns" "$W_DIFF_SEC"
        printf '  CVE references: %s (weight: %s)\n' "$cve_patterns" "$W_CVE"
        printf '  Memory safety issues: %s (weight: %s)\n' "$memory_safety_issues" "$W_MEM"
        printf '  Crash fixes: %s (weight: %s)\n' "$crash_fixes" "$W_CRASH"
        printf '  Total security score: %s\n' "$total_security_score"
        
        if [[ "$total_security_score" -gt 0 ]]; then
            printf '\nSecurity Keywords Detected:\n'
            local log_cmd_short_array=("git" "-c" "color.ui=false" "log" "--format=%s")
            if [[ "$NO_MERGES" = "true" ]]; then
                log_cmd_short_array+=("--no-merges")
            fi
            "${log_cmd_short_array[@]}" "$base_ref".."$target_ref" 2>/dev/null | \
                grep -i -E "$(printf '%s' "$SEC_REGEX" | tr -d '\n')" | \
                head -"$TOP_COMMITS" || printf '  None found in commit messages\n'
        fi
    fi
}

# Main execution
analyze_security_keywords "$BASE_REF" "$TARGET_REF"
