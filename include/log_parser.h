#pragma once

#include "log_entry.h"
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

class LogParser {
public:
  struct HeaderResult {
    std::string pid;
    std::string error_type;
    std::optional<int32_t> tid;
  };

  /**
   * @brief Parses a header line to extract PID, Error Type, and optional Thread ID.
   *
   * @param line The line to parse (e.g. "==12345== Thread 2: Invalid read...")
   * @return HeaderResult if successful, or std::nullopt.
   */
  static std::optional<HeaderResult> parse_header(std::string_view line);

  /**
   * @brief Parses a stack frame line.
   *
   * @param line The line to parse (e.g. "   at 0x4C2...: malloc (vg_replace_malloc.c:299)")
   * @return The cleaned stack frame content if it matches known patterns.
   */
  static std::optional<std::string> parse_stack_frame(std::string_view line);

  /**
   * @brief Helper to remove the Valgrind prefix "==12345== ".
   */
  static std::string_view remove_prefix(std::string_view line);
};
