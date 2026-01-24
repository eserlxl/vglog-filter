# Codebase Feature Design - Iteration 1

## 1. Goal
Formalize the codebase by enforcing `camelCase` consistency, eliminating `kPascalCase` (if any), removing `std::cerr` pollution, and fixing critical safety issues (memory leaks).

## 2. Proposed API Changes

### 2.1. File Utils (`include/file_utils.h`)
Refactor snake_case to camelCase:
```cpp
// [MODIFY]
size_t getFileSizeBytes(const std::string& filename); // was get_file_size_bytes
void reportProgress(size_t current, size_t total, const std::string& task); // was report_progress
```

### 2.2. Signal Handler (`include/signal_handler.h`)
Refactor snake_case to camelCase:
```cpp
// [MODIFY]
namespace SignalHandler { // Ensure Namespace/Class consistent naming
    void install();
    bool isStopRequested(); // was is_stop_requested
}
```

### 2.3. Options (`include/options.h`)
Add verbosity control:
```cpp
// [MODIFY] struct Options
bool verbose = false; // New field
```

### 2.4. Log Processor (`include/log_processor.h`)
Add debug logging helper and clean up.
```cpp
// [MODIFY]
class LogProcessor {
    // ...
private:
    void logDebug(std::string_view msg) const;
    // ...
};
```

## 3. Implementation Details

### 3.1. Memory Safety (`src/log_processor.cpp`)
Fix memory leak in `processStreamCFile`.
Construct a custom RAII wrapper for the `char* buf` used by `::getline`.
```cpp
struct LineBuffer {
    char* data = nullptr;
    size_t cap = 0;
    ~LineBuffer() { free(data); }
};
// Loop:
LineBuffer lb;
ssize_t read = ::getline(&lb.data, &lb.cap, fp);
// ...
```
This guarantees `free` is called even if `validate_line_length` throws.

### 3.2. Standardizing Internal Helpers
Rename all `snake_case` static functions in `src/*.cpp` to `camelCase`:
- `is_digit` -> `isDigit`
- `validate_line_length` -> `validateLineLength`
- etc.

## 4. Backend Compatibility
- **API Breakage**: Yes, for `file_utils` and `signal_handler`. Since these are internal libraries, we update all call sites within the repo (global search/replace).
- **Behavior**: No functional change desired, strictly refactoring + safety.

## 5. Required Tests
- **Compilation Check**: `make` must pass.
- **Regression**: `ctest` must pass (all existing tests).
- **Safety Verification**: No new test file needed strictly if we verify via code inspection, but ensuring `test_memory_leaks` runs is crucial.
