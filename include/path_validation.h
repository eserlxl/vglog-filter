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
#include <fstream>
#include <filesystem>
#include <limits.h>
#include <sys/stat.h>
#include <cstdio>
#include <stdexcept>

// Check if a path contains path traversal attempts
bool contains_path_traversal(const std::string& path) {
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

// Validate and sanitize file path
std::string validate_file_path(const std::string& input_path) {
    // Special case for stdin
    if (input_path == "-") {
        return input_path;
    }
    
    // Check for path traversal attempts
    if (contains_path_traversal(input_path)) {
        throw std::runtime_error("Path traversal attempt detected: " + input_path);
    }
    
    // Check for null bytes or other dangerous characters
    if (input_path.find('\0') != std::string::npos) {
        throw std::runtime_error("Path contains null bytes: " + input_path);
    }
    
    // Check path length
    if (input_path.length() > PATH_MAX) {
        throw std::runtime_error("Path too long: " + input_path);
    }
    
    // Normalize the path to prevent double-dot traversal
    try {
        std::filesystem::path normalized_path = std::filesystem::path(input_path).lexically_normal();
        std::string result = normalized_path.string();
        
        // Re-check for path traversal after normalization
        if (contains_path_traversal(result)) {
            throw std::runtime_error("Path traversal attempt detected after normalization: " + result);
        }
        
        return result;
    } catch (const std::exception& e) {
        throw std::runtime_error("Path validation failed: " + std::string(e.what()));
    }
}

// Safe file opening with path validation
FILE* safe_fopen(const std::string& filename, const char* mode) {
    std::string validated_path = validate_file_path(filename);
    return fopen(validated_path.c_str(), mode);
}

// Safe file stream opening with path validation
std::ifstream safe_ifstream(const std::string& filename) {
    std::string validated_path = validate_file_path(filename);
    return std::ifstream(validated_path);
}

// Safe stat with path validation
int safe_stat(const std::string& filename, struct stat* st) {
    std::string validated_path = validate_file_path(filename);
    return stat(validated_path.c_str(), st);
}

#endif // PATH_VALIDATION_H 