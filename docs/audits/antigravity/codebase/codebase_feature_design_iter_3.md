# Codebase Feature Design (Iteration 3)

## 1. Naming Standardization
- **Namespace**: `cli`
- **Function**: `parse_args` -> `ParseArgs` (to match `LogProcessor::ProcessLines` style if it existed, or just consistency).
  - Actually, `LogProcessor` uses `processLines` (camelCase).
  - So `cli::parseArgs` (camelCase).
  
## 2. Constants extraction
**File**: `src/log_writer.cpp`
```cpp
constexpr size_t JSON_BUFFER_RESERVE = 128;
constexpr size_t MB_IN_BYTES = 1024 * 1024;
```

**File**: `src/cli_parser.cpp`
```cpp
constexpr size_t ERROR_MSG_BUFFER = 64;
```

## 3. Include Cleanup
- Remove `<iostream>` where not used.
- Remove `<file_utils.h>` from `cli_parser.cpp`.

## 4. Type Safety
- `parse_nonneg_int` should return `int` (as is), but usage should `static_cast<size_t>` explicitly where target is `size_t`.

## Validation
- `cmake --build`
- `ctest`
- Manual check of `build/build.log` for reduced warning noise.
