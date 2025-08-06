// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "path_validation.h"

#include <algorithm>
#include <cctype>
#include <stdexcept>
#include <string>

namespace path_validation {

namespace {
inline constexpr char        NULL_BYTE   = '\0';
inline constexpr std::string_view STDIN_MARKER{"-"};

constexpr bool is_dangerous_char(char c) noexcept {
    // basic shell/meta chars
    constexpr std::string_view bad = "`$(){}[]|&;<>\"'\\";
    for (char b : bad) if (b == c) return true;
    return false;
}

[[nodiscard]] bool contains_dangerous(std::string_view s) noexcept {
    for (char c : s) if (is_dangerous_char(c)) return true;
    return false;
}

[[nodiscard]] bool starts_drive(std::string_view s) noexcept {
    // Windows drive: C:\ or C:/
    return s.size() > 2 && s[1] == ':' && (s[2] == '/' || s[2] == '\\');
}

[[nodiscard]] bool within(const std::filesystem::path& child,
                          const std::filesystem::path& base) {
    auto child_it = child.begin();
    auto base_it  = base.begin();
    for (; base_it != base.end(); ++base_it, ++child_it) {
        if (child_it == child.end() || *child_it != *base_it) return false;
    }
    return true;
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
    const auto sanitized_rel = sanitize_path_for_file_access(input_path);

    const auto cwd    = std::filesystem::current_path();
    const auto joined = cwd / sanitized_rel;
    // weakly_canonical avoids throwing if intermediate parts don't exist
    const auto canon  = std::filesystem::weakly_canonical(joined);

    if (!within(canon, std::filesystem::weakly_canonical(cwd))) {
        throw std::runtime_error("Resolved path escapes working directory.");
    }
    return canon;
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

} // namespace path_validation