# Codebase Feature Design (Iteration 1)

## 1. Correctness: `is_digit` Fix
### Problem
`std::isdigit` is not `constexpr` and has UB for negative chars on some platforms.
### Proposal
Replace with:
```cpp
constexpr bool is_digit(char c) noexcept {
  return c >= '0' && c <= '9';
}
```
This is safe, locale-independent (for digits), and valid `constexpr`.

## 2. API Hardening
### Problem
Return values of `LogParser` are ignored in some call sites, or at least not enforced.
### Proposal
Add `[[nodiscard]]` to:
- `LogParser::parseHeader`
- `LogParser::parseFrameStructured`
- `LogParser::parseStackFrame`
- `LogParser::removePrefix`

## 3. Signal Handling (Graceful Shutdown)
### Problem
`Ctrl+C` kills the process immediately. If `jsonArray` is enabled, the closing `]` is never written, resulting in invalid JSON.
### Proposal
Introduce `src/signal_handler.h`:
```cpp
#include <functional>
#include <vector>

class SignalHandler {
public:
    using Callback = std::function<void()>;
    static void register_handler();
    static void add_cleanup_task(Callback task);
private:
    static void handle_signal(int signal);
    static std::vector<Callback> cleanup_tasks;
};
```
Integration:
- `main.cpp` calls `SignalHandler::register_handler()`.
- `LogWriter` registers a cleanup task in its constructor (or `main.cpp` lambda capturing `LogWriter`) to call `pImpl->finalize()`.
- *Refinement*: `LogWriter` shouldn't depend on `SignalHandler`. `main.cpp` should bind them.

## 4. GitHub Actions Integration
### Problem
CI pipelines need machine-readable errors to annotate PRs.
### Proposal
Add `--github-actions` flag to `Options`.
Update `LogWriter::writeEntry`:
If enabled, emit:
`::error file=<FILE>,line=<LINE>,title=<TYPE>::<MESSAGE>`

Logic:
- `<TYPE>`: `entry.errorType`
- `<FILE>`, `<LINE>`: Parse from `entry.stackFrames[0].location` if available.
- `<MESSAGE>`: First line of stack or summary.

New Option:
- `bool githubActions = false;` in `Options`.
- CLI flag: `--github-actions`.

## 5. Backward Compatibility
- New flags are optional.
- Signal handling is transparent improvement.
- `is_digit` fix is internal.

## 6. Required Tests
- `test_signal_handling.cpp`: Mock signal (if possible) or unit test the handler logic.
- `test_github_output.cpp`: Verify format strings.
