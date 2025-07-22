# vglog-filter FAQ

## What does vglog-filter do?
It deduplicates and filters Valgrind log files, making it easier to spot unique memory errors and issues by removing redundant or repeated blocks.

## What is the default marker and why is it used?
The default marker is `Successfully downloaded debug`. By default, only log entries after the last occurrence of this marker are processed. This helps focus on the most recent run or relevant section of the log.

## How do I keep all log entries?
Use the `-k` or `--keep-debug-info` option to process the entire log file, ignoring the marker.

## What does the depth option do?
The `-d N` or `--depth N` option controls how many lines are used to generate the signature for deduplication. A higher depth means more context is considered. `0` means unlimited depth.

## How do I see the raw, unscrubbed log blocks?
Use the `-v` or `--verbose` option to disable address and `at:` scrubbing.

## What if my log uses a different marker?
Use the `-m S` or `--marker S` option to specify a custom marker string.

## What happens if the input file cannot be opened?
The tool will print an error message and exit with a non-zero status.

## Can I use vglog-filter with logs from tools other than Valgrind?
It is designed for Valgrind logs, but may work with similar formats if the error blocks match the expected patterns. 