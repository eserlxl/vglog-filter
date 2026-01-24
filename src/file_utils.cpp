// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "file_utils.h"
#include "log_processor.h"
#include "path_validation.h"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>
#include <string>
#include <string_view>
#include <sys/resource.h> // Linux
#include <sys/stat.h>
#include <vector>

namespace {

constexpr std::size_t KB_TO_BYTES = 1024;
constexpr std::size_t MB_TO_BYTES = 1024 * KB_TO_BYTES;
constexpr std::size_t TB_TO_BYTES = 1024ULL * 1024ULL * 1024ULL * 1024ULL; // 1 TB
constexpr std::size_t MAX_FILE_SIZE_BYTES = TB_TO_BYTES; 
constexpr std::size_t INITIAL_LINE_CAPACITY = 1024;
constexpr std::size_t MAX_LINES = 1'000'000;
constexpr int PCT_MULTIPLIER = 100;

[[nodiscard]] std::string toMb(std::size_t bytes) {
  return std::to_string(bytes / MB_TO_BYTES);
}

[[nodiscard]] std::string pct(std::size_t done, std::size_t total) {
  if (total == 0)
    return "0";
  return std::to_string(static_cast<int>((done * PCT_MULTIPLIER) / total));
}

void validateFileSize(std::size_t s) {
  if (s > MAX_FILE_SIZE_BYTES) {
    throw std::runtime_error("File too large (max " + toMb(MAX_FILE_SIZE_BYTES) + " MB)");
  }
}
void validateLineCount(std::size_t n) {
  if (n > MAX_LINES) {
    throw std::runtime_error("Too many lines (max " + std::to_string(MAX_LINES) + ")");
  }
}

} // namespace


std::string createErrorMessage(std::string_view operation, std::string_view filename,
                                 std::string_view details) noexcept {
  std::string m = "Error during ";
  m.append(operation);
  if (!filename.empty()) {
    m.append(" for file '").append(filename).append("'");
  }
  if (!details.empty()) {
    m.append(": ").append(details);
  }
  return m;
}

void reportProgress(std::size_t bytesProcessed, std::size_t totalBytes,
                     std::string_view filename) {
  if (totalBytes == 0 || bytesProcessed > totalBytes)
    return;
  std::fprintf(stderr, "\rProcessing %.*s: %s%% (%s/%s MB)", static_cast<int>(filename.size()),
               filename.data(), pct(bytesProcessed, totalBytes).c_str(),
               toMb(bytesProcessed).c_str(), toMb(totalBytes).c_str());
  if (bytesProcessed >= totalBytes)
    std::fputc('\n', stderr);
}

constexpr std::size_t KB_PER_MB = 1024;

std::size_t getMemoryUsageMb() noexcept {
#if defined(__linux__)
  rusage u{};
  if (getrusage(RUSAGE_SELF, &u) == 0) {
    return static_cast<std::size_t>(u.ru_maxrss) / KB_PER_MB; // KB -> MB
  }
#endif
  return 0;
}

void reportMemoryUsage(std::string_view operation, std::string_view filename) {
  const auto mb = getMemoryUsageMb();
  if (mb > 0) {
    if (!filename.empty()) {
      std::fprintf(stderr, "Memory usage during %.*s for %.*s: %zu MB\n",
                   static_cast<int>(operation.size()), operation.data(),
                   static_cast<int>(filename.size()), filename.data(), mb);
    } else {
      std::fprintf(stderr, "Memory usage during %.*s: %zu MB\n", static_cast<int>(operation.size()),
                   operation.data(), mb);
    }
  }
}

std::vector<std::string> readFileLines(std::string_view fname) {
  if (fname.empty())
    throw std::invalid_argument("Filename cannot be empty");

  auto ifs = path_validation::safe_ifstream(fname);
  ifs.exceptions(std::ios::badbit); // keep it cheap; avoid throw on eof

  std::vector<std::string> lines;
  lines.reserve(INITIAL_LINE_CAPACITY);

  std::string line;
  std::size_t count = 0;
  while (std::getline(ifs, line)) {
    validateLineCount(++count);
    lines.push_back(line);
  }
  return lines;
}

