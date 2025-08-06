#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Version Calculator
# Calculates next version based on LOC-based delta system and bonus points

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

show_help() {
    cat << 'EOF'
Version Calculator

Usage:
  $(basename "$0") [options]

Options:
  --current-version <ver>  Current version (e.g., 1.2.3)
  --bump-type <type>       Bump type: major, minor, patch
  --loc <number>           Lines of code changed (non-negative integer)
  --bonus <number>         Bonus points to add (non-negative integer)
  --machine                Output machine-readable key=value format
  --json                   Output machine-readable JSON
  --main-mod <number>      MAIN_VERSION_MOD (default: 1000)
  --strict                 Fail on invalid --current-version instead of falling back to 0.0.0
  --help, -h               Show this help

Examples:
  $(basename "$0") --current-version 1.2.3 --bump-type minor --loc 500
  $(basename "$0") --current-version 1.2.3 --bump-type major --bonus 10 --machine
  $(basename "$0") --current-version 1.2.3 --bump-type patch --loc 100 --json
EOF
}

# ---------- utilities ----------
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

# round_div a/b with nearest-integer rounding
# works for non-negative integers only (we validate inputs as non-negative)
round_div() {
    local a="$1" b="$2"
    # prevent div-by-zero
    (( b == 0 )) && die "internal error: division by zero"
    echo $(( (a + b/2) / b ))
}

# Render n/100 as fixed 2 decimals. n is non-negative integer.
fmt_fixed2_from_int100() {
    local n="$1"
    local whole=$(( n / 100 ))
    local frac=$(( n % 100 ))
    printf '%d.%02d' "$whole" "$frac"
}

# ---------- defaults ----------
CURRENT_VERSION=""
BUMP_TYPE=""
LOC=0
BONUS=0
MACHINE_OUTPUT=false
JSON_OUTPUT=false
STRICT=false
MAIN_VERSION_MOD=1000

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --current-version)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--current-version requires a value"
            CURRENT_VERSION="$2"; shift 2;;
        --bump-type)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--bump-type requires a value"
            BUMP_TYPE="$2"; shift 2;;
        --loc)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--loc requires a value"
            LOC="$2"; shift 2;;
        --bonus)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--bonus requires a value"
            BONUS="$2"; shift 2;;
        --main-mod)
            [[ -n "${2-}" && "${2#-}" = "$2" ]] || die "--main-mod requires a value"
            MAIN_VERSION_MOD="$2"; shift 2;;
        --machine) MACHINE_OUTPUT=true; shift;;
        --json) JSON_OUTPUT=true; shift;;
        --strict) STRICT=true; shift;;
        --help|-h) show_help; exit 0;;
        *) die "Unknown option: $1";;
    esac
done

# ---------- validate ----------
[[ -n "$CURRENT_VERSION" ]] || die "--current-version is required"
[[ -n "$BUMP_TYPE"    ]] || die "--bump-type is required"

case "$BUMP_TYPE" in major|minor|patch) ;; *) die "--bump-type must be major, minor, or patch";; esac
is_uint "$LOC"   || die "--loc must be a non-negative integer"
is_uint "$BONUS" || die "--bonus must be a non-negative integer"
# shellcheck disable=SC2015
is_uint "$MAIN_VERSION_MOD" && (( MAIN_VERSION_MOD >= 1 )) || die "--main-mod must be a positive integer"

# ---------- parse semver (fallback or strict) ----------
if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
else
    if $STRICT; then
        die "--current-version must be in form X.Y.Z (strict mode)"
    fi
    major=0 minor=0 patch=0
fi

