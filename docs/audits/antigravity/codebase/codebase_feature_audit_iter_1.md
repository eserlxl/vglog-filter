# Codebase Feature Expansion - Iteration 1 Audit

## 1. Existing Capabilities & Status
The codebase has undergone previous expansion attempts (up to Iteration 3), resulting in a functional but partially verified state.
- **Core Processing**: `LogProcessor` handles Valgrind log parsing with `LogParser`.
- **Filtering**: `LogFilter` supports type, stack, source, and regex-based filtering (added in prev Iter 3).
- **Output**: `LogWriter` supports text, JSON, and GitHub Actions formats.
- **Testing**: A comprehensive suite exists (`test_features_iter3` passes), but `codebase_feature_verification_iter_3.md` is missing, implying incomplete formal verification.

## 2. Coding Standard Violations
The `USER_REQUEST` mandates `camelCase` and explicitly forbids `kPascalCase`.
- **Snake Case**: The `src/log_processor.cpp` file contains several internal helper functions using `snake_case`:
  - `is_digit`
  - `validate_line_length`
  - `validate_block_size`
  - `validate_pending_blocks_count`
  - `report_progress` (inferred from usage, need to check def)
- **Action**: These must be renamed to `camelCase` (e.g., `isDigit`, `validateLineLength`) to meet the formalization goal.

## 3. API Usability & Design Gaps
- **Hardcoded Debug Output**: `LogProcessor` writes directly to `std::cerr` ("DEBUG: ...").
  - This pollutes standard error and makes the library unusable in quiet tools.
  - **Proposed Fix**: Introduce a `verbose` or `debug` flag in `Options` and wrap debug prints in a conditional helper.
- **Member Encapsulation**: `LogProcessor` members like `raw`, `sig`, `pendingPid` are `private` but the internal state management (`clearCurrentState`, `resetEpoch`) is somewhat scattered.

## 4. Safety & Correctness
- **Lifetime Safety**: `LogProcessor` holds `const Options& opt`. This requires `Options` to outlive the processor. While valid for `main.cpp`, it's a constraint that should be documented or guarded.
- **Raw Pointers**: `processStreamCFile` takes `std::FILE*`. This is necessary for C-interop but usage of `::getline` with `std::free(buf)` is manual memory management.
  - **Action**: Verify exception safety. If `validate_line_length` throws, `buf` might leak?
  - `buf` is managed by `::getline`. If exception is thrown inside the loop, `std::free(buf)` at the end is SKIPPED.
  - **Critical Issue**: **Memory Leak on Exception**. If `validate_line_length` throws, `buf` (allocated by `getline`) is never freed.
  - **Fix**: Use `std::unique_ptr` with custom deleter or `defer` pattern (RAII) for `buf`.

## 5. Missing Test Coverage
- **Exception Safety**: No tests seem to cover the memory leak scenario in `processStreamCFile` upon exception.
- **Regex Edge Cases**: `test_features_iter3.cpp` covers basic inclusion/exclusion, but complex regexes or invalid regex handling (throwing `std::regex_error`?) need verification.

## 6. Plan for Iteration 1
- **Fix**: Memory leak in `processStreamCFile`.
- **Refactor**: Rename `snake_case` helpers to `camelCase`.
- **Enhance**: Add `Options::verbose` and silence `std::cerr`.
- **Verify**: Re-run all tests and add a test for the memory leak fix (using a mock or analyzing code).

## 7. What Changed Since Last Iteration
(Applicable for N > 1).
