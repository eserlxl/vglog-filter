#!/bin/bash
set -Eeuo pipefail
classify_path() {
    local path="$1"
    if [[ "$path" =~ ^(build|dist|out|third_party|vendor|.git|node_modules|target|bin|obj)/ ]] || [[ "$path" =~ \.(lock|exe|dll|so|dylib|jar|war|ear|zip|tar|gz|bz2|xz|7z|rar)$ ]]; then
        echo "0"
        return
    fi
    if [[ "$path" =~ \.(c|cc|cpp|cxx|h|hpp|hh)$ ]] || [[ "$path" =~ ^(src|source|app)/ ]]; then
        echo "30"
        return
    fi
    if [[ "$path" =~ ^(test|tests)/ ]]; then
        echo "10"
        return
    fi
    if [[ "$path" =~ ^(doc|docs)/ ]] || [[ "$path" =~ ^README ]]; then
        echo "20"
        return
    fi
    echo "0"
}
doc_result=$(classify_path "doc/README.md")
echo "doc result: $doc_result"
src_result=$(classify_path "src/main.cpp")
echo "src result: $src_result"
test_result=$(classify_path "test/test.cpp")
echo "test result: $test_result"
