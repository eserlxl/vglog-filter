#include "log_processor.h"
#include "options.h"
#include "test_helpers.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

bool test_tid_parsing() {
  std::string line = "==100== Thread 2: Invalid read of size 4";

  Options opt;
  opt.detailedStats = true;
  opt.trim = false; // Disable trim to avoid requiring markers

  LogProcessor p(opt);
  std::vector<std::string> lines;
  lines.push_back(line);
  lines.push_back("==100==    at 0x123: main (main.c:1)");
  lines.push_back("");

  p.processLines(lines);

  const auto& stats = p.getStats();
  if (stats.blocksFound != 1) {
    std::cerr << "FAIL: details blocksFound=" << stats.blocksFound << std::endl;
    return false;
  }

  // Check TID stats
  if (stats.errorCountsByTid.count(2) == 0) {
    std::cerr << "FAIL: TID 2 not found in stats" << std::endl;
    return false;
  }
  if (stats.errorCountsByTid.at(2) != 1) {
    std::cerr << "FAIL: TID 2 count mismatch" << std::endl;
    return false;
  }

  TEST_PASS("test_tid_parsing");
  return true;
}

bool test_structured_json() {
  std::string base_name = "test_struct.json";
  if (fs::exists(base_name))
    fs::remove(base_name);

  Options opt;
  opt.outputFile = base_name;
  opt.jsonOutput = true;
  opt.detailedJson = true;
  opt.trim = false;
  opt.scrub_raw = false; // Disable scrubbing so we keep addresses and at/by prefixes

  {
    LogProcessor p(opt);
    std::vector<std::string> lines;
    lines.push_back("==100== Invalid read");
    lines.push_back("==100==    at 0xABC: my_func (file.cpp:42)");
    lines.push_back("");

    p.processLines(lines);
  } // Destructor closes file ensuring flush

  // Check output file
  if (!fs::exists(base_name)) {
    std::cerr << "FAIL: Output file missing" << std::endl;
    return false;
  }

  std::ifstream ifs(base_name);
  std::string content((std::istreambuf_iterator<char>(ifs)), (std::istreambuf_iterator<char>()));

  // Verify JSON content roughly (strings present)
  // We expect "frames" array
  if (content.find("\"frames\":[") == std::string::npos) {
    std::cerr << "FAIL: 'frames' array missing in JSON" << std::endl;
    return false;
  }

  // Check fields
  if (content.find("\"addr\":\"0xABC\"") == std::string::npos) {
    std::cerr << "FAIL: Address missing" << std::endl;
    return false;
  }
  if (content.find("\"func\":\"my_func\"") == std::string::npos) {
    std::cerr << "FAIL: Function missing" << std::endl;
    return false;
  }
  if (content.find("\"loc\":\"file.cpp:42\"") == std::string::npos) {
    std::cerr << "FAIL: Location missing" << std::endl;
    return false;
  }

  fs::remove(base_name);
  TEST_PASS("test_structured_json");
  return true;
}

int main() {
  bool passed = true;
  passed &= test_tid_parsing();
  passed &= test_structured_json();
  return passed ? 0 : 1;
}
