#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <cassert>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

void test_stats_filtering() {
  Options opt;
  // ...
}

void test_rotation() {
  std::string out_base = "test_rotate.log";
  // Cleanup
  if (fs::exists(out_base))
    fs::remove(out_base);
  if (fs::exists(out_base + ".1"))
    fs::remove(out_base + ".1");

  Options opt;
  opt.output_file = out_base;
  opt.trim = false;
  opt.rotate_size_mb = 1; // 1 MB
  opt.rotate_backups = 1;

  // We can't easily test 1MB limit without writing 1MB.
  // But we can hack: LogProcessor logic uses opt.rotate_size_mb.
  // If we can modify the check...
  // Or we just write 1.1 MB. 1 MB is small enough.

  LogProcessor processor(opt);

  std::string big_chunk(1024 * 10, 'A'); // 10KB
  // Write 110 chunks = 1.1 MB
  std::string block;
  block.reserve(1024 * 10 + 100);
  block += "==123== Error\n";
  block += "==123==    at ";
  block += big_chunk;
  block += "\n";

  // For rotation to happen, we need to call write_output multiple times or big write.
  // LogProcessor writes raw blocks.
  for (int i = 0; i < 110; ++i) {
    std::vector<std::string> lines;
    // Split block into lines to feed process_lines
    // Actually process_lines takes vector of strings.
    // We can just construct it.
    // Simplification: emulate file stream processing which chunks by line.
    // Or just feed 110 blocks.
    lines.push_back("==123== Error " + std::to_string(i));
    lines.push_back("==123==    at " + big_chunk);
    processor.process_lines(lines);
  }

  // Check files
  // out_base should exist (current). size ~ 0.1 MB
  // out_base.1 should exist (rotated). size ~ 1.0 MB

  auto s1 = fs::file_size(out_base);
  bool rotated = fs::exists(out_base + ".1");

  std::cout << "Current file size: " << s1 << "\n";
  if (rotated) {
    std::cout << "Rotated file size: " << fs::file_size(out_base + ".1") << "\n";
  }

  if (!rotated) {
    std::cerr << "Rotation failed! Backup file not created.\n";
    exit(1);
  }

  // Cleanup
  fs::remove(out_base);
  fs::remove(out_base + ".1");
}

int main() {
  try {
    test_rotation();
    std::cout << "test_rotation_strict passed\n";
  } catch (const std::exception& e) {
    std::cerr << "Test failed: " << e.what() << "\n";
    return 1;
  }
  return 0;
}
