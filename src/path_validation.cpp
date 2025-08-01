// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <path_validation.h>
#include <stdexcept>

namespace path_validation {

std::filesystem::path validate_and_canonicalize(const std::string& input_path) {
    if (input_path.empty() || input_path.find('\0') != std::string::npos) {
        throw std::runtime_error("Invalid path: empty or contains null bytes.");
    }

    if (input_path == "-") {
        return "-"; // Special case for stdin
    }

    const std::filesystem::path path(input_path);

    // Disallow absolute paths
    if (path.is_absolute()) {
        throw std::runtime_error("Absolute paths are not allowed: " + input_path);
    }

    const std::filesystem::path base_dir = std::filesystem::current_path();
    std::filesystem::path full_path = base_dir / path;

    // The `weakly_canonical` function resolves symlinks and normalizes the path.
    // It doesn't require the path to exist.
    std::filesystem::path canonical_path = std::filesystem::weakly_canonical(full_path);

    // Check if the canonical path is still within the base directory.
    // This is a robust way to prevent path traversal attacks.
    auto [root_end, mismatch_path] = std::mismatch(base_dir.begin(), base_dir.end(), canonical_path.begin());

    if (root_end != base_dir.end()) {
        throw std::runtime_error("Path traversal attempt detected: " + input_path);
    }

    return canonical_path;
}


std::ifstream safe_ifstream(const std::string& filename) {
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
