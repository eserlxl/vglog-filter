# Codebase Feature Design (Iteration 1)

## 1. Goal
Implement missing output formats (CSV, YAML), transparent output compression (Gzip), and structured diff export (JSON). Refactor writer creation for better extensibility.

## 2. Proposed Changes

### 2.1. Expanded Output Formats

#### `CsvLogWriter` (New)
A new implementation of `ILogWriter` that outputs log entries in CSV format.
-   **Header**: `Timestamp,PID,TID,ErrorType,SourceFile,Line,Function,Signature`
-   **Escaping**: Standard CSV quoting for fields containing commas/newlines.
-   **Location**: `include/csv_log_writer.h`, `src/csv_log_writer.cpp`.

#### `YamlLogWriter` (New)
A new implementation of `ILogWriter` that outputs log entries in YAML format.
-   **Structure**: List of objects.
-   **Location**: `include/yaml_log_writer.h`, `src/yaml_log_writer.cpp`.

#### `Options` Extension
Update `include/options.h`:
```cpp
struct Options {
    // ... existing ...
    std::string csvOutput;  // Path to CSV output
    std::string yamlOutput; // Path to YAML output
    // ...
};
```

### 2.2. Transparent Output Compression
Allow any output file (Normal, CSV, JSON, YAML) to be automatically compressed if the filename ends in `.gz`.

#### `file_utils` Extension
-   **Function**: `std::unique_ptr<std::ostream> openOutputFile(const std::string& path)`
-   **Logic**:
    -   If path ends in `.gz`, use `popen("gzip > " + path, "w")` and wrap in a custom `streambuf`.
    -   Else, use `std::ofstream`.
-   **Refactoring**: Update all `LogWriter` implementations to use this helper instead of raw `std::ofstream`.

### 2.3. JSON Diff Export
Extend `DiffEngine` to support exporting the diff results as JSON.

#### `DiffEngine` Extension
```cpp
class DiffEngine {
    // ...
    static void writeDiffJson(const DiffResult& result, const DiffStats& stats, std::ostream& out);
};
```
-   **Format**:
    ```json
    {
      "stats": { "new": 5, "fixed": 2, ... },
      "new_errors": [ ... ],
      "fixed_errors": [ ... ]
    }
    ```

### 2.4. LogWriter Factory
Refactor the manual writer instantiation in `main.cpp` into a factory.

#### `LogWriterFactory` (New)
-   **Location**: `include/log_writer_factory.h`
-   **Signature**:
    ```cpp
    class LogWriterFactory {
    public:
        static std::unique_ptr<ILogWriter> create(const Options& opt);
    };
    ```
-   **Logic**: Returns a `CompositeLogWriter` populated with the appropriate writers based on `Options`.

## 3. Backward Compatibility
-   All new options are optional.
-   Existing flags (`--json`, `--markdown`) remain unchanged.
-   Existing output behavior remains unchanged unless new flags are used.

## 4. Verification Plan
-   **Unit Tests**:
    -   `test_csv_writer.cpp`: Verify CSV formatting and escaping.
    -   `test_yaml_writer.cpp`: Verify YAML structure.
    -   `test_compression_output.cpp`: Write `.gz` file, read back, verify content.
    -   `test_diff_json.cpp`: Verify JSON structure of diff report.
-   **Integration**:
    -   Run `vglog-filter` with `--csv-output` and `--yaml-output`.
-   **Safety**:
    -   Verify `popen` safety (though `file_utils` already uses it). Ensure handling of pipe failures.
