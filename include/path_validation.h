// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef PATH_VALIDATION_H
#define PATH_VALIDATION_H

#include <string>
#include <vector>
#include <stdexcept>
#include <filesystem>
#include <unistd.h>
#include <climits>
#include <fstream>
#include <sys/stat.h>

namespace path_validation {

// Get the current working directory, which serves as the security root.
inline std::filesystem::path get_secure_base_directory() {
    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) == nullptr) {
        throw std::runtime_error("Failed to get current working directory");
    }
    return std::filesystem::path(cwd);
}

// Check if a path contains path traversal attempts
inline bool contains_path_traversal(const std::string& path) {
    // Check for common path traversal patterns
    const std::vector<std::string> dangerous_patterns = {
        "..",           // Parent directory
        "~",            // Home directory expansion
        "//",           // Multiple slashes (could be used for path manipulation)
        "\\",           // Windows backslash (potential cross-platform issue)
    };
    
    for (const auto& pattern : dangerous_patterns) {
        if (path.find(pattern) != std::string::npos) {
            return true;
        }
    }
    
    // Check for absolute paths (except for stdin indicator)
    if (!path.empty() && path[0] == '/' && path != "-") {
        return true;
    }
    
    return false;
}

// Validates a given file path to ensure it is safe to use.
// A path is considered safe if it is within the secure base directory.
inline std::string validate_file_path(const std::string& input_path) {
    if (input_path == "-") {
        return input_path; // Special case for stdin
    }

    if (input_path.empty()) {
        return ".";
    }

    if (input_path.find('\0') != std::string::npos) {
        throw std::runtime_error("Path contains null bytes: " + input_path);
    }

    if (input_path.length() > PATH_MAX) {
        throw std::runtime_error("Path too long: " + input_path);
    }

    // Check for path traversal attempts before filesystem operations
    if (contains_path_traversal(input_path)) {
        throw std::runtime_error("Path traversal attempt detected: " + input_path);
    }

    const auto base_dir = get_secure_base_directory();
    const auto full_path = base_dir / input_path;
    
    // Lexically normal path is the simplest form of the path without resolving symlinks.
    const auto normal_path = full_path.lexically_normal();

    // Check if the normalized path is within the base directory.
    // This is a check to prevent path traversal attacks like "../"
    auto [root_end, nothing] = std::mismatch(base_dir.begin(), base_dir.end(), normal_path.begin());

    if (root_end != base_dir.end()) {
        throw std::runtime_error("Path traversal attempt detected: " + input_path);
    }

    // Re-check for path traversal after normalization
    std::string normalized_str = std::filesystem::relative(normal_path, base_dir).string();
    if (contains_path_traversal(normalized_str)) {
        throw std::runtime_error("Path traversal attempt detected after normalization: " + normalized_str);
    }

    return normalized_str;
}

// Safely opens a file using fopen after validating the path.
// Returns nullptr for stdin ("-"), which the caller must handle.
inline FILE* safe_fopen(const std::string& filename, const char* mode) {
    const std::string validated_path = validate_file_path(filename);
    if (validated_path == "-") {
        return nullptr; // Indicates stdin, caller should use stdin stream
    }
    const auto full_path = get_secure_base_directory() / validated_path;
    return fopen(full_path.c_str(), mode);
}

// Safely opens a file stream (ifstream) after validating the path.
// Throws an error for stdin ("-") as ifstream does not directly support it.
inline std::ifstream safe_ifstream(const std::string& filename) {
    const std::string validated_path = validate_file_path(filename);
    if (validated_path == "-") {
        throw std::runtime_error("stdin ('-') is not supported for ifstream. Please handle it separately.");
    }
    const auto full_path = get_secure_base_directory() / validated_path;
    return std::ifstream(full_path);
}

// Safely gets file status (stat) after validating the path.
// Returns -1 for stdin ("-").
inline int safe_stat(const std::string& filename, struct stat* st) {
    const std::string validated_path = validate_file_path(filename);
    if (validated_path == "-") {
        return -1; // Indicates stdin, which has no file status
    }
    const auto full_path = get_secure_base_directory() / validated_path;
    return stat(full_path.c_str(), st);
}

} // namespace path_validation

#endif // PATH_VALIDATION_H 