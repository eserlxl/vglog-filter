// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include "file_utils.h"
#include "log_entry.h"
#include "log_writer.h"
#include "options.h"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <iosfwd>
#include <memory>
#include <regex>
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
   */
  explicit LogProcessor(const Options& options);
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

private:
  void process_line(std::string_view line);
  void flush();
  void clear_current_state() noexcept;
  void reset_epoch() noexcept;
  [[nodiscard]] std::size_t find_marker(const VecS& lines) const;

  // Centralized filtering logic
  [[nodiscard]] bool shouldKeepEntry(const LogEntry& entry) const;

  void initialize_string_patterns();
  [[nodiscard]] std::size_t get_file_size_for_progress() const;
  [[nodiscard]] bool should_report_progress(std::size_t bytesProcessed,
                                            std::size_t total_bytes) const;

  void output_pending_blocks(); // Kept as it manages pending_blocks vector logic
  // Removed: write_output, write_json_record, rotate_log (moved to LogWriter)

  [[nodiscard]] LogEntry parse_entry(const std::string& raw_block,
                                     const std::string& signature) const;
  [[nodiscard]] std::string process_raw_line(const std::string& processed_line) const;
  [[nodiscard]] std::string generate_signature_key() const;

  // String matching helpers (regex-free)
  [[nodiscard]] bool matches_vg_line(std::string_view line) const noexcept;
  [[nodiscard]] bool matches_prefix(std::string_view line) const noexcept;
  [[nodiscard]] bool matches_start_pattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matches_bytes_head(std::string_view line) const noexcept;
  [[nodiscard]] bool matches_at_pattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matches_by_pattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matches_q_pattern(std::string_view line) const noexcept;

  std::string replace_patterns(const std::string& line) const;

  const Options& opt;
  std::string raw;
  std::string sig;
  VecS sigLines;
  std::unordered_set<Str> seen;

  // stream-mode buffer
  std::vector<LogEntry> pending_blocks;
  bool marker_found{false};

  // Stats
  LogStats stats;

  // Writer
  std::unique_ptr<LogWriter> writer;

  // pattern placeholders
  std::string vg_pattern;
  std::string prefix_pattern;
  std::string start_pattern;
  std::string bytes_head_pattern;
  std::string at_pattern;
  std::string by_pattern;
  std::string q_pattern;

  std::vector<std::regex> stack_regexes;
  std::string pendingPid;
};