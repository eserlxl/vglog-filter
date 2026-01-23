# Codebase Feature Audit (Iteration 1)

## 1. Existing capabilities that are under-exposed or incomplete

### 1.1 Color Output
- **Status**: Basic "all-red" or "all-reset" logic exists in `LogWriter::writeEntry`.
- **Gap**: No semantic highlighting. Key elements like file paths, line numbers, function names, and addresses are not visually distinct, making manual reading difficult.
- **Proposal**: Implement a `Colorizer` utility to apply semantic coloring (e.g., specific colors for headers, source paths, memory addresses).

### 1.2 Configuration Management
- **Status**: `Options` structure exists and is populated via CLI. `config_loader` handles loading from file.
- **Gap**: No way to export the *current* effective configuration to a file. Users debugging strictly configured pipelines cannot easily "snapshot" the config.
- **Proposal**: Add `--dump-config <file>` to serialize the full `Options` state (including defaults and CLI overrides) to JSON.

### 1.3 Time Filtering
- **Status**: `timeAfter`/`timeBefore` exist as strings. Comparison is lexicographical.
- **Gap**: Lexicographical comparison relies on the log's timestamp format being sortable (e.g., "HH:MM:SS"). If Valgrind format varies or includes dates/microseconds in non-standard ways, this fails.
- **Proposal**: Formalize timestamp parsing in `LogParser` and use a comparable type (or normalized string) for filtering.

## 2. Missing features logically implied by current design

### 2.1 Symmetric Source Filtering
- **Status**: `excludeSourcePaths` exists in `FilterConfig`.
- **Implied Feature**: `includeSourcePaths` (Include only *specific* source files/directories). This is a natural counterpart for focused debugging.

### 2.2 Stats Output Flexibility
- **Status**: Stats can be written to a dedicated JSON file (`--stats-json`) or printed as text to stdout/file.
- **Implied Feature**: Allow printing stats in JSON format to *stdout* (e.g. `--stats-format=json`). This enables piping stats to other tools like `jq` without intermediate files.

## 3. High-risk correctness or safety issues

### 3.1 Strict timestamp dependency
- **Risk**: If functionality depends on `entry.timestamp` being present and it is missing (common in some Valgrind outputs or partial lines), behavior is to either drop or keep based on implicit logic.
- **Fix**: Define explicit behavior for missing timestamps when time filtering is active (e.g., "keep if missing" vs "drop if missing" mode, default to "drop" for strict time bounds).

## 4. API usability gaps and misuse risks

### 4.1 `LogEntry` Structure
- `startPattern`, `bytesHeadPattern` etc. are hardcoded in `LogProcessor`. They should be centralized or configurable constants to avoid drift if Valgrind output formats change.

## 5. Missing tests blocking safe feature expansion

- **Color Logic**: No tests for color codes (likely because it writes directly to stream). Need a test that captures output and verifies ANSI codes.
- **Config Dump**: New feature, will need tests.
- **Time Parsing**: Need specific unit tests for edge-case timestamp formats.

## 6. Areas that must remain unchanged
- **Core Loop**: `LogProcessor::processStream` handles buffering and logic efficiently. Do not rewrite the main loop unless necessary for correctness.
- **Regex Logic**: `LogFilter` regex compilation is correct (using `std::regex::optimize`).

## 7. Plan for Iteration 1
1.  **Refine Color**: Implement semantic syntax highlighting.
2.  **Config**: Implement `--dump-config`.
3.  **Filter**: Implement `includeSourcePaths`.
4.  **Time**: Hardening timestamp comparison.
