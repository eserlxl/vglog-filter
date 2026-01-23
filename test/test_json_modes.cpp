
#include "log_entry.h"
#include "log_writer.h"
#include "options.h"
#include <cassert>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>

// Simple helper to read whole file
std::string read_file(const std::string& path) {
  std::ifstream t(path);
  if (!t)
    return ""; // Handle missing file gracefully
  std::stringstream buffer;
  buffer << t.rdbuf();
  return buffer.str();
}

void test_json_lines() {
  std::cout << "Testing JSON Lines Mode..." << std::endl;
  std::string out_file = "test_lines.json";
  std::filesystem::remove(out_file);

  Options opt;
  opt.outputFile = out_file;
  opt.jsonOutput = true;
  opt.jsonArray = false;

  {
    LogWriter writer(opt);
    LogEntry e1;
    e1.rawContent = "Raw1";
    e1.signature = "Sig1";
    LogEntry e2;
    e2.rawContent = "Raw2";
    e2.signature = "Sig2";

    writer.writeEntry(e1);
    writer.writeEntry(e2);
  } // Destructor closes

  std::string content = read_file(out_file);
  // Expect: {"type":"record",...}\n{"type":"record",...}\n
  // Should NOT start with [
  if (content.front() == '[') {
    std::cerr << "FAIL: JSON Lines output started with [\n";
    std::exit(1);
  }
  // Should count 2 newlines (minimum)
  int newlines = 0;
  for (char c : content)
    if (c == '\n')
      newlines++;
  if (newlines < 2) {
    std::cerr << "FAIL: Expected at least 2 newlines in JSON Lines output, got " << newlines
              << "\n";
    std::exit(1);
  }

  std::cout << "PASS" << std::endl;
  std::filesystem::remove(out_file);
}

void test_json_array() {
  std::cout << "Testing JSON Array Mode..." << std::endl;
  std::string out_file = "test_array.json";
  std::filesystem::remove(out_file);

  Options opt;
  opt.outputFile = out_file;
  opt.jsonOutput = true;
  opt.jsonArray = true;

  {
    LogWriter writer(opt);
    LogEntry e1;
    e1.rawContent = "Raw1";
    e1.signature = "Sig1";
    LogEntry e2;
    e2.rawContent = "Raw2";
    e2.signature = "Sig2";

    writer.writeEntry(e1);
    writer.writeEntry(e2);
  } // Destructor writes ]

  std::string content = read_file(out_file);
  // Expect: [... , ...]
  assert(content.front() == '[');
  assert(content.back() == ']');
  // Should contain comma
  assert(content.find(',') != std::string::npos);

  std::cout << "PASS" << std::endl;
  std::filesystem::remove(out_file);
}

void test_json_array_empty() {
  std::cout << "Testing Empty JSON Array..." << std::endl;
  std::string out_file = "test_array_empty.json";
  std::filesystem::remove(out_file);

  Options opt;
  opt.outputFile = out_file;
  opt.jsonOutput = true;
  opt.jsonArray = true;

  {
    LogWriter writer(opt);
    // Write nothing
  }

  std::string content = read_file(out_file);
  // Expect: []
  assert(content == "[]");

  std::cout << "PASS" << std::endl;
  std::filesystem::remove(out_file);
}

int main() {
  test_json_lines();
  test_json_array();
  test_json_array_empty();
  return 0;
}
