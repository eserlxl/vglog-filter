# Codebase Feature Design (Iteration 1)

## Proposed New APIs

### 1. Extended Filtering (Symmetry)

**Header:** `include/options.h`

```cpp
struct FilterConfig {
  // Existing...
  std::vector<std::string> excludeTypes;
  std::vector<int32_t> excludeThreads;

  // NEW
  std::vector<int32_t> includeThreads;
  std::vector<int32_t> includePids;
  std::vector<int32_t> excludePids;
};
```

**CLI Flags:**
- `--include-thread N`: Only keep errors from thread N.
- `--include-pid N`: Only keep errors from PID N.
- `--exclude-pid N`: Exclude errors from PID N.

**Behavioral Contract:**
- `includeThreads`/`includePids`: XOR-like logic with other includes? OR logic?
- **Decision**: Logic follow existing pattern.
  - Excludes are applied FIRST (if match, drop).
  - Includes are applied SECOND (if specific list exists, must match at least one).
  - If multiple "include" lists are provided (e.g. types AND threads), what is the relationship?
  - **Proposed**: AND relationship between categories. (Must match Type Include AND Thread Include). With a category (e.g. multiple threads), it is OR.

### 2. Timestamp Support

**Header:** `include/log_entry.h`

```cpp
struct LogEntry {
  // Existing...
  std::optional<int32_t> tid;

  // NEW
  std::optional<std::string> timestamp; // Format: "HH:MM:SS.mmm" or similar
};
```

**Header:** `include/log_parser.h`

```cpp
struct HeaderResult {
  std::string pid;
  std::string errorType;
  std::optional<int32_t> tid;
  
  // NEW
  std::optional<std::string> timestamp;
};
```

**Parsing Logic:**
- Valgrind format: `==12345== 00:00:23: ...` or `==12345== 01:02:03.456 ...`
- Parser must detect time-like pattern after PID and before content.

### 3. LogEntry Helper

**Header:** `include/log_entry.h`

```cpp
  /**
   * @brief Returns the first stack frame that does NOT match exclusion patterns.
   * Useful for finding the "blame" frame in user code.
   */
  [[nodiscard]] const StackFrame* getPrimaryFrame(
      const std::vector<std::string>& excludePatterns = {}) const;
```

## Error Handling
- Invalid PID/Thread values in CLI throws `std::runtime_error` during `Options::validate` or parsing.
- Timestamp parsing failures result in `std::nullopt` (soft fail), preserving existing behavior.

## Backward Compatibility
- No breaking changes.
- New fields in structs are optional or vectors (default empty).
- Existing CLI flags work as before.

## Required Tests
1.  **Test Timestamp Parsing:**
    - Input: `==12345== 01:23:45 MyError...`
    - Verify `entry.timestamp` is "01:23:45".
2.  **Test PID/Thread Includes:**
    - Use `LogFilter` unit test.
    - entries with PID 100, 200. Config `includePids = {100}`. Verify 200 is dropped.
3.  **Test Primary Frame:**
    - Construct entry with frames: `[malloc, my_func, main]`. Exclude `malloc`. Result: `my_func`.
