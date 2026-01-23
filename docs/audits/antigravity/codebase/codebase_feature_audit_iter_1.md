# Codebase Feature Audit (Iteration 1)

## 1. Existing Capabilities (Under-exposed or Incomplete)
- **Filtering System**: valid `exclude` and `include` logic exists for Types, Functions, PIDs, Threads. However, `excludeStackPatterns` (regex on stack) exists, but **`includeStackPatterns`** is missing. This checks if *any* frame matches a regex to include the entry.
- **Statistics**: The system collects stats (`linesRead`, `blocksFound`, `errorCounts`), but only prints them to `stderr` or a text format. There is no structured **JSON export for statistics**, limiting integration with dashboards.
- **Input Processing**: The system handles large files and streams, but lacks **Time-based filtering** (e.g., "show errors after 10:00"). Timestamps are parsed into `LogEntry`, but not used for filtering.
- **Output**: The output is plain text or basic JSON. **Colorized output** for TTY is missing, which is a standard feature for CLI log tools.

## 2. Missing Features Logically Implied
- **Configuration File**: The tool relies entirely on CLI arguments. As options grow (exclusions, inclusions, limits), a **JSON/YAML config file** is a natural extension to share presets.
- **Time Window**: `LogEntry` has a `timestamp` field. Users naturally expect to filter logs by time (after/before).
- **Inverse Stack Matching**: Users often want to "find all errors passing through `my_function`". `includeFunctions` does exact substring match, but regex support for inclusion is implied by `excludeStackPatterns`.

## 3. High-Risk Correctness or Safety Issues
- **Regex Performance**: `LogFilter` compiles regexes in constructor. If many regexes are provided, `std::regex` might be slow. No immediate fix needed for Iter/1, but worth noting.
- **Input Validation**: `cli_parser` does basic validation, but complex combinations (e.g. `json` + `interactive`) might need stricter checks.
- **Large Line Handling**: `MAX_LINE_LENGTH` is 1MB. This is safe, but could be configurable.

## 4. API Usability Gaps and Misuse Risks
- **Verbose CLI**: The number of exclusion flags is growing. Helper to load from file is needed.
- **Stats Visibility**: `monitorMemory` prints to stderr but isn't very structured.

## 5. Missing Tests
- **Time Filtering Tests**: usage of timestamp parsing needs verification.
- **Color Output Tests**: Need to verify ANSI codes are not emitted when not a TTY (or forced).
- **Config File Tests**: Need to verify priority (CLI overrides Config).

## 6. Areas to Remain Unchanged
- **Core Parsing Logic (`LogParser`)**: Stable and handles Valgrind format well.
- **Canonicalization**: well-tested integration.

## 7. Changes Since Last Iteration
- N/A (Iteration 1)
