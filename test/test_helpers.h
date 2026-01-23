// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Common test macros and helpers for vglog-filter tests
#pragma once
#include <canonicalization.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <regex>
#include <sstream>
#include <string>
#include <string_view>

#define TEST_ASSERT(condition, message)                                                            \
  do {                                                                                             \
    if (!(condition)) {                                                                            \
      std::cerr << "FAIL: " << message << std::endl;                                               \
      return false;                                                                                \
    }                                                                                              \
  } while (0)

#define TEST_PASS(message)                                                                         \
  do {                                                                                             \
    std::cout << "PASS: " << message << std::endl;                                                 \
  } while (0)

inline std::string read_file_to_string(const std::string& path) {
  std::ifstream f(path);
  std::stringstream buffer;
  buffer << f.rdbuf();
  return buffer.str();
}

inline std::string trim(std::string_view s) {
  auto start = s.find_first_not_of(" \t\r\n");
  if (start == std::string_view::npos)
    return "";
  auto end = s.find_last_not_of(" \t\r\n");
  return std::string(s.substr(start, end - start + 1));
}

inline std::string canon(std::string_view s) {
  return canonicalization::canon(s);
}

class TempFile {
public:
  explicit TempFile(const char* filename, std::ios::openmode mode = std::ios::out)
      : path_(std::string("/tmp/") + filename), stream_(path_, mode) {}

  ~TempFile() {
    stream_.close();
    std::remove(path_.c_str());
  }

  std::ofstream& get_stream() {
    return stream_;
  }
  const char* path() const {
    return path_.c_str();
  }
  void write(const std::string& content) {
    stream_ << content;
  }
  void close() {
    stream_.close();
  }
  void flush() {
    stream_.flush();
  }

private:
  std::string path_;
  std::ofstream stream_;
};