# Codebase Feature Design (Iteration 2)

## 1. Deduplication (--unique)
**Goal**: Suppress duplicate error blocks.
**Design**:
- `Options`: Add `bool uniqueOutput = false`.
- `LogProcessor`: In `processLine` (or where entries are finalized), check `options.uniqueOutput`.
- Logic:
  - Existing `seen` set tracks signatures.
  - If `options.uniqueOutput` is true AND signature is already in `seen` -> Skip `writer->writeEntry`.
  - Ensure `uniqueBlocks` stat is still incremented correctly (it tracks *uniqueness*, not printed count? Actually uniqueBlocks counts distinct signatures encountered. `blocksFound` counts total).
  - So logic: `if (is_new) { seen.insert; unique++; write(); } else { if (!uniqueOutput) write(); }`.

## 2. Source Context (--context N)
**Goal**: Show source code around the error.
**Design**:
- `Options`: Add `int contextLines = 0`.
- `LogProcessor`:
  - Identify primary stack frame (Frame 0 usually).
  - If `contextLines > 0` and entry has valid file/line:
    - Call `SourceLoader::loadContext(file, line, N)`.
    - Returns `vector<string>` or formatted string.
    - Append to `LogEntry`.
- `LogEntry`: Add `std::vector<std::string> sourceContext`.
- `LogWriter`:
  - JSON: Output array `sourceContext`.
  - Raw: Print lines prefixed with `>` or similar.

## 3. Multiple Inputs
**Goal**: Process list of files.
**Design**:
- `Options`: Add `std::vector<std::string> inputFiles`.
- `cli_parser`: Collect non-option arguments into `inputFiles`.
- `main.cpp`:
  - Iterate `inputFiles`.
  - Reuse `LogProcessor` instance (so stats and deduplication work across files).
  - Extract file processing logic to `process_file(processor, path)`.

## 4. API Changes
```cpp
struct Options {
    // ...
    bool uniqueOutput = false; // --unique
    int contextLines = 0;      // --context N
    std::vector<std::string> inputFiles; 
};

struct LogEntry {
    // ...
    std::vector<std::string> sourceContext;
};
```
