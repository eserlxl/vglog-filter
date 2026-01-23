#include "log_processor.h"
#include "log_writer.h"
#include "options.h"
#include "source_loader.h"
#include "test_helpers.h"
#include <fstream>
#include <iostream>
#include <vector>

// Mock Writer to capture output
class MockWriter : public ILogWriter {
public:
  std::vector<LogEntry> entries;
  void writeEntry(const LogEntry& entry) override {
    entries.push_back(entry);
  }
  void writeRaw(const std::string&) override {}
  void writeStats(const LogStats&) override {}
  void writeStatsJson(const LogStats&, const std::string&) const override {}
  void setUseColor(bool) override {}
  void flush() override {}
};

bool test_source_loader_caching_logic() {
  TempFile tf("test_code.cpp");
  tf.write("line1\nline2\nline3\nline4\n");
  tf.close();

  SourceLoader loader;
  auto ctx1 = loader.loadContext(tf.path(), 2, 1); // line 2, context 1 -> lines 1,2,3
  TEST_ASSERT(ctx1.size() == 3, "Should load 3 lines");
  TEST_ASSERT(ctx1[0] == "line1", "Line 1 match");

  // Modify file on disk to prove cache is used (cache should have old content)
  {
    std::ofstream f(tf.path());
    f << "MODIFIED\n";
  }

  auto ctx2 = loader.loadContext(tf.path(), 2, 1); // Should hit cache
  TEST_ASSERT(ctx2.size() == 3, "Should load 3 lines from cache");
  TEST_ASSERT(ctx2[0] == "line1", "Line 1 match from cache, ignoring disk change");

  TEST_PASS("SourceLoader caching behaves correctly");
  return true;
}

bool test_unique_output() {
  Options opt;
  opt.uniqueOutput = true; // Dedup
  opt.depth = 1;

  auto writerCtx = std::make_unique<MockWriter>();
  auto* writer = writerCtx.get();
  LogProcessor processor(opt, std::move(writerCtx));

  std::vector<std::string> lines = {
      "==123== Invalid read of size 4",
      "==123==    at 0x1: main",
      "==123== Invalid read of size 4", // Duplicate signature
      "==123==    at 0x1: main",
  };

  processor.processLines(lines);

  TEST_ASSERT(writer->entries.size() == 1, "Should deduce to 1 entry when uniqueOutput=true");

  TEST_PASS("Unique output flag works (dedup)");
  return true;
}

bool test_non_unique_output() {
  Options opt;
  opt.uniqueOutput = false; // NO Dedup
  opt.depth = 1;

  auto writerCtx = std::make_unique<MockWriter>();
  auto* writer = writerCtx.get();
  LogProcessor processor(opt, std::move(writerCtx));

  std::vector<std::string> lines = {
      "==123== Invalid read of size 4",
      "==123==    at 0x1: main",
      "==123== Invalid read of size 4", // Duplicate signature
      "==123==    at 0x1: main",
  };

  processor.processLines(lines);

  TEST_ASSERT(writer->entries.size() == 2, "Should have 2 entries when uniqueOutput=false");

  TEST_PASS("Non-unique output works (all entries)");
  return true;
}

int main() {
  std::cout << "Running Iteration 2 Features Tests..." << std::endl;
  bool all = true;
  all &= test_source_loader_caching_logic();
  all &= test_unique_output();
  all &= test_non_unique_output();

  if (all) {
    std::cout << "\nAll Iteration 2 tests passed!" << std::endl;
    return 0;
  }
  return 1;
}
