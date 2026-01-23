# Codebase Feature Design (Iteration 2)

## 1. `Options::uniqueOutput` Semantics
- **Issues**: Currently `LogProcessor` dedoubles by default (using `seen`). Flag is ignored (defaults to false).
- **Proposal**:
    - If `uniqueOutput` is `true` (default should be false in options, but user must enable it?), we print unique.
    - **Change**: `LogProcessor::processEntry` uses `seen` *only* if `opt.uniqueOutput` is true.
    - **Default**: Since `uniqueOutput` initializes to `false` in `Options.h`, standard behavior becomes "Print All". This is a change from current behavior (which defaults to dedup).
    - **Mitigation**: Update `Options` default to `true`? Or accept that currently `Options::uniqueOutput` is just unused.
    - **Decision**: Set `uniqueOutput` default to `true` in `Options`. Rename flag to `--no-unique` / `--all` if strictly needed, but `unique` flag exists.
    - **Actually**: The existing flag is `--unique`. It presumably means "turn on uniqueness".
    - So if `uniqueOutput` is false (default), it *should* print everything.
    - We will implement this: `writeEntry` unconditionally if `!uniqueOutput`. If `uniqueOutput`, check `seen`.

## 2. Source Loading Optimization (`SourceCache`)
- **Problem**: `SourceLoader::loadContext` opens file on every call.
- **Design**:
    - `SourceLoader` becomes stateful or uses a static cache?
    - `LogProcessor` owns `SourceLoader` instance? Currently `SourceLoader` has static method `loadContext`.
    - **Change**: Convert `SourceLoader` to a class with instance state (LRU cache of file contents).
    - **Integration**: `LogProcessor` holds a `SourceLoader` instance.

## 3. Config Dump Update
- **Goal**: Export `jsonArray`, `deduplicate`, `contextLines`.
- **Implementation**: Add fields to `dump_config_to_file`.

## 4. Input Validity
- **Check**: Verify files exist in `process_input_files` before passing to processor, to warn early.

## 5. Updates to `Options`
- `uniqueOutput` default is `false`. We will NOT change it to `true` to match current behavior. Instead, we will implement the flag. If user runs without `--unique`, they get ALL duplicates. This matches "cat file | vglog-filter" expectation (stream processing usually doesn't dedup unless asked).
- **Note**: Current behavior (dedup always) might be considered a "bug" regarding the flag existence.

## 6. Testing
- **New Test**: `test_features_iter2.cpp`
    - Test unique vs non-unique output.
    - Test SourceLoader caching (mock or performance test? Basic logic test is fine).
