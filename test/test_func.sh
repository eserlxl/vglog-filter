#!/bin/bash
set -Eeuo pipefail
classify_path() {
    local path="$1"
    if [[ "$path" =~ ^(build|dist|out|third_party|vendor|.git|node_modules|target|bin|obj)/ ]] || [[ "$path" =~ \.(lock|exe|dll|so|dylib|jar|war|ear|zip|tar|gz|bz2|xz|7z|rar)$ ]]; then
        return 0
    fi
    if [[ "$path" =~ \.(c|cc|cpp|cxx|h|hpp|hh)$ ]] || [[ "$path" =~ ^(src|source|app)/ ]]; then
        return 30
    fi
    if [[ "$path" =~ ^(test|tests)/ ]]; then
        return 10
    fi
    if [[ "$path" =~ ^(doc|docs)/ ]] || [[ "$path" =~ ^README ]]; then
        return 20
    fi
    return 0
}
classify_path "doc/README.md"
echo "Result: $?"
