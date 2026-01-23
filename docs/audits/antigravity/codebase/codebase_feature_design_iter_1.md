# Codebase Feature Design (Iteration 1)

## 1. Proposed New / Extended APIs

### A. Options Refactoring (`include/options.h`)
Transform the flat `Options` struct into a hierarchical configuration to improve maintainability and logical grouping.

```cpp
// NEW: Filter Configuration
struct FilterConfig {
  std::vector<std::string> excludeTypes;
  std::vector<std::string> excludeStackPatterns;
  std::vector<std::string> excludeSourcePaths;
  std::vector<int32_t> excludeThreads;
  std::vector<std::string> includeTypes;
  std::vector<std::string> includeFunctions;
  std::vector<std::string> excludeFunctions;
  size_t maxErrors = 0;
};

// NEW: Rotation Configuration
struct RotationConfig {
  size_t rotateSizeMb = 0;
  size_t rotateBackups = 0;
  std::string outputFile; // Required for rotation
};

// MODIFIED: Main Options
struct Options {
  int depth = DEFAULT_DEPTH;
  bool trim = true;
  bool scrubRaw = true; // Renamed from scrub_raw
  bool streamMode = false;
  bool showProgress = false;
  bool monitorMemory = false; // Renamed from monitor_memory
  std::vector<std::string> markers;
  std::string filename;
  std::string outputFile;
  bool jsonOutput = false;
  bool useStdin = false; // Renamed from use_stdin
  bool detailedJson = false;
  bool strictMode = false;
  bool detailedStats = false;

  // Nested Configs
  FilterConfig filter;
  RotationConfig rotation;

  void validate() const;
};
```

### B. Logical Filter Extraction (`include/log_filter.h`)
Extract filtering logic from `LogProcessor`.

```cpp
#pragma once
#include "log_entry.h"
#include "options.h" // for FilterConfig
#include <regex>
#include <vector>

class LogFilter {
public:
  explicit LogFilter(const FilterConfig& config);

  [[nodiscard]] bool shouldKeep(const LogEntry& entry) const;

private:
  const FilterConfig& config;
  std::vector<std::regex> stackRegexes;
};
```

### C. LogProcessor Modernization (`include/log_processor.h`)
Update to use `LogFilter` and camelCase naming.

```cpp
class LogProcessor {
public:
  explicit LogProcessor(const Options& options);
  // ...
private:
  // Renamed methods
  void processLine(std::string_view line); // was process_line
  void flush();
  void clearCurrentState() noexcept;       // was clear_current_state
  void resetEpoch() noexcept;              // was reset_epoch
  
  // New member
  LogFilter filter; 
};
```

## 2. Behavioral Contracts
- **Filtering**: `LogFilter` must honor the OR logic for `include` directives and AND logic for `exclude` directives as currently implemented.
- **State**: `LogProcessor` retains ownership of `LogWriter` and `LogFilter`.
- **Parsing**: `processLine` (camelCase) behavior remains identical to `process_line`.

## 3. Error Handling
- `LogFilter` constructor throws `std::runtime_error` if regex compilation fails (same as current `LogProcessor`).
- `Options::validate` will check rotation constraints on `rotation` struct.

## 4. Backward Compatibility
- **CLI**: The command-line flags remain unchanged. The `main.cpp` parsing logic will map existing flags to the new nested `Options` fields.
- **API**: Internal C++ API breaks (renaming fields), but this is allowed in Iteration 1.

## 5. Required Tests
- **Unit**: Verify `LogFilter` in isolation (`test_log_filter.cpp`).
- **Integration**: Verify `LogProcessor` still works with the new structure.
- **CLI**: Ensure old flags (`--exclude-type`) correctly populate `options.filter.excludeTypes`.