std::string readFileContent(std::string_view fname) {
  if (fname.empty())
    throw std::invalid_argument("Filename cannot be empty");

  auto ifs = path_validation::safe_ifstream(fname);
  ifs.exceptions(std::ios::badbit);

  std::string content;
  // Pre-allocate if size known
  try {
      if (isLargeFile(fname)) {
          // Skip pre-alloc for large files or handle differently?
          // readFileContent implies loading all into memory, so size check matters.
          // But isLargeFile checks > 1GB. We can just read.
      }
      auto sz = getFileSizeBytes(fname);
      if (sz > 0) content.reserve(sz);
  } catch(...) {}

  content.assign(std::istreambuf_iterator<char>(ifs),
                 std::istreambuf_iterator<char>());
  return content;
}

bool isLargeFile(std::string_view fname) {
  if (fname.empty())
    return false;
  try {
    const auto p = path_validation::validate_and_canonicalize(fname);
    // Prefer POSIX stat to avoid libstdc++ filesystem heavy code paths under MSan
    struct stat st{};
    if (::stat(p.c_str(), &st) != 0)
      return false;
    const auto s = static_cast<std::uintmax_t>(st.st_size);
    validateFileSize(static_cast<std::size_t>(s));
    return s >= static_cast<std::uintmax_t>(LARGE_FILE_THRESHOLD_MB) * MB_TO_BYTES;
  } catch (...) {
    return false;
  }
}

void processFileStream(std::string_view fname, const Options& opt) {
  if (fname.empty())
    throw std::invalid_argument("Filename cannot be empty");
  LogProcessor processor(opt);
  // Prefer C stdio path to avoid libstdc++ internal locale/stream interactions with MSan
  FileHandle fh(fname.data(), "r");
  processor.processStreamCFile(fh.get());
}

// ---- FileHandle Implementation ----

FileHandle::FileHandle(const char* filename, const char* mode) {
  fp = path_validation::safe_fopen(filename, mode);
  if (!fp) {
    // safe_fopen might throw, but if it returned null without throw (unlikely given design), we check here.
    // Actually safe_fopen throws on error, so fp is valid here.
  }
}

FileHandle::~FileHandle() {
  if (fp) {
    std::fclose(fp);
  }
}

FileHandle::FileHandle(FileHandle&& other) noexcept : fp(other.fp) {
  other.fp = nullptr;
}

FileHandle& FileHandle::operator=(FileHandle&& other) noexcept {
  if (this != &other) {
    if (fp)
      std::fclose(fp);
    fp = other.fp;
    other.fp = nullptr;
  }
  return *this;
}

std::FILE* FileHandle::get() const noexcept {
  return fp;
}

FileHandle::operator bool() const noexcept {
  return fp != nullptr;
}

std::size_t getFileSizeBytes(std::string_view fname) {
  if (fname.empty())
    return 0;
  try {
    const auto p = path_validation::validate_and_canonicalize(fname);
    struct stat st{};
    if (::stat(p.c_str(), &st) != 0)
      return 0;
    return static_cast<std::size_t>(st.st_size);
  } catch (...) {
    return 0;
  }
}

// ---- Pipe / Compression Support ----

namespace {

namespace {
    constexpr size_t kPipeBufferSize = 8192;
}

class PipeStreamBuf : public std::streambuf {
public:
  explicit PipeStreamBuf(FILE* fp) : fp_(fp), buffer_(kPipeBufferSize) {
      // Basic buffering
  }

  ~PipeStreamBuf() override {
    if (fp_) {
      pclose(fp_);
    }
  }

protected:
  int_type underflow() override {
    if (gptr() < egptr()) {
      return traits_type::to_int_type(*gptr());
    }
    const size_t n = std::fread(buffer_.data(), 1, buffer_.size(), fp_);
    if (n == 0) {
      return traits_type::eof();
    }
    setg(buffer_.data(), buffer_.data(), buffer_.data() + n);
    return traits_type::to_int_type(*gptr());
  }

private:
  FILE* fp_;
  std::vector<char> buffer_;
};

class PipeStream : public std::istream {
public:
  explicit PipeStream(FILE* fp) : std::istream(nullptr), buf_(fp) {
    rdbuf(&buf_);
  }
private:
  PipeStreamBuf buf_;
};

} // namespace

std::unique_ptr<std::istream> openInputFile(const std::string& path) {
  if (path.length() > 3 && path.substr(path.length() - 3) == ".gz") {
    std::string cmd = "gzip -dc '" + path + "'";
    FILE* fp = popen(cmd.c_str(), "r");
    if (!fp) {
      throw std::runtime_error("Failed to open pipe for " + path);
    }
    return std::make_unique<PipeStream>(fp);
  }
  return std::make_unique<std::ifstream>(path_validation::safe_ifstream(path));
}