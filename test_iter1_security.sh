#!/bin/bash
set -e

BIN="./build/bin/Debug/vglog-filter"

echo "Running Iteration 1 Verification..."

# 1. Test GitHub Actions Output
echo "==123== Invalid read of size 4
==123==    at 0x4C2: malloc (vg_replace_malloc.c:299)" > input_gh.log

$BIN --github-actions input_gh.log > output_gh.txt
cat output_gh.txt

if grep -q "::error file=vg_replace_malloc.c,line=299,title=Invalid read" output_gh.txt; then
  echo "PASS: GitHub Actions format correct"
else
  echo "FAIL: GitHub Actions format incorrect"
  exit 1
fi

# 2. Test Signal Handling
echo "Testing Signal Handling..."
rm -f output_sig.json

# Start process in background reading from pipe
# We explicitly use stream mode
(
  echo "==999== Invalid write of size 8"
  echo "   at 0x123: main (main.c:50)"
  sleep 10
) | $BIN --json-array --stream > output_sig.json &
PID=$!

sleep 2
echo "Sending SIGINT to $PID..."
kill -SIGINT $PID
wait $PID || true # wait returns status of killed process

echo "Checking output..."
cat output_sig.json

if grep -q '{"type":"record"' output_sig.json; then
    if [[ $(tail -c 1 output_sig.json) == "]" ]]; then
        echo "PASS: JSON Array valid and closed."
    else
        echo "FAIL: JSON Array NOT closed (missing ']')."
        exit 1
    fi
else
    echo "FAIL: No records output before signal."
    exit 1
fi

echo "Iteration 1 Verified!"
