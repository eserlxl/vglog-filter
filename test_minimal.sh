#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

echo "Testing minimal execution"
echo "Script dir: $SCRIPT_DIR"

# Test ref-resolver
echo "Testing ref-resolver..."
ref_output=$(./dev-bin/ref-resolver --machine)
echo "Ref output length: ${#ref_output}"

# Test parsing
echo "Testing parsing..."
declare -A REF=()
while IFS='=' read -r k v; do
    [[ -z "${k// }" ]] && continue
    REF["$k"]="$v"
done <<< "$ref_output"

echo "Parsed REF keys: ${!REF[*]}"
echo "REF[HAS_COMMITS]=${REF[HAS_COMMITS]:-not_set}"

# Test early exit
echo "Testing early exit condition..."
if [[ "${REF[SINGLE_COMMIT_REPO]:-false}" == "true" || "${REF[HAS_COMMITS]:-true}" == "false" ]]; then
    echo "EARLY EXIT"
    exit 20
fi

echo "No early exit, continuing..." 