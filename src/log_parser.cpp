#include "log_parser.h"
#include <algorithm>
#include <cctype>

namespace {
constexpr bool is_digit(char c) noexcept {
  return std::isdigit(static_cast<unsigned char>(c)) != 0;
}
} // namespace

std::optional<std::pair<std::string, std::string>> LogParser::parse_header(std::string_view line) {
  if (line.size() < 2 || line[0] != '=' || line[1] != '=') {
    return std::nullopt;
  }
  auto content = remove_prefix(line);
  if (content.empty())
    return std::nullopt;

  // Extract PID from the original line if present
  // Format: ==12345== Error Type...
  std::string pid;
  if (line.size() >= 2 && line[0] == '=' && line[1] == '=') {
    size_t end_pid = line.find("==", 2);
    if (end_pid != std::string_view::npos) {
      pid = std::string(line.substr(2, end_pid - 2));
    }
  }

  // Heuristic: Check if content looks like a known error start
  // We don't strictly enforce "Invalid read" keys here to allow generic errors,
  // but the caller might filter.

  // Clean trailing copy-paste artifacts if any
  std::string error_type(content);
  while (!error_type.empty() && std::isspace(static_cast<unsigned char>(error_type.back()))) {
    error_type.pop_back();
  }

  return std::make_pair(std::move(pid), std::move(error_type));
}

std::optional<std::string> LogParser::parse_stack_frame(std::string_view line) {
  // Expected: "   at 0x..." or "   by 0x..."
  // But processed line might have prefix removed already.
  // Let's assume input is full line.

  auto content = remove_prefix(line);
  if (content.find("at : ") != std::string_view::npos ||
      content.find("by : ") != std::string_view::npos ||
      content.find("at 0x") != std::string_view::npos ||
      content.find("by 0x") != std::string_view::npos) {

    return std::string(content);
  }

  return std::nullopt;
}

std::string_view LogParser::remove_prefix(std::string_view line) {
  // ==12345== prefix
  if (line.size() < 2 || line[0] != '=' || line[1] != '=') {
    return line;
  }

  size_t i = 2;
  while (i < line.size() && is_digit(line[i]))
    ++i;

  if (i < line.size() && line[i] == '=' && i + 1 < line.size() && line[i + 1] == '=') {
    i += 2;
    while (i < line.size() && std::isspace(static_cast<unsigned char>(line[i])))
      ++i;
    return line.substr(i);
  }

  return line;
}
