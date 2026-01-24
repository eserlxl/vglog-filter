# Codebase Feature Design (Iteration 2)

## 1. Correct Time Filtering
### Problem
Lexicographical comparison of timestamps (`9:00` > `10:00`) is incorrect.
### Proposal
Implement `parseTimestampMs`:
- Parse `HH:MM:SS.mmm` or `HH:MM:SS` into `int64_t` milliseconds from midnight.
- Handle flexible formats (optional hours, optional ms).
- Use `std::chrono` or simple math.
- Update `isAfter`/`isBefore` to compare integers.

## 2. Scalable Configuration (File Lists)
### Problem
Passing dozens of types to exclude via CLI (`-e Type1 -e Type2 ...`) is cumbersome. The JSON config file is hard to update dynamically.
### Proposal
Add CLI flags to read lists from files:
- `--exclude-types-file <path>`
- `--include-types-file <path>`
- `--exclude-functions-file <path>`
- `--include-functions-file <path>`

Implementation:
- `cli_parser.cpp`: Add new flags.
- `options.cpp`: In `validate()` or helper, read files and append to `FilterConfig` vectors.
- Reuse `file_utils::read_file_lines`.

## 3. Help Message Improvement
### Problem
`usage()` is manually maintained and often out of sync.
### Proposal
Centralize option definitions. But for this iteration (Iter 2), just manual update is fine, but make it formatted better.
Actually, let's focus on the Lists and Time.

## 4. Helper Abstractions
- `TimeParser`: Dedicated class/namespace.
- `ListLoader`: Helper to load unique non-empty lines from file.

## Plan
1.  Implement `src/time_utils.cpp`: `timestampToMillis()`.
2.  Update `cli_parser.cpp` with new flags.
3.  Update `main.cpp`/`options.cpp` to load files.
