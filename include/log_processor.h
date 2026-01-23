// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include "file_utils.h"
#include "ilog_writer.h"
#include "log_entry.h"
#include "log_filter.h"
#include "log_writer.h" // Keep for default impl creation? Or prefer ILogWriter?
#include "options.h"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <iosfwd>
#include <memory>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// Basic processing statistics
struct LogStats {
  std::size_t linesRead = 0;
  std::size_t bytesProcessed = 0;
  std::size_t blocksFound = 0;
  std::size_t uniqueBlocks = 0;
  std::size_t filteredCount = 0;
  std::size_t parseErrors = 0;
  std::unordered_map<std::string, std::size_t> errorCounts;
  std::unordered_map<int32_t, std::size_t> errorCountsByPid;
  std::unordered_map<int32_t, std::size_t> errorCountsByTid;
};

/**
 * @brief Main processor class for Valgrind logs.
 *
 * Handles reading input streams, identifying error blocks, filtering them based on Options,
 * and dispatching to LogWriter.
 * Not thread-safe.
 */
class LogProcessor {
public:
  using Str = std::string;
  using VecS = std::vector<Str>;
  using StrSpan = std::span<const Str>;

  /**
   * @brief Constructs a new Log Processor.
   * @param options Configuration options. Must remain valid for object lifetime.
   * @param writer Optional custom writer (dependency injection). If null, creates default LogWriter.
   */
  explicit LogProcessor(const Options& options, std::unique_ptr<ILogWriter> writer = nullptr);
  ~LogProcessor();

  /**
   * @brief Process logs from a C++ input stream (e.g. ifstream).
   * @param in Input stream to read from.
   */
  void processStream(std::istream& in);

  /**
   * @brief Process logs from a C file pointer (e.g. stdin).
   * @param fp C file pointer (must be valid).
   */
  void processStreamCFile(std::FILE* fp);

  /**
   * @brief Process a pre-loaded vector of log lines.
   * @param lines Vector of strings representing lines.
   */
  void processLines(const VecS& lines);

  /**
   * @brief Get the current processing statistics.
   * @return const LogStats& Reference to stats struct.
   */
  [[nodiscard]] const LogStats& getStats() const noexcept {
    return stats;
  }

  /**
   * @brief Print statistics to a file pointer.
   * @param out Output C file pointer.
   */
  void printStats(std::FILE* out) const;
  void saveStatsJson() const; // Iteration 1
  void flush();

private:
  void processLine(std::string_view line);
  void clearCurrentState() noexcept;
  void resetEpoch() noexcept;
  [[nodiscard]] std::size_t findMarker(const VecS& lines) const;

  void initializeStringPatterns();
  [[nodiscard]] std::size_t getFileSizeForProgress() const;
  [[nodiscard]] bool shouldReportProgress(std::size_t bytesProcessed,
                                          std::size_t total_bytes) const;

  void outputPendingBlocks();

  [[nodiscard]] LogEntry parseEntry(const std::string& raw_block,
                                    const std::string& signature) const;
  [[nodiscard]] std::string processRawLine(const std::string& processed_line) const;
  [[nodiscard]] std::string generateSignatureKey() const;

  // String matching helpers (regex-free)
  [[nodiscard]] bool matchesVgLine(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesPrefix(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesStartPattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesBytesHead(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesAtPattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesByPattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesQPattern(std::string_view line) const noexcept;

  std::string replacePatterns(const std::string& line) const;

  const Options& opt;
  LogFilter filter; // New encapsulated filter

  std::string raw;
  std::string sig;
  VecS sigLines;
  std::unordered_set<Str> seen;

  // stream-mode buffer
  std::vector<LogEntry> pendingBlocks;
  bool markerFound{false};

  // Stats
  LogStats stats;

  // Writer
  std::unique_ptr<ILogWriter> writer;

  // pattern placeholders
  std::string vgPattern;
  std::string prefixPattern;
  std::string startPattern;
  std::string bytesHeadPattern;
  std::string atPattern;
  std::string byPattern;
  std::string qPattern;

  std::string pendingPid;
};