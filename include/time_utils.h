#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace time_utils {

/**
 * @brief Normalizes a timestamp string to a comparable format (HH:MM:SS.mmm).
 *
 * Handles formats like:
 * - "HH:MM:SS"
 * - "HH:MM:SS.ms"
 * - "day HH:MM:SS" (strips day)
 *
 * @param ts The timestamp string to parse.
 * @return Normalized string or empty if invalid.
 */
std::string normalizeTimestamp(std::string_view ts);

/**
 * @brief Checks if a timestamp is after a reference.
 */
bool isAfter(std::string_view ts, std::string_view reference);

/**
 * @brief Checks if a timestamp is before a reference.
 */
bool isBefore(std::string_view ts, std::string_view reference);

} // namespace time_utils
