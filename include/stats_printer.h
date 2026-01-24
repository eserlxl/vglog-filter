#pragma once

#include "log_processor.h" // For LogStats
#include <cstdio>

class StatsPrinter {
public:
  /**
   * @brief Output format for the statistics.
   */
  enum class Format : std::uint8_t { Text, Json };

  /**
   * @brief Prints the collected statistics to the specified stream.
   *
   * @param stats The statistics to print.
   * @param out The output stream (e.g. stdout).
   * @param format The output format (Text or JSON).
   * @param detailed Whether to include detailed PID/TID breakdowns.
   */
  static void print(const LogStats& stats, std::FILE* out, Format format, bool detailed = false);

private:
  static void printText(const LogStats& stats, std::FILE* out);
  static void printJson(const LogStats& stats, std::FILE* out, bool detailed);
};
