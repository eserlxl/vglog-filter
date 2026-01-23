# Codebase Feature Audit (Iteration 3)

## Focus Area: Stability & Cleanup

## Identified Issues
### 1. Lint Warnings (Code Quality)
- **Magic Numbers**:
    - `log_writer.cpp`: `1024` (KB/MB conversion?).
    - `cli_parser.cpp`: `64` (buffer size?), `MAX_MARKER_LENGTH`.
    - Tests: `100`, `200`, `1024*1024`.
- **Naming Conventions**:
    - `parse_args` -> `ParseArgs` (if following LLVM/Google style? or project style?). Project style seems mixed. `LogProcessor` is CamelCase. `parse_header` is snake_case. `parse_marker` is snake_case. 
    - `LONG_OPTS` / `SHORT_OPTS`: Global constants.
    - `OPT_ROTATE_SIZE`: Enum constants.
- **Unused Headers**:
    - `iostream` in `log_writer.cpp` (using `fprintf`).
    - `file_utils.h` in `cli_parser.cpp` (if unused).

### 2. Semantic Stability
- **Implicit Conversions**: `parse_nonneg_int` (returns int) assigned to `size_t` (e.g. `opt.depth`). Should cast or change return type.
- **Error Handling**: `cli_parser` throws `runtime_error`. Main catches `std::exception`. This is good, but messages should be user-friendly.

## Proposed Plan for Iteration 3
1.  **Refactor Constants**: Move magic numbers to named constants.
2.  **Fix Lints**:
    - Remove unused headers.
    - safe_cast or explicit cast for numeric conversions.
    - Harmonize naming (Stick to snake_case for free functions if that's the pattern, or update to CamelCase if class methods).
        - `LogParser` uses `camelCase` methods (`parseHeader`).
        - `cli_parser` uses `snake_case` (`parse_args`).
        - Decision: Normalize to `camelCase` for public APIs to match `LogProcessor`/`LogParser`.
3.  **Documentation**: Ensure public headers have Doxygen-style comments.

## Verification
- Build should ideally have ZERO warnings in standard mode.
- `clang-tidy` warnings should be reduced (though 100% elimination might be overkill for this iteration, we target high-priority ones).
