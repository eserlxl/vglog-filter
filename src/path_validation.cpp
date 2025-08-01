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
        return "-"; // Special case for stdin
    }

    const std::filesystem::path path(input_path);

    if (path.is_absolute()) {
        throw std::runtime_error("Absolute paths are not allowed for security reasons: " + std::string(input_path));
    }

    std::filesystem::path base_dir;
    try {
        base_dir = std::filesystem::current_path();
    } catch (const std::filesystem::filesystem_error& e) {
        throw std::runtime_error("Failed to get current working directory: " + std::string(e.what()));
    }
    std::filesystem::path full_path = base_dir / path;

    // weakly_canonical resolves symlinks and normalizes the path (e.g., ., ..)
    // without requiring the path to exist.
    std::filesystem::path canonical_path = std::filesystem::weakly_canonical(full_path);

    // To prevent path traversal, we check if the canonical path is within the current working directory.
    // We do this by iterating over the path components and ensuring that the canonical path
    // starts with the components of the base directory.
    auto base_it = base_dir.begin();
    auto path_it = canonical_path.begin();

    while (base_it != base_dir.end() && path_it != canonical_path.end() && *base_it == *path_it) {
        ++base_it;
        ++path_it;
    }

    if (base_it != base_dir.end()) {
        throw std::runtime_error("Path traversal attempt detected: " + std::string(input_path));
    }

    return canonical_path;
}


std::ifstream safe_ifstream(std::string_view filename) {
    if (filename == "-") {
        throw std::runtime_error("Cannot open stdin with ifstream.");
    }
    std::filesystem::path validated_path = validate_and_canonicalize(filename);
    
    if (!std::filesystem::exists(validated_path)) {
        throw std::runtime_error("File does not exist: " + validated_path.string());
    }
    if (!std::filesystem::is_regular_file(validated_path)) {
        throw std::runtime_error("Path is not a regular file: " + validated_path.string());
    }

    return std::ifstream(validated_path);
}

} // namespace path_validation