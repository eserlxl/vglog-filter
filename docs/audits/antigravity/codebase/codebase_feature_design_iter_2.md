# Codebase Feature Design (Iteration 2: Parallel Processing)

## Goal
Improve throughput for large log files by parallelizing the parsing and filtering of independent error blocks.

## Audit
- **Current State**: `LogProcessor::processStream` reads line-by-line, appends to `raw`, calls `flush` (which parses and filters), then clears state.
- **Bottleneck**: Single-threaded parsing. Regex (if used) and string manipulation (`scrubLine`) are CPU intensive.
- **State**: `LogProcessor` maintains `raw`, `sig`, `seen`, `pendingBlocks`, `stats`. `seen` (unordered_set) is the main synchronization point for uniqueness.

## Architecture: Producer-Consumer Pipeline

### 1. `BlockReader` (Producer)
- Reads the stream line-by-line.
- Detects `isBlockStart` using the configured `IParser`.
- Accummulates lines into a `RawBlock` struct (std::string content, line number start).
- Pushes `RawBlock` to a thread-safe Queue.

### 2. `BlockProcessor` (Consumer/Worker)
- Pops `RawBlock` from Queue.
- Executes `parser->parseBlock()`.
- Executes `filter.shouldKeep()`.
- Returns `ProcessedResult` (LogEntry, bool kept).

### 3. `ResultCollector` (main thread or separate)
- Collects `ProcessedResult`.
- Checks `seen` set (uniqueness).
- Updates `stats`.
- Writes to `ILogWriter`.

## Data Structures
```cpp
struct RawBlock {
    std::string content;
    std::string pid; // Captured from context if needed
    size_t startLine;
};

struct ProcessingResult {
    LogEntry entry;
    bool kept;
    // Stats info
};
```

## Implementation Plan
1.  **Refactor `LogProcessor`**:
    - Extract `readLoop` that identifies blocks.
    - Extract `processBlock(RawBlock)` that returns result.
2.  **Concurrency**:
    - Use `std::deque` + `mutex` + `condition_variable` or a simple thread pool.
    - Since `LogFilter` is read-only (mostly), it can be shared or copied. `seen` modification must be serialized.
3.  **Output Ordering**:
    - Parallel processing may reorder blocks.
    - If order matters (it usually does for logs), the collector must re-sequence based on `startLine` or sequence ID.
    - *Simplification*: For Iteration 2, strict order might not be critical, but `vglog-filter` output is usually linear.
    - *Re-sequencing*: Use a priority queue in Collector or just process in batches?
    - *Alternative*: `std::async` for each block? Overhead might be high.
    - *Selected Strategy*: Dedicated `WorkQueue` and `ResultQueue`. Collector pops from `ResultQueue` (which might be out of order).
    - If strict order is required, we tag each block with `seqId`. Collector expects `nextSeqId`. If `ResultQueue` has `seqId > next`, buffer it.

## Changes
- Modify `Options`: Add `size_t jobs = 1`.
- Modify `LogProcessor`:
    - `processStreamParallel(std::istream&, size_t jobs)`.
    - Internal `Queue` class.

## Verification
- `test_parallel_consistency.cpp`: Process a large file with `jobs=1` and `jobs=4`. Verify output (json/text) content is identical (order might differ slightly if not enforced, but we will target enforced order).
