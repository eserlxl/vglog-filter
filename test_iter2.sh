#!/bin/bash
set -e
BIN="./build/bin/Debug/vglog-filter"

echo "Running Iteration 2 Verification..."

# 1. Test Exclude Type File
echo "Verifying File Lists..."
echo "Invalid read" > exclude.txt
echo "==1== Invalid read" > input_list.log
echo "==1== Invalid write" >> input_list.log

$BIN --exclude-type-file exclude.txt -o output_list.txt input_list.log
echo "--- Output Content ---"
cat output_list.txt
echo "----------------------"
if grep -q "Invalid read" output_list.txt; then
  echo "FAIL: FilteredType should be excluded"
  exit 1
fi
if grep -q "Invalid write" output_list.txt; then
  echo "PASS: KeptType preserved"
else
  echo "FAIL: KeptType missing"
  exit 1
fi

# 2. Test Time Integer Comparison
echo "Verifying Time Integer Comparison..."
# Log time: 9:00:00 (09:00:00)
# Threshold: 10:00:00
# Expected: 9 < 10.
# If we ask for --after 10:00:00, 9:00:00 should be excluded.
# If string comparison (bad): "9" > "1", so it would include it.
echo "==1== 09:00:00 ErrorEarly" > input_time.log
echo "==1== 11:00:00 ErrorLate" >> input_time.log

$BIN --after "10:00:00" -o output_time.txt input_time.log

if grep -q "ErrorEarly" output_time.txt; then
  echo "FAIL: 09:00:00 included despite being before 10:00:00. Integer comparison failed?"
  # Wait, standard string comp "09" < "10". This works even in Lex.
  # We need a case where Lex fails.
  # "9:00" vs "10:00"
  # Lex: "9" > "1".
  # Int: 9 < 10.
  exit 1
fi

echo "Testing Lex fail case..."
echo "==1== 9:00:00 ErrorNine" > input_lex.log
$BIN --after "10:00:00" -o output_lex.txt input_lex.log
if grep -q "ErrorNine" output_lex.txt; then
  echo "FAIL: 9:00:00 included. Lex comp used?"
  exit 1
else
  echo "PASS: 9:00:00 excluded correctly."
fi

echo "Iteration 2 Verified!"
