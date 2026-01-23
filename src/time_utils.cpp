#include "time_utils.h"

#include <algorithm>
#include <charconv>
#include <iomanip>
#include <sstream>

namespace time_utils {

std::string normalizeTimestamp(std::string_view ts) {
  // Simple normalization: try to find HH:MM:SS pattern
  // If found, return it. If not, return original if it looks like a number?
  // Valgrind often uses "HH:MM:SS" or just relative time.
  // We'll search for the first occurrence of digit:digit:digit

  if (ts.empty())
    return "";

  // Heuristic: Find first ':'
  auto firstColon = ts.find(':');
  if (firstColon == std::string_view::npos || firstColon == 0)
    return std::string(ts); // No colon, return as is (maybe raw seconds)

  // Check if we have digits before
  size_t start = firstColon;
  while (start > 0 && std::isdigit(ts[start - 1])) {
    start--;
  }

  // Check if we have digits after
  size_t end = firstColon + 1;
  while (end < ts.size() && (std::isdigit(ts[end]) || ts[end] == ':' || ts[end] == '.')) {
    end++;
  }

  return std::string(ts.substr(start, end - start));
}

bool isAfter(std::string_view ts, std::string_view reference) {
  return normalizeTimestamp(ts) > normalizeTimestamp(reference);
}

bool isBefore(std::string_view ts, std::string_view reference) {
  return normalizeTimestamp(ts) < normalizeTimestamp(reference);
}

} // namespace time_utils
