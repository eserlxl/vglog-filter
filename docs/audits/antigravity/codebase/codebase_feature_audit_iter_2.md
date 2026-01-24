# Codebase Feature Audit (Iteration 2)

## 1. Existing capabilities that are under-exposed or incomplete
- **Configuration Loading**: `ConfigLoader` supports basic keys but ignores `includeSourcePaths` (commented out as "files").
- **Options Dump**: `Options::dump` is marked as "incomplete". It manually prints JSON. It should drive off a serializer or helper.
- **JSON Construction**: `LogWriter` and `LogProcessor` manually concat strings for JSON. This is error-prone and repetitive. A `JsonBuilder` abstraction is implied.
- **CLI Usage**: `usage()` function is a long sequence of `fputs`/`fprintf`. It's hard to read and maintain.

## 2. Missing features logically implied by current design
- **Signal Safety in Parallel Mode**: `LogProcessor::processStreamParallel` (if enabled via `--jobs`) does not appear to check `SignalHandler::isStopRequested()` in its reader loop, unlike the sequential `processStream`.
- **JSON Helper**: `LogWriter` constructs JSON manually. A helper class `SimpleJsonBuilder` would clean this up significantly.

## 3. API usability gaps and misuse risks
- **`Options` Validation**: `validate()` checks rotation but could check conflicting flags (e.g. `json` vs `text` stats format consistency).

## 4. Areas that must remain unchanged
- **`LogEntry`**: Stable.
- **`ThreadPool`**: Stable.

## 5. What changed since last iteration
- Added `ColorMode`, `Version`, `ExitCodes`. All working.
- `TimeUtils` is now robust.
