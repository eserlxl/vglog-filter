# Codebase Feature Audit (Iteration 1)

## Existing Capabilities
- **Filtering**: Types, Functions, Source Paths, PIDs, Threads, Time (String-based), Regex.
- **Output**: Raw, Colorized, JSON (Array/Lines), Stats.
- **Input**: Stdin, Files, Multi-file.
- **Safety**: File rotation, Max errors limit.

## Missing Features / Gaps
1.  **CI Integration**: No native support for GitHub Actions logging commands.
2.  **Signal Safety**: JSON arrays are not closed if the process is interrupted (Ctrl+C), invalidating the entire output.
3.  **Correctness**: `is_digit` in `log_parser.cpp` uses `std::isdigit` in a `constexpr` function. `std::isdigit` is not `constexpr`. This is technically ill-formed or relys on compiler extensions.
4.  **API Hardening**: `LogParser` methods return `std::optional` but lack `[[nodiscard]]`.
5.  **Config Scalability**: Lists (excludes/includes) must be passed via CLI args or a single config file. Large exclusion lists (e.g. 1000s of types) are clumsy.

## High-Risk Issues
- **`is_digit` Constexpr Violation**: `std::isdigit` has undefined behavior if char is negative and not EOF, and is not constexpr.
    - *Fix*: Implement a custom range check `c >= '0' && c <= '9'`.
- **JSON Corruption**: Interruption handling is missing.

## API Usability
- **Naming**: No `kPascalCase` violations found in public headers, but `DEFAULT_DEPTH` etc. use SCREAMING_CASE which is standard for macros but maybe user prefers `DefaultDepth`? Given the strict "check for kPascalCase" instruction, I will assume constants should be `camelCase` if they are static members, or stay SCREAMING if macros. Since they are `inline constexpr`, `defaultDepth` would be more "modern C++". I will NOT change them yet to avoid churn unless confirmed, as `kPascalCase` was the specific prohibition.

## Missing Tests
- **Signal Handling**: Hard to test, but we can verify the handler is registered.
- **Github Actions Output**: Need verification of format.

## Plan for Iteration 1
1.  Fix `is_digit`.
2.  Add `[[nodiscard]]` to `LogParser`.
3.  Implement `SignalHandler` for graceful JSON closure.
4.  Add `GithubActions` output mode.
