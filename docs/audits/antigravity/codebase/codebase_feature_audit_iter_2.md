# Codebase Feature Expansion - Iteration 2 Audit

## 1. Existing Capabilities & Status
Iteration 1 formalized the codebase with `camelCase` and fixed a critical memory leak.
- **SourceLoader**: Basic in-memory caching is implemented (`std::map<string, CachedFile>`).
- **Options**: Struct-based configuration with some validation logic mixed in.
- **LogProcessor**: Uses `LineBuffer` for safety.

## 2. Capability Gaps and Issues
- **SourceLoader Caching**: The current implementation loads the *entire file* into memory (`CachedFile::lines`). For large source files (e.g., 100MB generated C++), this is inefficient if only 5 lines are needed.
  - **Risk**: OOM on large source trees.
  - **Refinement**: Implement a "smart" loader or at least an LRU eviction or limit the cache size. But given the scope "Add optional features that improve correctness, safety, or usability", preventing OOM is a safety feature.
- **Options API**: `Options` is a raw struct. `OptionsBuilder` exists (saw in file list) but isn't widely used? `include/options_builder.h` should be checked.
- **Usability**: `Options::validate` throws `runtime_error`. We might want `Options::isValid()` or more granular errors.

## 3. Design Proposal for Iteration 2
### 3.1. SourceLoader Hardening
- **Feature**: Add `maxCacheBytes` limit to `SourceLoader`.
- **Logic**: Track total bytes loaded. If > limit, clear cache (simple sweep) or LRU.
- **Implementation**:
  ```cpp
  class SourceLoader {
      size_t totalBytes = 0;
      static constexpr size_t MAX_CACHE_BYTES = 50 * 1024 * 1024; // 50MB
      // ...
  };
  ```

### 3.2. Options Builder Integraiton
- Check `include/options_builder.h`. If it's incomplete, finalize it.
- **Goal**: Fluent API for `Options` creation in tests and library usage.

### 3.3. Refinement
- **LogProcessor**: Ensure `logDebug` is used consistently.
- **Output**: Ensure JSON output correctly handles the new `verbose` flag if applicable (maybe verbose means including raw lines in JSON too?). Inspect `LogWriter`.

## 4. What Changed Since Last Iteration
- `file_utils` and `signal_handler` renamed.
- `verbose` flag added.
