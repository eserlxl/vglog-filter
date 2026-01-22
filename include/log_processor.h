// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include "file_utils.h"
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
#include <unordered_set>
#include <vector>

// Basic processing statistics
struct LogStats {
  std::size_t lines_read = 0;
  std::size_t bytes_processed = 0;
  std::size_t blocks_found = 0;
  std::size_t unique_blocks = 0;
};

class LogProcessor {
public:
  using Str = std::string;
  using VecS = std::vector<Str>;
  using StrSpan = std::span<const Str>;

  explicit LogProcessor(const Options& options);
  ~LogProcessor();

  void process_stream(std::istream& in);
  void process_stream_cfile(std::FILE* fp);
  void process_lines(const VecS& lines);

  [[nodiscard]] const LogStats& get_stats() const noexcept {
    return stats;
  }
  void print_stats(std::FILE* out) const;

private:
  void process_line(std::string_view line);
  void flush();
  void clear_current_state() noexcept;
  void reset_epoch() noexcept;
  [[nodiscard]] std::size_t find_marker(const VecS& lines) const;

  void initialize_string_patterns();
  [[nodiscard]] std::size_t get_file_size_for_progress() const;
  [[nodiscard]] bool should_report_progress(std::size_t bytes_processed,
                                            std::size_t total_bytes) const;

  void output_pending_blocks() const;
  void write_output(const void* data, size_t size) const;
  void write_output(char c) const;
  void write_json_record(const std::string& raw_block, const std::string& signature) const;

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

  [[nodiscard]] std::string replace_prefix(std::string_view line) const;
  [[nodiscard]] std::string replace_patterns(const std::string& line) const;

  const Options& opt;
  std::string raw;
  std::string sig;
  VecS sigLines;
  std::unordered_set<Str> seen;

  // stream-mode buffer
  std::vector<Str> pending_blocks;
  bool marker_found{false};

  // Stats and output
  LogStats stats;
  std::FILE* out_fp{stdout};
  // Used to keep the file handle alive if we opened it
  std::shared_ptr<void> file_handle_lifetime;

  // pattern placeholders
  std::string vg_pattern;
  std::string prefix_pattern;
  std::string start_pattern;
  std::string bytes_head_pattern;
  std::string at_pattern;
  std::string by_pattern;
  std::string q_pattern;
};