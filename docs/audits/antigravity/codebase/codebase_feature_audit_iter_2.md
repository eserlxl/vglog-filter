# Codebase Feature Audit (Iteration 2)

## 1. Existing Capabilities (Under-exposed or Incomplete)
- **JSON Output**: Currently produces **JSON-L** (newline-delimited JSON objects). There is no support for generating a standard JSON array file (`[{},{}]`), which is often expected by JSON parsers.
- **LogEntry API**: `LogEntry` is a "dumb" struct. Consumers (like `LogFilter`) have to iterate `stackFrames` manually to check conditions.
- **Parsing**: `LogParser` handles standard Valgrind frames well, but `LogEntry` doesn't expose synthesized data (e.g., "list of all source files in this error").

## 2. Missing Features Logically Implied by Current Design
- **JSON Array Mode**: If `--json` is supported, `--json-array` is a logical extension for non-streaming consumers.
- **Semantic Helpers**: `LogEntry` should answer questions like `hasStackFrameMatching(regex)` or `involvesFile(string)`.

## 3. High-Risk Correctness or Safety Issues
- **JSON Validity**: In stream mode, if the process crashes, a JSON Array file might not be closed (`]`). JSON-L is safer logging format, but Array is often requested. We should document this trade-off.
- **Memory**: `LogEntry::stackTrace` (raw strings) and `stackFrames` (structured) duplicate data. `stackFrames` is optional/parsed on demand? No, currently parsed if possible.

## 4. API Usability Gaps
- **Consumer Code**: Writing a custom analysis tool using `vglog-filter` as a library requires writing loops over `stackFrames`.
- **Options**: `detailedJson` adds fields, but doesn't change structure.

## 5. Changes Since Last Iteration
- `LogFilter` now exists. It can be simplified by delegating logic to `LogEntry` methods.
- `Options` is hierarchical. We should add `OutputConfig`? Or just add to root `Options` for now (Iteration 2 allows API changes).

## 6. Plan
- Enhance `LogEntry` with helper methods.
- Refactor `LogFilter` to use them.
- Update `LogWriter` to support JSON Array output.
- Add `--json-array` flag.
