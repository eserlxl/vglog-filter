#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

# SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

debug() { [[ "${VERBOSE:-false}" == "true" ]] && printf 'Debug: %s\n' "$*" >&2; }

VERBOSE=true
debug "Testing ref-resolver"
ref_output=$(./dev-bin/ref-resolver --machine)
echo "Ref output: $ref_output"

debug "Testing parsing"
declare -A REF=()
while IFS='=' read -r k v; do
    [[ -z "${k// }" ]] && continue
    REF["$k"]="$v"
done <<< "$ref_output"

echo "REF[HAS_COMMITS]=${REF[HAS_COMMITS]:-not_set}"
echo "REF[SINGLE_COMMIT_REPO]=${REF[SINGLE_COMMIT_REPO]:-not_set}"

debug "Testing early exit condition"
echo "SINGLE_COMMIT_REPO check: ${REF[SINGLE_COMMIT_REPO]:-false} == true"
echo "HAS_COMMITS check: ${REF[HAS_COMMITS]:-true} == false"

if [[ "${REF[SINGLE_COMMIT_REPO]:-false}" == "true" || "${REF[HAS_COMMITS]:-true}" == "false" ]]; then
    echo "EARLY EXIT WOULD TRIGGER"
else
    echo "EARLY EXIT WOULD NOT TRIGGER"
fi 