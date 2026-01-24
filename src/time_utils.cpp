#include "time_utils.h"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <vector>

namespace time_utils {

namespace {

int64_t parseComponent(std::string_view sv) {
  int64_t val = 0;
  auto [ptr, ec] = std::from_chars(sv.data(), sv.data() + sv.size(), val);
  if (ec != std::errc())
    return 0;
  return val;
}

int64_t timestampToMs(std::string_view ts) {
  if (ts.empty())
    return -1;

  // Split by ':'
  std::vector<std::string_view> parts;
  size_t start = 0;
  size_t pos = 0;
  while ((pos = ts.find(':', start)) != std::string_view::npos) {
    parts.push_back(ts.substr(start, pos - start));
    start = pos + 1;
  }
  parts.push_back(ts.substr(start));

  int64_t hours = 0, mins = 0, secs = 0, ms = 0;

  if (parts.size() >= 3) {
    hours = parseComponent(parts[0]);
    mins = parseComponent(parts[1]);
    std::string_view secPart = parts[2];
    auto dot = secPart.find('.');
    if (dot != std::string_view::npos) {
      secs = parseComponent(secPart.substr(0, dot));
      auto msPart = secPart.substr(dot + 1);
      ms = parseComponent(msPart);
      // Pad/truncate ms to 3 digits?
      // If "1" -> 1ms? Or 100ms? Standard is usually digits.
      // Let's treat as value.
    } else {
      secs = parseComponent(secPart);
    }
  } else if (parts.size() == 2) {
    mins = parseComponent(parts[0]);
    // seconds logic same...
    std::string_view secPart = parts[1];
    auto dot = secPart.find('.');
    if (dot != std::string_view::npos) {
      secs = parseComponent(secPart.substr(0, dot));
      ms = parseComponent(secPart.substr(dot + 1));
    } else {
      secs = parseComponent(secPart);
    }
  } else {
    return -1; // Unknown format
  }

  return (hours * 3600000) + (mins * 60000) + (secs * 1000) + ms;
}

} // namespace

std::string normalizeTimestamp(std::string_view ts) {
  // Try to find HH:MM:SS pattern for display/storage
  // Keep existing heuristic logic for normalization output,
  // but maybe refine it.

  auto firstColon = ts.find(':');
  if (firstColon == std::string_view::npos)
    return std::string(ts);

  size_t start = firstColon;
  while (start > 0 && std::isdigit(ts[start - 1]))
    start--;

  size_t end = firstColon + 1;
  while (end < ts.size() && (std::isdigit(ts[end]) || ts[end] == ':' || ts[end] == '.'))
    end++;

  return std::string(ts.substr(start, end - start));
}

bool isAfter(std::string_view ts, std::string_view reference) {
  int64_t tVal = timestampToMs(normalizeTimestamp(ts));
  int64_t rVal = timestampToMs(normalizeTimestamp(reference));
  // Fallback to lex if parsing failed
  if (tVal < 0 || rVal < 0)
    return normalizeTimestamp(ts) > normalizeTimestamp(reference);
  return tVal > rVal;
}

bool isBefore(std::string_view ts, std::string_view reference) {
  int64_t tVal = timestampToMs(normalizeTimestamp(ts));
  int64_t rVal = timestampToMs(normalizeTimestamp(reference));
  if (tVal < 0 || rVal < 0)
    return normalizeTimestamp(ts) < normalizeTimestamp(reference);
  return tVal < rVal;
}

} // namespace time_utils
