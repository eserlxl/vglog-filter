// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include "log_entry.h"
#include "options.h"

#include <cstdio>
#include <memory>
#include <string>

/**
 * @brief Handles writing processed logs to output (File or Stdout).
 *
 * Encapsulates logic for:
 * - Opening/Closing files (RAII)
 * - Log rotation based on size
 * - Formatting (JSON vs Raw)
 * - Flushing
 */
class LogWriter : public ILogWriter {
public:
  explicit LogWriter(const Options& options);
  ~LogWriter();

  // Non-copyable
  LogWriter(const LogWriter&) = delete;
  LogWriter& operator=(const LogWriter&) = delete;

  // Move-only
  LogWriter(LogWriter&&) noexcept;
  LogWriter& operator=(LogWriter&&) noexcept;

  /**
   * @brief Writes a structured log entry.
   *
   * Formats as JSON or Raw text based on options provided at construction.
   * Checks rotation limits before writing to files.
   *
   * @param entry The log entry to write.
   */
  void writeEntry(const LogEntry& entry) override;

  /**
   * @brief Writes raw string content directly.
   *
   * @param content Raw data to write.
   */
  void writeRaw(const std::string& content) override;

  /**
   * @brief Writes statistics block.
   *
   * In JSON mode, writes a "stats" record.
   * In Text mode, writes a human-readable summary table.
   *
   * @param stats The statistics to output.
   */
  void writeStats(const struct LogStats& stats) override;

  // Iteration 1 Extensions
  void setUseColor(bool enable) override;
  void writeStatsJson(const struct LogStats& stats, const std::string& path) const override;

  /**
   * @brief Flushes the underlying output stream.
   */
  void flush() override;

private:
  struct Impl;
  std::unique_ptr<Impl> pImpl;
};
