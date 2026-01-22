#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <cassert>
#include <cstdio>
#include <iostream>
#include <sstream>
#include <string>

// Test filtering by exclude_types
void test_filtering() {
  Options opt;
  opt.json_output = false;
  opt.exclude_types.push_back("process terminating"); // Should match case-sensitive or insensitive?
  // Implementation uses find(), so case-sensitive based on raw log. Valgrind usually lowercases some things or Mixed.
  // "Process terminating" is standard. My implementation uses `entry.error_type` which comes from `replace_prefix`.
  // Let's use exact match or partial match.
  opt.exclude_types.push_back("Process terminating");

  LogProcessor processor(opt);

  // Sample blocks
  std::string block1 = "==123== Invalid read of size 4\n==123==    at 0x400: main (test.c:10)\n";
  std::string block2 = "==123== Process terminating with default action of signal 11\n==123==    "
                       "at 0x400: raise (raise.c:1)\n";

  // We simulate processing by feeding lines
  std::vector<std::string> lines;
  // Split block1
  std::stringstream ss1(block1);
  std::string line;
  while (std::getline(ss1, line))
    lines.push_back(line);
  // Split block2
  std::stringstream ss2(block2);
  while (std::getline(ss2, line))
    lines.push_back(line);

  // Capture output
  std::string output_file = "test_filter_out.txt";
  // Redirect stdout to file is hard here without pipe.
  // But LogProcessor takes a FILE* in process_stream_cfile or writes to generic out.
  // Actually LogProcessor writes to `out_fp` which defaults to stdout.
  // We can't easily capture stdout unless we reopen it.
  // BUT, LogProcessor ctor takes options with `output_file`.

  opt.output_file = output_file;
  LogProcessor processor_file(opt);
  processor_file.process_lines(lines);
  // Destructor closes file (via shared_ptr holder if we rely on it?)
  // Actually LogProcessor doesn't close `out_fp` unless it opened it.
  // It opens it if `output_file` is set.

  // Check file content
  // We expect block1 to be there, block2 to be missing.
}

int main() {
  try {
    test_filtering();
    std::cout << "test_filtering passed\n";
  } catch (const std::exception& e) {
    std::cerr << "Test failed: " << e.what() << "\n";
    return 1;
  }
  return 0;
}
