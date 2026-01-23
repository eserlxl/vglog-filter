#include "log_parser.h"
#include <algorithm>
#include <cctype>

namespace {
constexpr bool is_digit(char c) noexcept {
  return std::isdigit(static_cast<unsigned char>(c)) != 0;
}
} // namespace

std::optional<LogParser::HeaderResult> LogParser::parse_header(std::string_view line) {
  // Relaxed check: if it doesn't start with ==, assume it's just content
  bool has_prefix = (line.size() >= 2 && line[0] == '=' && line[1] == '=');

  std::string_view content_view = line;
  std::string pid;

  if (has_prefix) {
    content_view = remove_prefix(line);
    size_t end_pid = line.find("==", 2);
    if (end_pid != std::string_view::npos) {
      pid = std::string(line.substr(2, end_pid - 2));
    }
  }

  // Trim leading whitespace
  while (!content_view.empty() && std::isspace(content_view.front())) {
    content_view.remove_prefix(1);
  }

  if (content_view.empty())
    return std::nullopt;

  // Check for Thread ID (e.g., "Thread 2: ...")
  std::optional<int32_t> tid;
  std::string_view error_part = content_view;

  if (content_view.starts_with("Thread ")) {
    size_t pos = 7; // "Thread " length
    size_t num_start = pos;
    while (pos < content_view.size() && is_digit(content_view[pos])) {
      pos++;
    }
    if (pos > num_start && pos < content_view.size() && content_view[pos] == ':') {
      // Found "Thread N:"
      std::string_view num_str = content_view.substr(num_start, pos - num_start);
      try {
        tid = std::stoi(std::string(num_str));
        // Skip ": "
        pos++;
        if (pos < content_view.size() && content_view[pos] == ' ')
          pos++;
        error_part = content_view.substr(pos);
      } catch (...) {
        // Parse error, ignore tid
      }
    }
  }

  // Clean trailing copy-paste artifacts if any
  std::string error_type(error_part);
  while (!error_type.empty() && std::isspace(static_cast<unsigned char>(error_type.back()))) {
    error_type.pop_back();
  }

  return HeaderResult{std::move(pid), std::move(error_type), tid};
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
