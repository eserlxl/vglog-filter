# Codebase Feature Audit (Iteration 1)

## 1. Existing Capabilities
-   **Core Processing**:
    -   Robust Valgrind and ASAN log parsing.
    -   Memory-efficient stream processing for large files.
    -   Deduplication based on configurable stack depth.
-   **Filtering**:
    -   Comprehensive filtering by Type, Stack Pattern, Function, Source Path, PID, and Thread ID.
    -   Regex support for advanced matching.
    -   Includes and Excludes logic.
-   **Output**:
    -   Supports Text, JSON, HTML, and Markdown formats.
    -   Basic "Diff" summary output.
-   **Configuration**:
    -   CLI and JSON file configuration loading.
-   **Concurrency**:
    -   Basic ThreadPool implementation.
    -   Parallel processing path for non-streaming mode.

## 2. Missing Features (Latent/Implied)
Based on the current architecture, the following features are naturally implied but missing:

1.  **Expanded Output Formats**:
    -   **CSV Output**: Critical for spreadsheet analysis and reporting. Missing `CsvLogWriter`.
    -   **YAML Output**: Useful for configuration-driven pipelines and human readability. Missing `YamlLogWriter`.
    -   **JSON Diff**: The `DiffEngine` produces a summary, but cannot export the diff results (New/Fixed/Common) as a machine-readable JSON file.
2.  **Output Compression**:
    -   Input files support transparent `.gz` decompression.
    -   **Output files** do NOT support transparent compression. Users processing massive logs must pipe to `gzip`. Adding transparent `.gz` output support would complete the I/O symmetry.
3.  **Detailed Metrics Export**:
    -   `LogStats` are collected but export options are limited (basic text or JSON dump). Expanding to a more formal "Report" structure would be beneficial.

## 3. High-Risk Issues & Technical Debt
1.  **LogProcessor Complexity**:
    -   `LogProcessor` handles parsing, filtering, state management, threading, and reporting. It is approaching "God Class" status (589 lines of mixed logic).
    -   **Recommendation**: Extract `ParallelProcessor` logic or `Pipeline` abstraction in future. (Out of scope for Iter 1 feature expansion, but noted).
2.  **PID/TID Type Inconsistency**:
    -   `LogEntry` uses `std::string` for PID and `std::optional<int32_t>` for TID. Config uses `int32_t` for PID filters.
    -   **Risk**: Conversion errors (seen in `LogFilter` `try/catch` blocks).
    -   **Mitigation**: Standardize on a strong `ProcessId` / `ThreadId` type or consistent primitive.

## 4. API Usability Gaps
1.  **LogWriter Interface**:
    -   `ILogWriter` is simple but functional. Adding new formats requires implementing `writeEntry`, `writeStats`, etc.
    -   No "Factory" for creating writers based on extension/enum, leading to manual `if/else` chains in `main.cpp`.
2.  **Diff Engine Exposure**:
    -   `DiffEngine::compare` returns a `DiffResult`. There is no dedicated `IDiffWriter` interface, leading to ad-hoc printing in `main.cpp`.

## 5. Missing Tests
-   **Compression Output**: No tests for writing compressed files (feature missing).
-   **Format Validation**: Existing tests check `JsonWriter`, `HtmlWriter`, but need tests for new `Csv`/`Yaml` writers.
-   **Diff JSON**: No tests for structured diff output.

## 6. Proposed Scope for Iteration 1
1.  **Implement `CsvLogWriter` and `YamlLogWriter`**.
2.  **Implement `GzipOutputStream` support** in `file_utils` and integrate with `LogWriter`.
3.  **Implement `JsonDiffWriter`** (or extend `DiffEngine` to support JSON export).
4.  **Refactor `LogWriter` creation** into a factory to clean up `main.cpp`.
