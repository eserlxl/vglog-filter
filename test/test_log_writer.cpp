#include "log_entry.h"
#include "log_writer.h"
#include "options.h"
#include "test_helpers.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

bool test_writer_basic() {
  std::string filename = "test_writer_basic.log";
  if (fs::exists(filename))
    fs::remove(filename);

  Options opt;
  opt.output_file = filename;
  opt.json_output = false;

  {
    LogWriter writer(opt);
    LogEntry entry;
    entry.raw_content = "Raw Content Line";
    writer.writeEntry(entry);
  }

  std::string content = read_file_to_string(filename);
  TEST_ASSERT(content == "Raw Content Line\n", "Should write raw content with newline");

  fs::remove(filename);
  TEST_PASS("test_writer_basic");
  return true;
}

bool test_writer_json() {
  std::string filename = "test_writer_json.log";
  if (fs::exists(filename))
    fs::remove(filename);

  Options opt;
  opt.output_file = filename;
  opt.json_output = true;
  opt.detailed_json = true;

  {
    LogWriter writer(opt);
    LogEntry entry;
    entry.raw_content = "RawContent";
    entry.signature = "Sig";
    entry.error_type = "ErrType";
    entry.pid = "123";
    entry.stack_trace.push_back("Frame1");
    writer.writeEntry(entry);
  }

  std::string content = read_file_to_string(filename);

  // Simple check for JSON structure
  TEST_ASSERT(content.find("\"type\":\"record\"") != std::string::npos, "JSON type missing");
  TEST_ASSERT(content.find("\"raw\":\"RawContent\"") != std::string::npos, "JSON raw missing");
  TEST_ASSERT(content.find("\"pid\":\"123\"") != std::string::npos, "JSON pid missing");
  TEST_ASSERT(content.find("\"error_type\":\"ErrType\"") != std::string::npos,
              "JSON error_type missing");

  fs::remove(filename);
  TEST_PASS("test_writer_json");
  return true;
}

bool test_writer_rotation() {
  std::string filename = "test_writer_rot.log";
  // Clean up potential leftovers
  if (fs::exists(filename))
    fs::remove(filename);
  if (fs::exists(filename + ".1"))
    fs::remove(filename + ".1");

  Options opt;
  opt.output_file = filename;
  opt.rotate_size_mb = 1; // 1MB
  opt.rotate_backups = 1;

  // Mock size check override or use small size?
  // Since rotate_size_mb is size_t mb, min is 1MB.
  // We can't easily test rotation without writing > 1MB.
  // We can't change LogWriter impl to accept bytes easily without changing interface.
  // Let's write 1MB+ of data.

  {
    LogWriter writer(opt);
    std::string big_chunk(1024 * 1024 + 100, 'A'); // > 1MB
    writer.writeRaw(big_chunk);
    // Next write should trigger rotation
    writer.writeRaw("Trigger");
  }

  TEST_ASSERT(fs::exists(filename), "Current log should exist");
  TEST_ASSERT(fs::exists(filename + ".1"), "Backup log should exist");

  uintmax_t size_backup = fs::file_size(filename + ".1");
  uintmax_t size_current = fs::file_size(filename);

  TEST_ASSERT(size_backup > 1024 * 1024, "Backup should contain the big chunk");
  TEST_ASSERT(size_current < 1024, "Current should contain only the trigger");

  fs::remove(filename);
  fs::remove(filename + ".1");
  TEST_PASS("test_writer_rotation");
  return true;
}

int main() {
  bool passed = true;
  passed &= test_writer_basic();
  passed &= test_writer_json();
  passed &= test_writer_rotation();

  if (passed) {
    std::cout << "All LogWriter tests passed\n";
    return 0;
  } else {
    std::cerr << "Some LogWriter tests failed\n";
    return 1;
  }
}
