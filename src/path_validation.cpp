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
    
    // Helper function to get current working directory
    std::filesystem::path get_current_working_directory() {
        try {
            return std::filesystem::current_path();
        } catch (const std::filesystem::filesystem_error& e) {
            throw std::runtime_error("Failed to get current working directory: " + std::string(e.what()));
        }
    }
    
    // Helper function to canonicalize path
    std::filesystem::path canonicalize_path(const std::filesystem::path& full_path) {
        try {
            return std::filesystem::weakly_canonical(full_path);
        } catch (const std::filesystem::filesystem_error& e) {
            throw std::runtime_error("Failed to canonicalize path: " + std::string(e.what()));
        }
    }
    
    // Helper function to check for path traversal attempts
    void check_path_traversal(const std::filesystem::path& base_dir, 
                             const std::filesystem::path& canonical_path,
                             const std::string& path_str) {
        auto base_it = base_dir.begin();
        auto path_it = canonical_path.begin();
        
        // Check that the canonical path starts with the base directory
        while (base_it != base_dir.end() && path_it != canonical_path.end() && *base_it == *path_it) {
            ++base_it;
            ++path_it;
        }
        
        if (base_it != base_dir.end()) {
            throw std::runtime_error("Path traversal attempt detected: " + path_str);
        }
    }
    
    // Helper function to validate file exists and is regular
    void validate_file_exists_and_regular(const std::filesystem::path& validated_path) {
        if (!std::filesystem::exists(validated_path)) {
            throw std::runtime_error("File does not exist: " + validated_path.string());
        }
        
        if (!std::filesystem::is_regular_file(validated_path)) {
            throw std::runtime_error("Path is not a regular file: " + validated_path.string());
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
    
    // Get current working directory with proper initialization
    // Use explicit copy construction to avoid move assignment MSAN issues
    std::filesystem::path base_dir;
    try {
        base_dir = std::filesystem::path(get_current_working_directory());
    } catch (const std::runtime_error& e) {
        throw std::runtime_error("Failed to get current working directory: " + std::string(e.what()));
    }
    
    // Ensure base_dir is properly initialized before use
    if (base_dir.empty()) {
        throw std::runtime_error("Current working directory is empty or invalid.");
    }
    
    // Construct full path with explicit initialization
    // Use explicit copy construction to avoid move assignment MSAN issues
    const std::filesystem::path full_path(base_dir / path);
    
    // Canonicalize path with explicit initialization
    // Use explicit copy construction to avoid move assignment MSAN issues
    const std::filesystem::path canonical_path(canonicalize_path(full_path));
    
    // Check for path traversal attempts
    check_path_traversal(base_dir, canonical_path, path_str);
    
    // Return explicit copy to avoid move-related uninitialized memory issues
    // Use explicit copy construction instead of move assignment
    // Create a new path object with explicit string conversion to avoid MSAN issues
    return std::filesystem::path(canonical_path.string());
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