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
#include "options.h"
#include "source_loader.h"
#include "parsers/i_parser.h"
#include "threading/thread_pool.h"
#include <queue>
#include <condition_variable>
#include <mutex>



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
                                          std::size_t totalBytes) const;

  void outputPendingBlocks();

  [[nodiscard]] LogEntry parseEntry(const std::string& rawBlock,
                                    const std::string& signature) const;
  // Helper for debug logging
  void logDebug(std::string_view msg) const noexcept;

  const Options& opt;
  LogFilter filter; 

  std::string raw;
  std::unordered_set<Str> seen;

  // stream-mode buffer
  std::vector<LogEntry> pendingBlocks;
  bool markerFound{false};

  // Stats
  LogStats stats;

  // Writer
  std::unique_ptr<ILogWriter> writer;

  // pattern placeholders
  std::unique_ptr<parsers::IParser> parser;


  int32_t pendingPid = 0;

  mutable SourceLoader sourceLoader; // Iteration 2: Cache source files

  // Iteration 2: Parallel Processing
  struct RawBlock {
    std::string content;
    int32_t pid = 0;
    size_t startLine = 0;
  };

  struct ProcessedResult {
    LogEntry entry;
    bool kept;
    bool error;
    size_t linesProcessed = 0;
  };

  [[nodiscard]] ProcessedResult processBlock(RawBlock&& block);
  void finalizeResult(ProcessedResult& res);

  void processStreamParallel(std::istream& in);
  // void pushRawBlock(RawBlock&& block); // Removed - unused
  // void workerLoop(); // Removed - unused
  
  std::unique_ptr<ThreadPool> threadPool;
  std::queue<ProcessedResult> resultQueue;
  std::mutex resultMutex;
  std::condition_variable resultCv;
};