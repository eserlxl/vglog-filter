#include "file_utils.h"
#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <filesystem>
#include <fstream>
#include <vector>

namespace fs = std::filesystem;

bool test_rotation() {
  // Setup
  std::string base_name = "test_rotate.log";
  // Clean up previous runs
  if (fs::exists(base_name))
    fs::remove(base_name);
  if (fs::exists(base_name + ".1"))
    fs::remove(base_name + ".1");
  if (fs::exists(base_name + ".2"))
    fs::remove(base_name + ".2");

  Options opt;
  opt.outputFile = base_name;
  opt.rotateSizeMb = 1;
  opt.rotateBackups = 2;
  opt.scrub_raw = false; // Disable scrubbing

  {
    LogProcessor p(opt);

    // Massive chunk: 100,000 lines.
    // Even at 10 bytes/line -> 1MB.
    // Realistically > 2MB.
    std::string chunk1;
    chunk1.reserve(4000000);
    chunk1 += "==100== Invalid read\n";
    for (int i = 0; i < 100000; ++i) {
      chunk1 += "==100==    at 0x123: func (file.c:1)\n";
    }
    chunk1 += "\n";

    std::stringstream ss1(chunk1);
    p.processStream(ss1);

    std::stringstream ss2(chunk1);
    p.processStream(ss2);
  }

  // Verify
  if (!fs::exists(base_name)) {
    std::cerr << "Main file missing" << std::endl;
    return false;
  }
  // Debug info
  auto sizeMain = fs::file_size(base_name);
  std::cout << "Main size: " << sizeMain << std::endl;

  if (!fs::exists(base_name + ".1")) {
    std::cerr << "Backup file .1 missing. Rotation failed." << std::endl;
    return false;
  }
  auto size1 = fs::file_size(base_name + ".1");
  std::cout << "Backup .1 size: " << size1 << std::endl;

  if (size1 == 0) {
    std::cerr << "Backup file is empty." << std::endl;
    return false;
  }

  // Cleanup
  fs::remove(base_name);
  fs::remove(base_name + ".1");
  if (fs::exists(base_name + ".2"))
    fs::remove(base_name + ".2");

  TEST_PASS("test_rotation");
  return true;
}

bool test_regex_filtering() {
  Options opt;
  opt.trim = false; // Disable trim so we don't need markers
  // Filter out any stack frame containing "crypto"
  opt.excludeStackPatterns.push_back(".*crypto.*");

  LogProcessor p(opt);

  std::vector<std::string> lines;
  // Block 1: Should be kept
  lines.push_back("==100== Invalid read");
  lines.push_back("==100==    at 0x1: main (main.c:1)");
  lines.push_back("");

  // Block 2: Should be filtered (contains "do_crypto")
  lines.push_back("==100== Invalid write");
  lines.push_back("==100==    at 0x2: do_crypto_ops (crypto.c:1)");
  lines.push_back("");

  p.processLines(lines);

  const auto& stats = p.getStats();
  if (stats.blocksFound != 2) {
    std::cerr << "FAIL: Found " << stats.blocksFound << " blocks (expected 2)" << std::endl;
    return false;
  }

  TEST_ASSERT(stats.filteredCount == 1u, "Filtered 1 block (crypto)");
  TEST_ASSERT(stats.uniqueBlocks == 1u, "Kept 1 block");

  TEST_PASS("test_regex_filtering");
  return true;
}

int main() {
  bool passed = true;
  passed &= test_rotation();
  passed &= test_regex_filtering();
  return passed ? 0 : 1;
}
