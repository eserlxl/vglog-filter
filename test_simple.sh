#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

SUGGEST_ONLY=true
suggestion="major"

echo "Testing suggest-only logic"
if [[ "$SUGGEST_ONLY" == "true" ]]; then
    printf '%s\n' "$suggestion"
    echo "Should exit 0"
    exit 0
fi
echo "This should not print" 