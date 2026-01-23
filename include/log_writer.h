// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

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
class LogWriter {
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
  void write_entry(const LogEntry& entry);

  /**
   * @brief Writes raw string content directly.
   *
   * @param content Raw data to write.
   */
  void write_raw(const std::string& content);

  /**
   * @brief Writes statistics block.
   */
  void writeStats(const struct LogStats& stats);

  /**
   * @brief Flushes the underlying output stream.
   */
  void flush();

private:
  struct Impl;
  std::unique_ptr<Impl> pImpl;
};
