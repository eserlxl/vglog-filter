// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "path_validation.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <limits.h>
#include <stdexcept>
#include <string>
#include <unistd.h>
#include <vector>

namespace path_validation {

namespace {
inline constexpr char NULL_BYTE = '\0';
inline constexpr std::string_view STDIN_MARKER{"-"};

constexpr bool is_dangerous_char(char c) noexcept {
  // basic shell/meta chars
  constexpr std::string_view bad = "`$(){}[]|&;<>\"'\\";
  for (char b : bad)
    if (b == c)
      return true;
  return false;
}

[[nodiscard]] bool contains_dangerous(std::string_view s) noexcept {
  for (char c : s)
    if (is_dangerous_char(c))
      return true;
  return false;
}

[[nodiscard]] bool starts_drive(std::string_view s) noexcept {
  // Windows drive: C:\ or C:/
  return s.size() > 2 && s[1] == ':' && (s[2] == '/' || s[2] == '\\');
}

[[nodiscard]] std::string get_current_working_directory() {
  char* buffer = ::getcwd(nullptr, 0);
  if (buffer == nullptr) {
    throw std::runtime_error("Failed to get current working directory");
  }
  std::string cwd(buffer);
  std::free(buffer);
  if (cwd.empty()) {
    throw std::runtime_error("Empty current working directory");
  }
  // Remove trailing slash except for root
  if (cwd.size() > 1 && cwd.back() == '/')
    cwd.pop_back();
  return cwd;
}

[[nodiscard]] std::vector<std::string> split_path_components(std::string_view path) {
  std::vector<std::string> components;
  std::size_t start = 0;
  while (start <= path.size()) {
    const std::size_t pos = path.find('/', start);
    const std::size_t len = (pos == std::string_view::npos ? path.size() : pos) - start;
    if (len > 0) {
      const std::string part(path.substr(start, len));
      if (part != ".") {
        if (part == "..") {
          if (!components.empty())
            components.pop_back();
        } else {
          components.push_back(part);
        }
      }
    }
    if (pos == std::string_view::npos)
      break;
    start = pos + 1;
  }
  return components;
}

[[nodiscard]] std::string join_components_as_absolute(const std::vector<std::string>& components) {
  std::string result;
  result.reserve(64);
  result.push_back('/');
  for (std::size_t i = 0; i < components.size(); ++i) {
    result.append(components[i]);
    if (i + 1 < components.size())
      result.push_back('/');
  }
  return result;
}

} // namespace

std::string sanitize_path_for_file_access(std::string_view input_path) {
  if (input_path.empty() || input_path.find(NULL_BYTE) != std::string_view::npos) {
    throw std::runtime_error("Invalid path: empty or contains null bytes.");
  }
  if (contains_dangerous(input_path)) {
    throw std::runtime_error("Invalid path: contains dangerous characters.");
  }
  if (input_path.front() == '/' || starts_drive(input_path)) {
    throw std::runtime_error("Absolute paths are not allowed for security reasons.");
  }
  // Disallow traversal tokens
  if (input_path.find("..") != std::string_view::npos) {
    throw std::runtime_error("Path traversal attempt detected.");
  }
  return std::string{input_path};
}

std::filesystem::path validate_and_canonicalize(std::string_view input_path) {
  if (input_path == STDIN_MARKER) {
    return std::filesystem::path(STDIN_MARKER);
  }
  const std::string sanitized_rel = sanitize_path_for_file_access(input_path);

  const std::string base_dir = get_current_working_directory();

  std::vector<std::string> base_components = split_path_components(base_dir);
  const std::size_t base_size = base_components.size();

  std::vector<std::string> rel_components = split_path_components(sanitized_rel);

  std::vector<std::string> combined;
  combined.reserve(base_components.size() + rel_components.size());
  for (const auto& c : base_components)
    combined.push_back(c);
  for (const auto& c : rel_components) {
    if (c == "..") {
      if (combined.size() > base_size)
        combined.pop_back();
      else
        throw std::runtime_error("Resolved path escapes working directory.");
    } else if (c == "." || c.empty()) {
      continue;
    } else {
      combined.push_back(c);
    }
  }

  const std::string resolved_abs = join_components_as_absolute(combined);

  if (!(resolved_abs.size() >= base_dir.size() &&
        (resolved_abs == base_dir ||
         (resolved_abs.compare(0, base_dir.size(), base_dir) == 0 &&
          (resolved_abs.size() == base_dir.size() || resolved_abs[base_dir.size()] == '/'))))) {
    throw std::runtime_error("Resolved path escapes working directory.");
  }

  return std::filesystem::path(resolved_abs);
}

std::ifstream safe_ifstream(std::string_view filename) {
  if (filename == STDIN_MARKER) {
    throw std::runtime_error("Cannot open stdin with ifstream.");
  }
  const auto path = validate_and_canonicalize(filename);
  std::ifstream ifs(path, std::ios::in);
  ifs.exceptions(std::ios::badbit);
  if (!ifs.is_open()) {
    throw std::runtime_error("Failed to open file: " + path.string());
  }
  return ifs;
}

std::FILE* safe_fopen(std::string_view filename, const char* mode) {
  if (filename == STDIN_MARKER) {
    throw std::runtime_error("Cannot open stdin with fopen.");
  }
  const auto path = validate_and_canonicalize(filename);
  std::FILE* fp = std::fopen(path.c_str(), mode);
  if (fp == nullptr) {
    throw std::runtime_error("Failed to open file: " + path.string());
  }
  return fp;
}

} // namespace path_validation