# Handle special case for 0.0.0
if [[ "$CURRENT_VERSION" = "0.0.0" ]] || [[ -z "$CURRENT_VERSION" ]]; then
    case "$BUMP_TYPE" in
        major) NEXT_VERSION="1.0.0" ;;
        minor) NEXT_VERSION="0.1.0" ;;
        patch) NEXT_VERSION="0.0.1" ;;
        *) NEXT_VERSION="0.0.0" ;;
    esac
    
    # Output results for 0.0.0 case
    if [[ "$JSON_OUTPUT" = "true" ]]; then
        printf '{\n'
        printf '  "current_version": "%s",\n' "$CURRENT_VERSION"
        printf '  "bump_type": "%s",\n' "$BUMP_TYPE"
        printf '  "next_version": "%s",\n' "$NEXT_VERSION"
        printf '  "loc": %s,\n' "$LOC"
        printf '  "bonus": %s,\n' "$BONUS"
        printf '  "base_delta": 0,\n'
        printf '  "bonus_multiplier": "1.00",\n'
        printf '  "total_bonus": 0,\n'
        printf '  "total_delta": 0,\n'
        printf '  "main_version_mod": %s,\n' "$MAIN_VERSION_MOD"
        printf '  "loc_divisor": 0,\n'
        printf '  "reason": "Initial version from 0.0.0"\n'
        printf '}\n'
    elif [[ "$MACHINE_OUTPUT" = "true" ]]; then
        printf 'CURRENT_VERSION=%s\n' "$CURRENT_VERSION"
        printf 'BUMP_TYPE=%s\n' "$BUMP_TYPE"
        printf 'NEXT_VERSION=%s\n' "$NEXT_VERSION"
        printf 'LOC=%s\n' "$LOC"
        printf 'BONUS=%s\n' "$BONUS"
        printf 'BASE_DELTA=0\n'
        printf 'BONUS_MULTIPLIER=1.00\n'
        printf 'TOTAL_BONUS=0\n'
        printf 'TOTAL_DELTA=0\n'
        printf 'MAIN_VERSION_MOD=%s\n' "$MAIN_VERSION_MOD"
        printf 'LOC_DIVISOR=0\n'
        printf 'REASON=Initial version from 0.0.0\n'
    else
        printf '=== Version Calculation ===\n'
        printf 'Current version: %s\n' "$CURRENT_VERSION"
        printf 'Bump type: %s\n' "$BUMP_TYPE"
        printf 'Next version: %s\n' "$NEXT_VERSION"
        printf '\nCalculation Details:\n'
        printf '  Lines of code: %s\n' "$LOC"
        printf '  Base bonus: %s\n' "$BONUS"
        printf '  Base delta: 0\n'
        printf '  Bonus multiplier: 1.00\n'
        printf '  Total bonus: 0\n'
        printf '  Total delta: 0\n'
        printf '  Main version mod: %s\n' "$MAIN_VERSION_MOD"
        printf '  LOC divisor: 0\n'
        printf '\nReason: Initial version from 0.0.0\n'
    fi
    exit 0
fi

# ---------- constants per bump type ----------
# LOC divisor used both for base delta slope and for bonus multiplier (1 + LOC/L)
loc_divisor=250
case "$BUMP_TYPE" in
    patch) loc_divisor=250 ;;
    minor) loc_divisor=500 ;;
    major) loc_divisor=1000 ;;
esac

# ---------- base delta (pure integer with rounding) ----------
# Given in original:
#  patch: round(1   * (1 + LOC/250))  == 1 + round(LOC/250)
#  minor: round(5   * (1 + LOC/500))  == 5 + round(LOC/100)
#  major: round(10  * (1 + LOC/1000)) == 10 + round(LOC/100)
calc_base_delta() {
    local bt="$1" loc="$2"
    local base=1 add=0
    case "$bt" in
        patch) base=1;   add=$(round_div "$((loc))" 250) ;;
        minor) base=5;   add=$(round_div "$((loc))" 100) ;;
        major) base=10;  add=$(round_div "$((loc))" 100) ;;
        *) base=1; add=0 ;;
    esac
    local out=$(( base + add ))
    (( out < 1 )) && out=1
    echo "$out"
}

BASE_DELTA="$(calc_base_delta "$BUMP_TYPE" "$LOC")"

# ---------- bonus multiplier and total bonus ----------
# bonus_multiplier = 1 + LOC/loc_divisor (rendered as 2 decimals for output)
# total_bonus = round(BONUS * (1 + LOC/loc_divisor)) = BONUS + round(BONUS*LOC/loc_divisor)
# Keep math integer, only render multiplier as string w/2 decimals.
bonus_scale_100=$(( (100 * (loc_divisor + LOC) + loc_divisor/2) / loc_divisor ))   # == round(100*(1+LOC/L))
BONUS_MULTIPLIER_STR="$(fmt_fixed2_from_int100 "$bonus_scale_100")"

bonus_extra="$(round_div "$(( BONUS * LOC ))" "$loc_divisor")"
TOTAL_BONUS=$(( BONUS + bonus_extra ))

# ---------- total delta ----------
TOTAL_DELTA=$(( BASE_DELTA + TOTAL_BONUS ))
(( TOTAL_DELTA < 1 )) && TOTAL_DELTA=1

# ---------- rollover math ----------
# z_new = (patch + TOTAL_DELTA)
# delta_y = floor(z_new / MAIN_VERSION_MOD)
# y_new = minor + delta_y
# delta_x = floor(y_new / MAIN_VERSION_MOD)
# final = (major + delta_x).(y_new % mod).(z_new % mod)
z_new=$(( patch + TOTAL_DELTA ))
delta_y=$(( z_new / MAIN_VERSION_MOD ))
final_z=$(( z_new % MAIN_VERSION_MOD ))

