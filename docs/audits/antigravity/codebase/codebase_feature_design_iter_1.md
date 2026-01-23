# Codebase Feature Design (Iteration 1)

## 1. Proposed New APIs & Extensions

### 1.1 Time Filtering
**Goal**: Filter logs based on the timestamp present in the log entry.
**API Changes**:
- `FilterConfig` struct:
    - Adds `std::optional<std::string> timeAfter;`
    - Adds `std::optional<std::string> timeBefore;`
- `Options` struct:
    - Adds `std::string timeAfter;`
    - Adds `std::string timeBefore;`
- **Behavior**:
    - Performs string comparison against `LogEntry::timestamp`.
    - If `timeAfter` is set, entry is kept ONLY if `entry.timestamp >= timeAfter`.
    - If `timeBefore` is set, entry is kept ONLY if `entry.timestamp <= timeBefore`.
    - Entries without timestamps are excluded if time filtering is active.

### 1.2 Inverse Stack Matching
**Goal**: Include entries where *ANY* stack frame matches a regex.
**API Changes**:
- `FilterConfig` struct:
    - Adds `std::vector<std::string> includeStackPatterns;`
- `LogFilter`:
    - Compiles these patterns to `std::regex`.
    - In `shouldKeep`: checks if *any* frame matches *any* start pattern.
    - Logic: Update "Include-Only Logic" to consider `includeStackPatterns`.

### 1.3 Color Output
**Goal**: Improve TTY visibility.
**API Changes**:
- `Options` struct:
    - Adds `bool color = false;` (auto-detected if TTY, or forced via flag).
- `LogWriter`:
    - Adds `enableColor(bool)`.
    - Implementation: Use ANSI escape codes for `errorType`, `PID`, `Source File`.
    - Codes: Red for errors, detailed colors for locations.

### 1.4 JSON Statistics Export
**Goal**: Export summary stats to a file.
**API Changes**:
- `Options` struct:
    - Adds `std::string statsFile;`
- `LogWriter`:
    - Adds `writeStatsJson(const Stats& stats, const std::string& filename)`.

### 1.5 Configuration File
**Goal**: Load options from a file.
**API Changes**:
- `cli::parseArgs`: implementation detail.
- Support `--config <file>`.
- Format: JSON. (Since we already have `json_utils`, use it to parse config).
- **Behavior**: CLI args override Config file values.

## 2. Backward Compatibility
- All new options are optional.
- Default behavior remains unchanged.
- Existing CLI flags work as before.

## 3. Interfaces & Signatures

```cpp
// include/options.h
struct FilterConfig {
    // ... existing ...
    std::vector<std::string> includeStackPatterns;
    std::optional<std::string> timeAfter;
    std::optional<std::string> timeBefore;
};

struct Options {
    // ... existing ...
    std::string timeAfter;
    std::string timeBefore;
    std::string statsFile;
    std::string configFile;
    bool color = false;
};

// include/log_writer.h
class LogWriter {
    public:
        void setUseColor(bool enable);
        void writeStatsJson(const Stats& stats, const std::string& path) const;
};
```

## 4. Required Tests
- `test/test_new_features_iter1.cpp`:
    - Test `timeAfter` / `timeBefore` filtering.
    - Test `includeStackPatterns` (regex matching).
    - Test `writeStatsJson` (verify file content).
    - Test Config file loading (mock file, parse options).
