# Codebase Feature Audit (Iteration 2)

## 1. Existing Capabilities
- **Deduplication Tracking**: `LogProcessor` already calculates `signature` blocks and tracks unique blocks in `stats.uniqueBlocks`. However, it does NOT expose an option to suppress duplicate output (it outputs everything).
- **File Input**: `main.cpp` processes a single file or stdin. Any additional arguments are ignored.
- **Source Paths**: `LogEntry` parses filename and line number. `path_validation` logic exists. But the tool does not attempt to read these source files to show context.

## 2. Missing Features (Complex Use Cases)
- **Output Deduplication**: Users analyzing massive logs want to see only unique errors. The mechanism exists (signatures), but the switch (`--unique`) is missing.
- **Multiple Inputs**: Batch processing is cumbersome (requires shell loop). The tool should accept `vglog-filter a.log b.log c.log` and merge/process them.
    - *Risk*: `LogWriter` resets header/footer/file on each instantiation. Need to share `LogWriter` or change `LogProcessor` lifecycle.
- **Source Code Context**: For a better debugging experience (like `grep -C`), the tool should optionally read the source file identified in the stack trace and display lines around the error.
    - *Complexity*: path resolution (relative vs absolute), permission, performance.

## 3. API Usability Gaps
- **Output Mode**: `LogWriter` assumes single file creation from scratch. Appending or sharing streams across multiple inputs needs refactoring.

## 4. Plan for Extensions
- **Options**: Add `unique` (bool), `contextLines` (int), `inputFiles` (vector).
- **LogProcessor**: Add logic to skip `writeEntry` if `unique` is set and signature seen.
- **LogProcessor**: Add logic to resolve source file and fetch context.
- **Main**: Loop over inputs properly.
