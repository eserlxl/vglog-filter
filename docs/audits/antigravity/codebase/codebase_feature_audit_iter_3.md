# Codebase Feature Audit (Iteration 3)

## 1. Test Failures
- `test_features_iter4`: Fails `test_config_dump` because `SimpleJsonBuilder` produces compact JSON (`"key":value`), but test expects spaced JSON (`"key": value`).

## 2. Warnings
- `log_processor.cpp`: Unused `constexpr` constants (`VG_LINE_MIN_LEN` etc.).
- `cli_parser.cpp`: Case style warnings (`MAX_DEPTH`, `VERSION_STRING` - moved but left variable?).
- `log_writer.cpp`: Lint warnings about constants (`RED`, `GREEN`, etc.).

## 3. Style Issues
- Global constants in `src/cli_parser.cpp` use `UPPER_CASE`. Linter wants `camelCase` or `kCamelCase`.
- `SimpleJsonBuilder`: `add(sv, const char*)` overload added to fix build, justified.

## 4. API Stability
- `Options::dump` format changed (Compact JSON). This broke `test_features_iter4`. This counts as a minor breakage but acceptable for "Iteration 2 Refinement". We fix the test in Iteration 3.
