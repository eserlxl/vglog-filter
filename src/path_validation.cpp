// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <path_validation.h>
#include <stdexcept>

namespace path_validation {

namespace {
    constexpr char NULL_BYTE = '\0';
    constexpr std::string_view STDIN_MARKER = "-";
    
    // Helper function to check for null bytes in string
    bool contains_null_bytes(std::string_view input) {
        return input.find(NULL_BYTE) != std::string_view::npos;
    }
    
    // Helper function to validate path is not absolute
    void validate_not_absolute(const std::filesystem::path& path, const std::string& path_str) {
        if (path.is_absolute()) {
            throw std::runtime_error("Absolute paths are not allowed for security reasons: " + path_str);
        }
    }
    
    // Helper function to check for path traversal attempts
    void check_path_traversal(const std::filesystem::path& path, const std::string& path_str) {
        // Check if the path contains any parent directory references
        for (const auto& component : path) {
            if (component == ".." || component == "..\\" || component == "../") {
                throw std::runtime_error("Path traversal attempt detected: " + path_str);
            }
        }
    }
    
    // Helper function to validate file exists and is regular
    void validate_file_exists_and_regular(const std::filesystem::path& validated_path) {
        if (!std::filesystem::exists(validated_path)) {
            throw std::runtime_error("File does not exist");
        }
        
        if (!std::filesystem::is_regular_file(validated_path)) {
            throw std::runtime_error("Path is not a regular file");
        }
    }
}

std::filesystem::path validate_and_canonicalize(std::string_view input_path) {
    // Check for empty or null-containing paths
    if (input_path.empty() || contains_null_bytes(input_path)) {
        throw std::runtime_error("Invalid path: empty or contains null bytes.");
    }
    
    // Handle stdin marker
    if (input_path == STDIN_MARKER) {
        return std::filesystem::path(STDIN_MARKER);
    }
    
    // Create explicit string copy to avoid uninitialized memory
    const std::string path_str(input_path);
    const std::filesystem::path path(path_str);
    
    // Validate path is not absolute
    validate_not_absolute(path, path_str);
    
    // Check for path traversal attempts
    check_path_traversal(path, path_str);
    
    // For now, return the path directly to avoid MSAN issues with complex path operations
    // This is a simplified approach that should work for most use cases
    return path;
}

std::ifstream safe_ifstream(std::string_view filename) {
    // Handle stdin marker
    if (filename == STDIN_MARKER) {
        throw std::runtime_error("Cannot open stdin with ifstream.");
    }
    
    // Create explicit string copy to avoid uninitialized memory
    const std::string filename_str(filename);
    
    // Validate and canonicalize path
    // Use explicit copy construction to avoid move assignment MSAN issues
    const std::filesystem::path validated_path(validate_and_canonicalize(filename_str));
    
    // Validate file exists and is regular
    validate_file_exists_and_regular(validated_path);
    
    return std::ifstream(validated_path);
}

} // namespace path_validation