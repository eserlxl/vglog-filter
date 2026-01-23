# Codebase Feature Design (Iteration 2)

## 1. Proposed New / Extended APIs

### A. LogEntry Enhancements (`include/log_entry.h`)
Transform `LogEntry` from a POD struct into a rich class (or struct with methods).

```cpp
struct LogEntry {
  // ... existing fields ...

  // NEW Helpers
  [[nodiscard]] bool hasFrameMatching(const std::string& functionName) const;
  [[nodiscard]] bool hasFrameMatching(const std::regex& pattern) const;
  [[nodiscard]] bool involvesSourceFile(std::string_view filename) const;
  
  // Data extraction
  [[nodiscard]] std::vector<std::string> getUniqueFiles() const;
  // [[nodiscard]] std::string toJson() const; // Helper to self-serialize?
};
```

### B. LogWriter JSON Modes (`include/log_writer.h`)
Update `LogWriter` to handle stateful writing for JSON Arrays.

```cpp
class LogWriter {
public:
  enum class OutputFormat {
    Text,
    JsonLines,
    JsonArray
  };
  
  // ...
private:
  bool isFirstEntry = true;
  OutputFormat format = OutputFormat::Text;
  
  void writeJsonArrayItem(const LogEntry& entry);
  void writeJsonLine(const LogEntry& entry);
  
  // Destructor must close array if needed
  ~LogWriter(); 
};
```

### C. Options Update (`include/options.h`)
```cpp
struct Options {
  // ...
  bool jsonArray = false; // New flag
  // ...
};
```

## 2. Refactoring `LogFilter`
Update `LogFilter::shouldKeep` to use `entry.hasFrameMatching(...)` to simplify the implementation.

## 3. Behavioral Contracts
- **JSON Array**:
  - Must start with `[` on initialization (or first write?). Initialization is safer.
  - Must write `,` between items.
  - Must write `]` on destruction or explicit `close()`.
  - If no entries, result should be `[]`.

## 4. Tests
- `test_json_modes.cpp`: Verify OutputFormat::JsonArray produces valid JSON.
- `test_log_entry_methods.cpp`: Verify regex/string matching helpers.
