#include "options_builder.h"
#include "test_helpers.h"
#include <iostream>

bool test_builder_basic() {
  OptionsBuilder builder;
  builder.setOutput("outfile.log").setJson(true).setDetailedJson(false);

  Options opts = builder.build();
  TEST_ASSERT(opts.outputFile == "outfile.log", "Output file mismatch");
  TEST_ASSERT(opts.jsonOutput == true, "JSON output mismatch");
  TEST_ASSERT(opts.detailedJson == false, "Detailed JSON mismatch");

  TEST_PASS("test_builder_basic");
  return true;
}

bool test_builder_filters() {
  OptionsBuilder builder;
  builder.addIncludePid(100)
      .addExcludePid(200)
      .addIncludeThread(5)
      .addIncludeType("InvalidRead")
      .addExcludeFunction("malloc");

  Options opts = builder.build();
  TEST_ASSERT(opts.filter.includePids.size() == 1, "Include PID size");
  TEST_ASSERT(opts.filter.includePids[0] == 100, "Include PID val");

  TEST_ASSERT(opts.filter.excludePids.size() == 1, "Exclude PID size");
  TEST_ASSERT(opts.filter.excludePids[0] == 200, "Exclude PID val");

  TEST_ASSERT(opts.filter.includeThreads.size() == 1, "Include Thread size");
  TEST_ASSERT(opts.filter.includeThreads[0] == 5, "Include Thread val");

  TEST_ASSERT(opts.filter.includeTypes.size() == 1, "Include Type size");
  TEST_ASSERT(opts.filter.includeTypes[0] == "InvalidRead", "Include Type val");

  TEST_ASSERT(opts.filter.excludeFunctions.size() == 1, "Exclude Func size");
  TEST_ASSERT(opts.filter.excludeFunctions[0] == "malloc", "Exclude Func val");

  TEST_PASS("test_builder_filters");
  return true;
}

int main() {
  bool all_passed = true;
  all_passed &= test_builder_basic();
  all_passed &= test_builder_filters();

  if (all_passed) {
    std::cout << "All OptionsBuilder tests passed!" << std::endl;
    return 0;
  } else {
    std::cout << "Some Tests Failed" << std::endl;
    return 1;
  }
}
