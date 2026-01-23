# Codebase Feature Audit (Iteration 1)

## Existing Capabilities (Under-Exposed or Incomplete)
1.  **Thread Filtering**: `excludeThreads` exists, but there is no `includeThreads`. This makes "isolate thread X" workflows difficult.
2.  **PID Filtering**: `LogEntry` has `pid`, but `FilterConfig` offers no way to filter by PID (neither include nor exclude).
3.  **Timestamp Awareness**: The codebase ignores timestamps in Valgrind output (`--time-stamp=yes`), losing critical ordering/context vs other system logs.
4.  **Structured Stats**: `LogStats` collects error counts by PID and TID, but the CLI only has a generic `--detailed-stats` flag which may not be fully granular in JSON mode.

## Missing Features Logically Implied by Current Design
1.  **Symmetric Filtering**: If we can exclude threads, we should be able to include them. If we have PIDs, we should be able to filter them.
2.  **Primary Blame Frame**: Users generally care about the "first frame in my code". `LogEntry` parses frames but doesn't offer a helper to find the "blame" frame (first non-library frame, or first frame with line number).
3.  **Time Parsing**: `LogEntry` structure implies a faithful structured representation of the log, yet omits the timestamp field common in production runs.

## High-Risk Correctness or Safety Issues
1.  **Thread Safety**: `LogProcessor` is explicitly non-thread-safe. While acceptable for a CLI tool, this limits library usage.
2.  **Parser Strictness**: `LogParser::parseHeader` uses "relaxed" checks. This might misidentify content as headers in mixed streams.
3.  **Memory Limits**: `MAX_BLOCK_SIZE` is 10MB. Large monolithic blocks (e.g. from infinite recursion output) could trigger this, but the error message handling is basic exception throwing.

## API Usability Gaps
1.  **Configuration Construction**: `Options` is a large POD struct. Constructing it in tests or library usage is verbose. Builder pattern or fluent helpers would be better (Iteration 2 candidate).
2.  **LogEntry Inspection**: `hasFrameMatching` is good, but `getPrimaryFrame` is better for reporting.

## Missing Tests
1.  **Timestamp Parsing**: No tests for timestamped logs.
2.  **Complex Filter Combinations**: Need to verify `includeTypes` AND `excludeFunctions` behavior logic (AND vs OR vs Precedence).

## Areas Maintaining Status Quo
- **File I/O**: `std::istream` and `FILE*` dual support is good, efficient enough. No need to change to `mmap` or similar unless performance issues arise.
- **Regex Backend**: `std::regex` is used. Do not switch to `ctre` or `re2` unless performance is proven bottleneck (Iteration 2 optimization if needed).

## Changes Since Last Iteration
(N/A - This is Iteration 1)
