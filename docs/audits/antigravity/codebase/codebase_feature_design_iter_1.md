# Codebase Feature Design (Iteration 1)

## 1. Proposed New APIs

### 1.1 `include/exit_codes.h` (New Header)
Introduce standard exit codes to replace magic numbers `0` and `1`.
```cpp
namespace exit_codes {
    inline constexpr int SUCCESS = 0;
    inline constexpr int GENERIC_ERROR = 1;
    inline constexpr int INVALID_ARGUMENT = 2;
    inline constexpr int FILE_ERROR = 3;
    inline constexpr int MEMORY_LEAK_DETECTED = 4; // Use if strict mode fails
    inline constexpr int SIGNAL_INTERRUPT = 130;  // Standard SIGINT exit
}
```

### 1.2 `Options` Enhancement (`include/options.h`)
Add `ColorMode` to generalization `bool color`.
```cpp
enum class ColorMode { Auto, Always, Never };
// ...
struct Options {
    // ...
    ColorMode colorMode = ColorMode::Auto;
    // Deprecate bool color or sync it?
    // We will sync it: colorMode::Always/Auto -> color=true logic
    // ...
};
```
Add `bool version = false;` to `Options`.

### 1.3 `TimeUtils` Robustness (`include/time_utils.h`)
Change return type to `std::optional` to handle errors safely.
```cpp
// Returns std::nullopt on failure instead of -1
std::optional<int64_t> timestampToMsSafe(std::string_view ts);
```

## 2. Behavioral Contracts

### 2.1 CLI `--version`
- If `--version` is present, print version string (e.g. `vglog-filter v1.0.0`) and exit with `SUCCESS`.
- Ignore other flags if `--version` is primary action? Usually yes.

### 2.2 Signal Handling
- `LogProcessor` MUST check `SignalHandler::isStopRequested()` at every line or block processed.
- On stop: stop processing, flush remaining buffers (if possible/safe), and return.
- Main loop should exit with `SIGNAL_INTERRUPT` if stopped by signal? Or just partial success?
  - Design decision: If output was produced, maybe SUCCESS?
  - Better: If interrupted, we might have incomplete JSON.
  - "Graceful JSON closure" was mentioned in history. If we close JSON properly, it is a partial success.

### 2.3 Time Parsing
- `timestampToMs` should support:
  - `[Day] HH:MM:SS[.mmm]`
  - `YYYY-MM-DD HH:MM:SS` (optional)
  - Return `nullopt` if unparseable.

## 3. Backward Compatibility
- `bool color` in `Options` will be kept but synced with `ColorMode`.
- `timestampToMs` (old) can call `timestampToMsSafe` and return -1 for compat if we don't want to break call sites immediately. But "Iteration 1: Public API MAY change freely".
- So we will REPLACE `timestampToMs` with optional-returning version and fix call sites.

## 4. Required Tests
- `TestExitCodes`: Verify main returns correct codes.
- `TestVersion`: Verify `--version` output.
- `TestTimeUtils`: Add cases for invalid times, date-prefixed times.
- `TestSignalInterrupt`: Mock signal (set atomic flag) and ensure `LogProcessor` returns early.
