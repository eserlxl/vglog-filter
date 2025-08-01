// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <path_validation.h>
#include <stdexcept>

namespace path_validation {

std::filesystem::path validate_and_canonicalize(std::string_view input_path) {
    if (input_path.empty() || input_path.find('\0') != std::string_view::npos) {
        throw std::runtime_error("Invalid path: empty or contains null bytes.");
    }
    if (input_path == "-") {
        return std::filesystem::path("-");
    }
    const std::string path_str(input_path);
    const std::filesystem::path path(path_str);
    if (path.is_absolute()) {
        throw std::runtime_error("Absolute paths are not allowed for security reasons: " + path_str);
    }
    std::filesystem::path base_dir;
    try {
        base_dir = std::filesystem::current_path();
    } catch (const std::filesystem::filesystem_error& e) {
        throw std::runtime_error("Failed to get current working directory: " + std::string(e.what()));
    }
    std::filesystem::path full_path = base_dir / path;
    std::filesystem::path canonical_path;
    try {
        canonical_path = std::filesystem::weakly_canonical(full_path);
    } catch (const std::filesystem::filesystem_error& e) {
        throw std::runtime_error("Failed to canonicalize path: " + std::string(e.what()));
    }
    auto base_it = base_dir.begin();
    auto path_it = canonical_path.begin();
    while (base_it != base_dir.end() && path_it != canonical_path.end() && *base_it == *path_it) {
        ++base_it;
        ++path_it;
    }
    if (base_it != base_dir.end()) {
        throw std::runtime_error("Path traversal attempt detected: " + path_str);
    }
    return canonical_path;
}

std::ifstream safe_ifstream(std::string_view filename) {
    if (filename == "-") {
        throw std::runtime_error("Cannot open stdin with ifstream.");
    }
    const std::filesystem::path validated_path = validate_and_canonicalize(filename);
    if (!std::filesystem::exists(validated_path)) {
        throw std::runtime_error("File does not exist: " + validated_path.string());
    }
    if (!std::filesystem::is_regular_file(validated_path)) {
        throw std::runtime_error("Path is not a regular file: " + validated_path.string());
    }
    return std::ifstream(validated_path);
}

} // namespace path_validation