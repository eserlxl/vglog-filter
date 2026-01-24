# Codebase Feature Design (Iteration 2)

## 1. Proposed APIs

### 1.1 `include/json/simple_json_builder.h` (New Helper)
A small abstraction to construct JSON safely.
```cpp
namespace json {
class Builder {
public:
    Builder& add(std::string_view key, std::string_view value);
    Builder& add(std::string_view key, int64_t value);
    Builder& add(std::string_view key, bool value);
    Builder& startObject(std::string_view key);
    Builder& endObject();
    Builder& startArray(std::string_view key);
    Builder& endArray();
    std::string str() const;
    // ...
};
}
```
*Justification*: Eliminates repetitive `\"` escaping and manual comma handling in `LogWriter` and `Options::dump`.

### 1.2 `ConfigLoader` Enhancement
- Enable `files` key mapping to `includeSourcePaths` / `excludeSourcePaths`.
- Ensure strict type checking for JSON values.

### 1.3 `LogProcessor` Parallel Safety
- Inject `if (SignalHandler::isStopRequested()) break;` into `processStreamParallel` reader loop.

### 1.4 `Options::validate` Refinement
- Add check: If `detailedJson` is true, ensure `jsonOutput` is true (or auto-enable it).

## 2. Behavioral Contracts
- **SimpleJsonBuilder**:
  - Handles commas automatically between fields.
  - Escapes strings automatically.
  - Does NOT validate schema, just formatting.
- **ConfigLoader**:
  - Should not crash on invalid keys, just warn (existing behavior).
  - Add support for `files` -> `sourcePaths`.

## 3. Backward Compatibility
- JSON Output format must remain exactly identical byte-for-byte (or semantically equivalent) to Iteration 1 to avoid breaking verifiers.
- `Options::dump` format improved but compatible structure.

## 4. Required Tests
- `TestJsonBuilder`: Unit test for the new helper.
- `TestParallelSignal`: (Hard to test deterministically without mock, but manual verification via `processStreamParallel` review).
- `TestConfigFiles`: Verify `files` key loading.
