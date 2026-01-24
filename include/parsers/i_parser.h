#pragma once

#include "log_entry.h"
#include <string>
#include <string_view>

namespace parsers {

/**
 * @brief Interface for sanitizer-specific log parsing strategies.
 */
class IParser {
public:
  virtual ~IParser() = default;

  /**
   * @brief Determines if the line marks the start of a new error block.
   */
  [[nodiscard]] virtual bool isBlockStart(std::string_view line) const = 0;

  /**
   * @brief Determines if the line is relevant to this sanitizer (should be buffered).
   */
  [[nodiscard]] virtual bool isRelevant(std::string_view line) const = 0;

  /**
   * @brief Parses a complete raw block into a structured entry.
   */
  [[nodiscard]] virtual LogEntry parseBlock(std::string_view rawBlock) const = 0;

  /**
   * @brief Cleans a line for signature generation (canonicalization).
   */
  [[nodiscard]] virtual std::string scrubLine(const std::string& line) const = 0;

  /**
   * @brief Cleans a line for raw validation/storage (e.g. removing pointers).
   */
  [[nodiscard]] virtual std::string cleanRaw(const std::string& line) const = 0;

  /**
   * @brief Extracts PID from a single line if present.
   */

  [[nodiscard]] virtual std::optional<int32_t> extractPid(std::string_view line) const = 0;

  /**
   * @brief Returns the name of the parser strategy.
   * @return Parser name (e.g. "Valgrind", "AddressSanitizer")
   */
  [[nodiscard]] virtual std::string_view name() const = 0;
};


} // namespace parsers
