# Codebase Audit (Iteration 3)

## 1. Refactoring Opportunities
- **Config Loading**: `load_config` is currently a free function in `main.cpp`. It parses JSON using regex. It validates options directly.
    - *Improvement*: Move to `OptionsBuilder` or a new `ConfigLoader` class. This cleans up `main.cpp` and makes config loading testable.
- **LogWriter Coupling**: `LogProcessor` depends on the concrete `LogWriter` class. This makes unit testing `LogProcessor` difficult (requires file I/O).
    - *Improvement*: Extract `ILogWriter` interface. Allows mocking output in tests.

## 2. Performance
- **String Copies**: `LogProcessor::processLine` and `parseEntry` create many temporary strings.
    - *Improvement*: Use `std::string_view` where possible, though `LogEntry` needs ownership.
    - *Low hanging fruit*: Pass strings by const ref (already doing this?).

## 3. Reliability
- **Error Handling**: `load_config` prints to stderr but doesn't throw or return error codes clearly.
- **Path Validation**: `sanitize_path` is basic.

## 4. Plan
- **Phase A**: Refactor `load_config` into `src/config_loader.cpp`.
- **Phase B**: Extract `ILogWriter` interface. Update `LogWriter` to implement it. Update `LogProcessor` to use it.
- **Phase C**: Add unit tests using `MockLogWriter`.
