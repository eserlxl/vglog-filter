// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <path_validation.h>
#include <stdexcept>
#include <algorithm>
#include <cctype>
#include <cstdio>
#include <sys/stat.h>

namespace path_validation {

namespace {
    constexpr char NULL_BYTE = '\0';
    constexpr std::string_view STDIN_MARKER = "-";
    
    // Helper function to check for null bytes in string
    bool contains_null_bytes(std::string_view input) {
        return input.find(NULL_BYTE) != std::string_view::npos;
    }
    
    // Helper function to check for dangerous characters that could be used in path injection
    bool contains_dangerous_characters(std::string_view input) {
        // Check for characters that could be used in path injection or command execution
        const std::string dangerous_chars = "`$(){}[]|&;<>\"'\\";
        return std::any_of(input.begin(), input.end(), [&dangerous_chars](char c) {
            return dangerous_chars.find(c) != std::string::npos;
        });
    }
    
    // Helper function to validate path is not absolute
    void validate_not_absolute(const std::filesystem::path& path, const std::string& path_str) {
        if (path.is_absolute()) {
            throw std::runtime_error("Absolute paths are not allowed for security reasons: " + path_str);
        }
    }
    
    // Helper function to check for path traversal attempts
    void check_path_traversal(const std::filesystem::path& path, const std::string& path_str) {
        // Use string-based checking to avoid MSAN issues with path iteration
        // Check if the path contains any parent directory references
        const std::string path_string = path.string();
        
        // Check for common path traversal patterns
        if (path_string.find("..") != std::string::npos) {
            // Additional check to avoid false positives on valid paths like "..config"
            // Look for actual directory traversal patterns
            if (path_string.find("/../") != std::string::npos ||
                path_string.find("\\..\\") != std::string::npos ||
                path_string.find("/..\\") != std::string::npos ||
                path_string.find("\\../") != std::string::npos ||
                path_string.find("/..") != std::string::npos ||
                path_string.find("\\..") != std::string::npos ||
                path_string.find("..\\") != std::string::npos ||
                path_string.find("../") != std::string::npos ||
                path_string == ".." ||
                path_string.find("/..") == path_string.length() - 3 ||
                path_string.find("\\..") == path_string.length() - 3) {
                throw std::runtime_error("Path traversal attempt detected: " + path_str);
            }
        }
    }
    
    // String-based path validation to avoid MSAN issues with filesystem::path
    void validate_path_string(const std::string& path_str) {
        // Check for empty or null-containing paths
        if (path_str.empty() || path_str.find('\0') != std::string::npos) {
            throw std::runtime_error("Invalid path: empty or contains null bytes.");
        }
        
        // Check for dangerous characters
        const std::string dangerous_chars = "`$(){}[]|&;<>\"'\\";
        for (char c : path_str) {
            if (dangerous_chars.find(c) != std::string::npos) {
                throw std::runtime_error("Invalid path: contains dangerous characters.");
            }
        }
        
        // Check for absolute paths (start with / or drive letter on Windows)
        if (path_str[0] == '/' || (path_str.length() > 2 && path_str[1] == ':' && (path_str[2] == '/' || path_str[2] == '\\'))) {
            throw std::runtime_error("Absolute paths are not allowed for security reasons: " + path_str);
        }
        
        // Check for path traversal attempts
        if (path_str.find("..") != std::string::npos) {
            // Additional check to avoid false positives on valid paths like "..config"
            // Look for actual directory traversal patterns
            if (path_str.find("/../") != std::string::npos ||
                path_str.find("\\..\\") != std::string::npos ||
                path_str.find("/..\\") != std::string::npos ||
                path_str.find("\\../") != std::string::npos ||
                path_str.find("/..") != std::string::npos ||
                path_str.find("\\..") != std::string::npos ||
                path_str.find("..\\") != std::string::npos ||
                path_str.find("../") != std::string::npos ||
                path_str == ".." ||
                path_str.find("/..") == path_str.length() - 3 ||
                path_str.find("\\..") == path_str.length() - 3) {
                throw std::runtime_error("Path traversal attempt detected: " + path_str);
            }
        }
    }
    
    // Sanitize and validate path, returning a safe path string for file operations
    std::string sanitize_path_for_file_access(std::string_view input_path) {
        // Create explicit string copy to avoid uninitialized memory
        const std::string path_str(input_path);
        
        // Validate the path using string-based validation to avoid MSAN issues
        validate_path_string(path_str);
        
        // Return the validated path string - this is now safe for file operations
        return path_str;
    }
    
    // String-based file validation to avoid MSAN issues with filesystem::path
    // This function expects a pre-validated path string that has been sanitized
    void validate_file_exists_and_regular_string(const std::string& sanitized_path) {
        // Use C-style file operations to avoid MSAN issues with filesystem operations
        // The path has been pre-validated and sanitized, so it's safe for file operations
        FILE* file = fopen(sanitized_path.c_str(), "r");
        if (!file) {
            throw std::runtime_error("File does not exist");
        }
        
        // Check if it's a regular file using stat
        struct stat st;
        if (stat(sanitized_path.c_str(), &st) != 0) {
            fclose(file);
            throw std::runtime_error("Cannot stat file");
        }
        
        if (!S_ISREG(st.st_mode)) {
            fclose(file);
            throw std::runtime_error("Path is not a regular file");
        }
        
        fclose(file);
    }
}

std::filesystem::path validate_and_canonicalize(std::string_view input_path) {
    // Check for empty or null-containing paths
    if (input_path.empty() || contains_null_bytes(input_path)) {
        throw std::runtime_error("Invalid path: empty or contains null bytes.");
    }
    
    // Check for dangerous characters
    if (contains_dangerous_characters(input_path)) {
        throw std::runtime_error("Invalid path: contains dangerous characters.");
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
    
    // Sanitize and validate the path, getting a safe path string for file operations
    const std::string safe_filename = sanitize_path_for_file_access(filename);
    
    // Check if file exists and is regular using string-based approach
    validate_file_exists_and_regular_string(safe_filename);
    
    return std::ifstream(safe_filename);
}

} // namespace path_validation