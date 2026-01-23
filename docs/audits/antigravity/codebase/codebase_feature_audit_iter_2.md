# Codebase Feature Audit (Iteration 2)

## 1. Existing Capabilities & Gaps

### 1.1 Deduplication Semantics (`uniqueOutput`)
- **Status**: `Options::uniqueOutput` defaults to `false`.
- **Reality**: `LogProcessor::flush` *unconditionally* uses `seen.insert(key)` to filter output. Only the first occurrence of a signature is written.
- **Gap**: The tool effectively enforces "Unique Output" always, ignoring the flag.
- **Requirement**: 
    - If `uniqueOutput` is **false** (default), should we output *all* entries? 
    - *Correction*: Valgrind noise is high. Usually users *want* dedup. 
    - Maybe the flag should be inverted? `--show-all`? 
    - Or maybe `uniqueOutput` was intended to mean "Deduplicate output". If so, default should be `true`? Or if default is `false`, then current behavior (always dedup) is wrong?
    - **Decision**: In Iteration 2, we will adhere to the flag.
        - `uniqueOutput = true`: Deduplicate.
        - `uniqueOutput = false`: Print every error occurred.
        - **Note**: This arguably changes default behavior if we flip the switch. We must be careful.
        - *Better approach*: Keep Deduplication as default (it's a filter, after all). Rename flag to `--show-duplicates` or `--no-dedup`? 
        - Or, strictly implement `uniqueOutput` as "Enable deduplication". If so, default `false` means "show all". 
        - Given it's a "Filter" tool, deduplication is a primary feature.
        - Let's propose: Change `uniqueOutput` to be `true` by default? Or implement `--all` to disable it.
        - Let's stick to the existing flag `uniqueOutput` and make it control the logic. Default `false` -> Print All. (This might be noisy, but correct according to flag). 
        - *Alternative*: Maybe the original author meant `true` by default?
        - Let's assume we want to support "Print All" mode.

### 1.2 Source Loading Performance (`contextLines`)
- **Status**: `SourceLoader::loadContext` opens and scans the file from scratch for every query.
- **Gap**: High IO overhead for logs with many errors in the same source file.
- **Proposal**: Implement a file caching mechanism (`SourceCache`) to keep recently used files in memory (LRU or simple map).

### 1.3 JSON Output Array
- **Status**: Implemented in Iteration 1 updates to `LogWriter`.
- **Action**: Verify behavior with multiple inputs.

## 2. Missing Features

### 2.1 Config Dump Completeness
- **Status**: `dump_config_to_file` in `main.cpp` misses Iteration 2 fields (`unique`, `context`, `json-array`).
- **Proposal**: Update dumper.

## 3. Plan for Iteration 2
1. **Logic Fix**: Make deduplication conditional on `uniqueOutput` (or inverse).
   - *Refined Plan*: Rename `uniqueOutput` to `deduplicate` (default true). Or keep `uniqueOutput` and check it.
   - Let's check `cli_parser.cpp` default. It's `false` in `options.h`.
   - We will implement logic: `if (!opt.uniqueOutput) { print; } else { check seen; }`.
   - Wait, if default is `false`, then "vglog-filter" currently prints nothing if we fix it? No, currently it prints unique.
   - If we fix it to respect `false`, it will print *everything*. This is a behavior change.
   - We will implement this behavior change to respect the API.
2. **Optimization**: Implement `SourceCache` in `SourceLoader`.
3. **Refinement**: Update Config Dump.
