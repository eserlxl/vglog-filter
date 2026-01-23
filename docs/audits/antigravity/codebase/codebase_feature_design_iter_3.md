# Refactoring Design (Iteration 3)

## 1. Config Loader Extraction
**Goal**: Decouple configuration logic from `main.cpp`.
**Design**:
- Create `include/config_loader.h` and `src/config_loader.cpp`.
- Class `ConfigLoader`.
- Method: `static void load(Options& opt)`.
- Logic moves verbatim from `main.cpp` anonymous namespace.

## 2. ILogWriter Interface
**Goal**: Enable mocking of output for `LogProcessor` testing.
**Design**:
- `include/ilog_writer.h`: Interface with virtual destructor and pure virtual methods:
  - `writeEntry(const LogEntry&)`
  - `printStats(FILE*)` -> `writeStats`
  - `writeStatsJson(...)`
- Update `LogWriter` to inherit `ILogWriter`.
- Update `LogProcessor`:
  - Member `std::unique_ptr<ILogWriter> writer`.
  - Constructor overload: `LogProcessor(const Options&, std::unique_ptr<ILogWriter>)`.
  - Default constructor creates `LogWriter` impl.

## 3. Mock Testing
**Goal**: specific unit test for `LogProcessor` logic without file I/O.
**Design**:
- `test/test_features_iter3.cpp`:
  - Define `MockLogWriter : public ILogWriter`.
  - Test `LogProcessor` deduplication by counting calls to `MockLogWriter::writeEntry`.
