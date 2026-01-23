# Codebase Feature Audit (Iteration 2)

## Focus Area: Usability & Maintainability

## Existing Implementation Gaps
### 1. Configuration Complexity
- **Problem**: `Options` is a large POD (Plain Old Data) struct with nested configs. Constructing it correctly requires setting many fields manually. Validation is separate.
- **Impact**: Library users (and unit tests) have to write verbose setup code.
- **Refinement**: Introduce an `OptionsBuilder` pattern.

### 2. CLI Parsing Monolith
- **Problem**: `src/main.cpp` contains a large `parse_command_line` function with a massive switch statement and manual `getopt` usage.
- **Impact**: Hard to add new flags (as seen in Iteration 1). Hard to test in isolation.
- **Refinement**: Refactor into a `CommandLineParser` class or at least separate the logic more cleanly.

### 3. LogProcessor Complexity
- **Problem**: `LogProcessor::processLine` has deep nesting and complex state management (`raw`, `sig`, `pendingPid`, `markerFound`).
- **Impact**: High cognitive load, prone to bugs when adding features (like the streaming issue encountered in Iteration 1 tests).
- **Refinement**: Extract helper methods for state transitions.

## Missing "Safe" Features
- **Thread Safety**: `LogProcessor` is explicitly non-thread-safe.
- **Proposal**: Add a `ThreadSafeLogProcessor` wrapper or specific mutex guards if feasible without performance regression.

## API consistency
- **LogEntry**: Now has `timestamp` and `getPrimaryFrame`. We should ensure these play well with JSON output implementation in `LogWriter`.

## Proposed Plan for Iteration 2
1.  **Implement `OptionsBuilder`**: Fluent API for configuration.
2.  **Refactor CLI**: Move `parse_command_line` to `src/cli_parser.cpp` and improve structure.
3.  **JSON Output Update**: Ensure `timestamp` is serialized in JSON output (was likely missed in Iteration 1 implementation of serialization).

## High-Risk Areas
- Moving CLI logic might break existing flags if `getopt` state isn't handled right.
- JSON Serialization: adding fields to JSON output is a change, but likely backward compatible (new field).
