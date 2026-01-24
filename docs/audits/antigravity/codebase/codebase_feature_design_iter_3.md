# Codebase Feature Design (Iteration 3: Configuration File Support)

## Goal
Enable users to provide a JSON configuration file for complex filtering rules, especially arrays of exclusions/inclusions.

## Limitation
Existing `regex` parser in `ConfigLoader` only supports scalar values.
No external JSON library is available.

## Solution
Implement a minimal, lightweight JSON Parser (`SimpleJson`) capable of parsing:
- Objects `{}`
- Arrays `[]`
- Strings `""`
- Integers
- Booleans `true/false`

## Components

### 1. `SimpleJson` Parser
- **Files**: `include/json_parser.h`, `src/json_parser.cpp`
- **Model**:
  ```cpp
  struct JsonValue {
      enum Type { OBJECT, ARRAY, STRING, NUMBER, BOOLEAN, COMPOSITE_NULL };
      Type type;
      std::string stringVal;
      long numberVal;
      bool boolVal;
      std::vector<JsonValue> arrayVal;
      std::map<std::string, JsonValue> objectVal;
  };
  ```
- **Interface**: `static JsonValue parse(const std::string& input);`

### 2. `ConfigLoader` Update
- Use `SimpleJson::parse`.
- Walk the returned `JsonValue` object.
- Map keys to `Options`.

### 3. Schema
```json
{
  "sanitizer": "valgrind",
  "jobs": 4,
  "depth": 5,
  "exclude": {
    "types": ["Invalid read", "Invalid write"],
    "functions": ["malloc", "free"],
    "files": ["vendor/"]
  },
  "include": {
    "pids": [1234, 5678]
  }
}
```

## Implementation Steps
1.  Create `include/json_parser.h` and `src/json_parser.cpp`.
2.  Integrate into `ConfigLoader::load`.
3.  Add `Options` mapping logic.
    - `exclude.types` -> `opt.filter.excludeTypes`
    - `jobs` -> `opt.jobs`
    - etc.
4.  Verification Test (`test_config_loading`).

## Config Precedence
CLI options should generally override config file.
However, for list options (excludes), should they append or replace?
- **Decision**: Append. Logic: Config defines baseline, CLI adds one-off overrides.
- This aligns with `opt.filter.excludeTypes.emplace_back` usage in CLI parser.
- `ConfigLoader::load` runs *before* or *after* CLI parsing?
- Current `main.cpp` likely parses CLI first. If `ConfigLoader` runs inside `cli_parser` (triggered by `--config`), it populates `Options`.
- If `OptionBuilder` implementation is robust, it handles order.
- Let's check `cli_parser` call site.
  - `cli_parser` parses args and *returns* `Options`.
  - It handles `--config` by setting `opt.configFile`.
  - It does NOT load the config itself (based on code seen).
  - So `main` must call `ConfigLoader::load` after CLI parsing?
  - If so, CLI values are already set.
  - We should load config *before* final CLI overrides?
  - Better approach: CLI `parseArgs` returns `opt` with `configFile` set.
  - Main should:
    1. Parse CLI to get `configFile` (and others).
    2. If `configFile` set, Load Config into *temp* options?
    3. Merge?
    - **Or**: Just load config into `opt`.
    - If CLI flags set values, `opt` has them.
    - If Config sets them, `opt` updates.
    - If CLI should win, we effectively need to Apply `CLI` -> `Config` -> `CLI`?
    - Simplification: `ConfigLoader` only sets values if they are *default* (empty/zero)?
    - Or: User accepts that `--config` is loaded *after*.
    - **Better**: Load Config *first*? But we need `--config` path FROM CLI.
    - **Standard Pattern**: 
        1. Parse CLI (partially or fully).
        2. Load Config (using path from CLI or default).
        3. Re-Apply CLI (or ensure CLI took precedence by tracking "set by user").
        - `vglog-filter` `Options` doesn't track source.
        - `ConfigLoader` in `src/config_loader.cpp` checks: `if (opt.timeAfter.empty()) opt.timeAfter = val_str;`.
        - It implements "Only set if empty" policy.
        - I will continue this pattern: Config provides defaults/baselines. CLI (already parsed) wins if set.
        - For Arrays: `excludeTypes`, I will **APPEND**. This allows mixing.

## Verification
- Create `config.json`
- Run `test_config_loading` that mocks parsing or runs `LogProcessor` with config.
