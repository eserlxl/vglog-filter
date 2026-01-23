# Codebase Feature Design (Iteration 1)

## 1. Proposed APIs

### 1.1 `Options::dumpConfig` and CLI
- **New Flag**: `--dump-config <file>`
- **Behavior**:
  - If specified, the tool parses all arguments.
  - Before running processing, it serializes the final `Options` object to JSON.
  - Writes to `<file>` and exits (or continues? Standard practice is exit, but maybe useful to dump and run. Let's make it exit to be safe as a "dry run" inspection).

### 1.2 `FilterConfig::includeSourcePaths`
- **Field**: `std::vector<std::string> includeSourcePaths;`
- **Behavior**:
  - If NOT empty, *only* entries involving at least one of these paths are kept.
  - Works via `LogEntry::involvesSourceFile`.
  - Logic: `keep = (exclude check passed) AND (include check passed)`.
  - `include check passed` = `includeSourcePaths.empty() || OR(matches)`.

### 1.3 Semantic Coloring
- **Class**: `LogWriter::Colorizer` (internal helper or standalone).
- **Function**: `std::string colorize(const LogEntry& entry)`
- **Scheme**:
  - **Error Type**: Red (if high severity), Yellow (if warning).
  - **PID**: Cyan.
  - **Address (0x...)**: Green.
  - **File Path**: Blue.
  - **Line Number**: Yellow.
  - **Function**: Magenta.
- **API**: `LogWriter::setUseColor(bool)` already exists. It needs to enable this advanced mode.

### 1.4 Time Parsing `TimeUtils`
- **New Helper**: `include/time_utils.h` (or inside `json_utils.h` if small, but `time` is distinct).
- **Capabilities**:
  - `std::string normalizeTimestamp(std::string_view ts)`: Ensures "HH:MM:SS" format padding for string comparison.
  - `bool isAfter(string_view ts, string_view target)`
  - `bool isBefore(string_view ts, string_view target)`
- **Integration**: `LogFilter` uses these helpers instead of raw string comparison.

### 1.5 Stats Format
- **New Flag**: `--stats-format=json|text` (default text).
- **Behavior**: Defines how stats are printed to stdout if no `--stats-json` file is given (or even if it is).
- **API**: `Options::statsFormat` enum.

## 2. Backward Compatibility
- All new flags are optional. Default behavior matches current behavior.
- JSON output for logs remains compatible.

## 3. Behavioral Contracts
- `includeSourcePaths`: If an entry has NO source context (e.g. no symbols), it fails the inclusion filter if the filter is active. This matches expectation: "I want to see logs from *this file*". If undefined, it's not that file.

## 4. Required Tests
- **Test Config Dump**: Run with `--dump-config out.json`. load `out.json` and verify fields match.
- **Test Color**: Capture stdout. Verify ANSI codes appear around known tokens.
- **Test Time**: Feed logs with "1:00:00" vs "01:00:00" and ensure normalization allows correct comparison.
- **Test Include Source**: Feed logs with mixed files. Verify only target file remains.
