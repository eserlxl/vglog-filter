# Codebase Feature Design (Iteration 2)

## 1. Options Builder (Usability)

**Header**: `include/options_builder.h`

```cpp
#pragma once
#include "options.h"

class OptionsBuilder {
public:
  OptionsBuilder() = default;

  OptionsBuilder& setJsonOutput(bool enabled);
  OptionsBuilder& setDetailedJson(bool enabled);
  OptionsBuilder& setOutputFile(const std::string& path);
  OptionsBuilder& addExcludePid(int pid);
  OptionsBuilder& addIncludePid(int pid);
  OptionsBuilder& addIncludeThread(int tid);
  // ... other methods ...

  Options build() const;

private:
  Options opts;
};
```

## 2. CLI Refactoring (Refactoring)

**Header**: `include/cli_parser.h`

```cpp
#pragma once
#include "options.h"
#include <optional>

namespace cli {
  std::optional<Options> parse_args(int argc, char* argv[]);
}
```

**Implementation**: `src/cli_parser.cpp`
- Move `parse_command_line` logic from `main.cpp` to here.
- Clean up `main.cpp` to just call `cli::parse_args`.

## 3. JSON Output Updates (Consistency)

**File**: `src/log_writer.cpp`
- Update `format_json` to serialization `timestamp` field if present.
- Use `json_utils::escape_string`.

## Validation Plan
- **Unit Test**: `test_cli_options.cpp` (refactored to use `cli_parser`).
- **Unit Test**: `test_log_writer.cpp` (verify timestamp field in JSON).
- **Unit Test**: `test_options_builder.cpp` (new test).
