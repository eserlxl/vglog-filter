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
    return 0; // Failure indistinguishable from 0? Context matters. But local helper.
  return val;
}

std::optional<int64_t> parseComponentSafe(std::string_view sv) {
  int64_t val = 0;
  auto [ptr, ec] = std::from_chars(sv.data(), sv.data() + sv.size(), val);
  if (ec != std::errc())
    return std::nullopt;
  return val;
}

std::optional<int64_t> timestampToMsInternal(std::string_view ts) {
  if (ts.empty())
    return std::nullopt;

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
    if (auto h = parseComponentSafe(parts[0])) hours = *h; else return std::nullopt;
    if (auto m = parseComponentSafe(parts[1])) mins = *m; else return std::nullopt;
    
    std::string_view secPart = parts[2];
    auto dot = secPart.find('.');
    if (dot != std::string_view::npos) {
      if (auto s = parseComponentSafe(secPart.substr(0, dot))) secs = *s; else return std::nullopt;
      // Handle MS: if ".1" -> 100ms? Standard strptime behavior or custom?
      // Assuming digits are ms value for now to match legacy.
      if (auto m = parseComponentSafe(secPart.substr(dot + 1))) ms = *m; else return std::nullopt;
    } else {
      if (auto s = parseComponentSafe(secPart)) secs = *s; else return std::nullopt;
    }
  } else if (parts.size() == 2) {
    if (auto m = parseComponentSafe(parts[0])) mins = *m; else return std::nullopt;
    
    std::string_view secPart = parts[1];
    auto dot = secPart.find('.');
    if (dot != std::string_view::npos) {
      if (auto s = parseComponentSafe(secPart.substr(0, dot))) secs = *s; else return std::nullopt;
      if (auto m = parseComponentSafe(secPart.substr(dot + 1))) ms = *m; else return std::nullopt;
    } else {
      if (auto s = parseComponentSafe(secPart)) secs = *s; else return std::nullopt;
    }
  } else {
    // Attempt Date-style? "day HH:MM:SS" is already handled by normalizeTimestamp stripping "day".
    // If it's just raw number?
    return std::nullopt;
  }

  return (hours * 3600000) + (mins * 60000) + (secs * 1000) + ms;
}

} // namespace

std::string normalizeTimestamp(std::string_view ts) {
  // Try to find HH:MM:SS pattern for display/storage
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

int64_t timestampToMs(std::string_view ts) {
  auto res = timestampToMsInternal(ts);
  return res.value_or(-1);
}

std::optional<int64_t> timestampToMsSafe(std::string_view ts) {
  return timestampToMsInternal(ts);
}

bool isAfter(std::string_view ts, std::string_view reference) {
  auto tVal = timestampToMsSafe(normalizeTimestamp(ts));
  auto rVal = timestampToMsSafe(normalizeTimestamp(reference));
  
  // Lexicographical fallback if parsing fails (legacy behavior maintained but cleaned)
  if (!tVal || !rVal)
    return normalizeTimestamp(ts) > normalizeTimestamp(reference);
    
  return *tVal > *rVal;
}

bool isBefore(std::string_view ts, std::string_view reference) {
  auto tVal = timestampToMsSafe(normalizeTimestamp(ts));
  auto rVal = timestampToMsSafe(normalizeTimestamp(reference));
  
  if (!tVal || !rVal)
    return normalizeTimestamp(ts) < normalizeTimestamp(reference);
    
  return *tVal < *rVal;
}

} // namespace time_utils