y_new=$(( minor + delta_y ))
delta_x=$(( y_new / MAIN_VERSION_MOD ))
final_y=$(( y_new % MAIN_VERSION_MOD ))

final_x=$(( major + delta_x ))
NEXT_VERSION="${final_x}.${final_y}.${final_z}"

# ---------- output ----------
if $JSON_OUTPUT; then
    printf '{\n'
    printf '  "current_version": "%s",\n' "$CURRENT_VERSION"
    printf '  "bump_type": "%s",\n' "$BUMP_TYPE"
    printf '  "next_version": "%s",\n' "$NEXT_VERSION"
    printf '  "loc": %s,\n' "$LOC"
    printf '  "bonus": %s,\n' "$BONUS"
    printf '  "base_delta": %s,\n' "$BASE_DELTA"
    printf '  "bonus_multiplier": "%s",\n' "$BONUS_MULTIPLIER_STR"
    printf '  "total_bonus": %s,\n' "$TOTAL_BONUS"
    printf '  "total_delta": %s,\n' "$TOTAL_DELTA"
    printf '  "main_version_mod": %s,\n' "$MAIN_VERSION_MOD"
    printf '  "loc_divisor": %s,\n' "$loc_divisor"
    printf '  "reason": "LOC=%s, %s update, base_delta=%s, bonus=%s*%s=%s, total_delta=%s"\n' \
           "$LOC" "$(printf '%s' "$BUMP_TYPE" | tr '[:lower:]' '[:upper:]')" \
           "$BASE_DELTA" "$BONUS" "$BONUS_MULTIPLIER_STR" "$TOTAL_BONUS" "$TOTAL_DELTA"
    printf '}\n'
elif $MACHINE_OUTPUT; then
    printf 'CURRENT_VERSION=%s\n'  "$CURRENT_VERSION"
    printf 'BUMP_TYPE=%s\n'        "$BUMP_TYPE"
    printf 'NEXT_VERSION=%s\n'     "$NEXT_VERSION"
    printf 'LOC=%s\n'              "$LOC"
    printf 'BONUS=%s\n'            "$BONUS"
    printf 'BASE_DELTA=%s\n'       "$BASE_DELTA"
    printf 'BONUS_MULTIPLIER=%s\n' "$BONUS_MULTIPLIER_STR"
    printf 'TOTAL_BONUS=%s\n'      "$TOTAL_BONUS"
    printf 'TOTAL_DELTA=%s\n'      "$TOTAL_DELTA"
    printf 'MAIN_VERSION_MOD=%s\n' "$MAIN_VERSION_MOD"
    printf 'LOC_DIVISOR=%s\n'      "$loc_divisor"
    printf 'REASON=LOC=%s, %s update, base_delta=%s, bonus=%s*%s=%s, total_delta=%s\n' \
           "$LOC" "$(printf '%s' "$BUMP_TYPE" | tr '[:lower:]' '[:upper:]')" \
           "$BASE_DELTA" "$BONUS" "$BONUS_MULTIPLIER_STR" "$TOTAL_BONUS" "$TOTAL_DELTA"
else
    printf '=== Version Calculation ===\n'
    printf 'Current version: %s\n' "$CURRENT_VERSION"
    printf 'Bump type: %s\n'       "$BUMP_TYPE"
    printf 'Next version: %s\n'    "$NEXT_VERSION"
    printf '\nCalculation Details:\n'
    printf '  Lines of code: %s\n'     "$LOC"
    printf '  Base bonus: %s\n'        "$BONUS"
    printf '  Base delta: %s\n'        "$BASE_DELTA"
    printf '  Bonus multiplier: %s\n'  "$BONUS_MULTIPLIER_STR"
    printf '  Total bonus: %s\n'       "$TOTAL_BONUS"
    printf '  Total delta: %s\n'       "$TOTAL_DELTA"
    printf '  Main version mod: %s\n'  "$MAIN_VERSION_MOD"
    printf '  LOC divisor: %s\n'       "$loc_divisor"
    printf '\nReason: LOC=%s, %s update, base_delta=%s, bonus=%s*%s=%s, total_delta=%s\n' \
           "$LOC" "$(printf '%s' "$BUMP_TYPE" | tr '[:lower:]' '[:upper:]')" \
           "$BASE_DELTA" "$BONUS" "$BONUS_MULTIPLIER_STR" "$TOTAL_BONUS" "$TOTAL_DELTA"
fi 