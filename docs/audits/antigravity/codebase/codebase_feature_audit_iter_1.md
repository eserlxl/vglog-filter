# Codebase Feature Audit (Iteration 1)

## 1. Existing Capabilities (Under-exposed or Incomplete)
- **Options Management**: The `Options` struct is a flat collection of 20+ fields, mixing I/O, filtering, and rotation logic.
- **Filtering Logic**: Implemented directly inside `LogProcessor::shouldKeepEntry`. Use of `std::regex` inside the hot path (for each entry) is functional but coupled.
- **Statistics**: `LogStats` collects data but `LogWriter` decides how to print it. Separation is slightly blurry.
- **LogParser**: Currently just a set of static methods. Good for now, but `LogParser::parseStackFrame` returns `std::optional<std::string>`, missing the opportunity to return structured data directly in all cases (though `parseFrameStructured` exists).

## 2. Missing Features Logically Implied by Current Design
- **Structured Configuration**: `Options` should be nested (e.g., `FilterConfig`, `RotationConfig`).
- **Encapsulated Filter Engine**: Filtering is a core domain concept that deserves its own class (`LogFilter`), separate from the "Processor" (which should focus on the loop/pipeline).
- **Dependency Injection**: `LogProcessor` creates its own `LogWriter`. It should accept an `ILogWriter` or `LogWriter` instance/factory to allow better testing and flexibility.
- **Standard Layout**: The codebase mixes `snake_case` and `camelCase`.

## 3. High-Risk Correctness or Safety Issues
- **Manual String Parsing**: `LogProcessor::process_line` relies on manual character loops and `line[i]` access. While likely safe due to bounds checks, it's brittle.
- **Regex Performance**: Re-evaluating `std::regex` (even if compiled) for every frame of every entry in a large log file could be slow. `Options` stores strings, `LogProcessor` compiles them in ctor.

## 4. API Usability Gaps and Misuse Risks
- **Naming Conventions**: Major violation of the User's "camelCase" rule.
  - `scrub_raw` -> `scrubRaw`
  - `use_stdin` -> `useStdin`
  - `process_line` -> `processLine`
  - `matches_vg_line` -> `matchesVgLine`
- **Globals/Constants**: `DEFAULT_MARKER` is a global string view. `MAX_LINE_LENGTH` is `constinit`.

## 5. Missing Tests Blocking Safe Feature Expansion
- **Filter Combinations**: Need to verify that `includeTypes` AND `excludeFunctions` work together as expected (currently logic suggests `include` checks first).
- **JSON Structure**: Need to ensure `detailedJson` output is valid JSON (tests exist but should be robust).

## 6. Areas That Must Remain Unchanged
- **Valgrind Compatibility**: The core parsing logic for `==PID==` must not break.
- **Performance**: Avoid adding heap allocations in the hot loop (`process_line`).

## 7. Changes Since Last Iteration
- N/A (Iteration 1).
