# Codebase Feature Design (Iteration 3)

## 1. Zero-Warning Fixes

### Fix A: LogFilter Constructor
```cpp
// Before
LogFilter::LogFilter(const FilterConfig& config) : config(config) { ... }

// After
LogFilter::LogFilter(const FilterConfig& cfg) : config(cfg) { ... }
```

### Fix B: Safe File Reading in Tests
Refactor `read_file` helper in `test_json_modes.cpp`:
```cpp
std::string read_file(const std::string& path) {
  std::ifstream t(path);
  if (!t) return "";
  std::stringstream buffer;
  buffer << t.rdbuf();
  return buffer.str();
}
```

## 2. Documentation Polish
- Add `@details` to `LogFilter` explaining that regexes are compiled once.
- Ensure `LogEntry` helpers have examples in comments.

## 3. Final Verification
- Clean build.
- `cmake --build build` should show no "warning:" lines.
- Run all tests.
