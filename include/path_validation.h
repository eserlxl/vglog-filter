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
#include <cstdlib>
#include <unistd.h>

// Get the current working directory as the base directory for safe file access
std::string get_safe_base_directory() {
    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) == nullptr) {
        throw std::runtime_error("Failed to get current working directory");
    }
    return std::string(cwd);
}

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

// Validate and sanitize file path with strict security checks
std::string validate_file_path(const std::string& input_path) {
    // Special case for stdin
    if (input_path == "-") {
        return input_path;
    }
    
    // Check for null bytes or other dangerous characters
    if (input_path.find('\0') != std::string::npos) {
        throw std::runtime_error("Path contains null bytes: " + input_path);
    }
    
    // Check path length
    if (input_path.length() > PATH_MAX) {
        throw std::runtime_error("Path too long: " + input_path);
    }
    
    // Check for path traversal attempts
    if (contains_path_traversal(input_path)) {
        throw std::runtime_error("Path traversal attempt detected: " + input_path);
    }
    
    // Get the safe base directory
    std::string base_dir = get_safe_base_directory();
    
    // Handle empty path
    if (input_path.empty()) {
        return ".";
    }
    
    // Normalize the path using filesystem to handle ./ and other normalizations
    try {
        std::filesystem::path path_obj(input_path);
        std::filesystem::path normalized_path = path_obj.lexically_normal();
        std::string normalized_str = normalized_path.string();
        
        // Re-check for path traversal after normalization
        if (contains_path_traversal(normalized_str)) {
            throw std::runtime_error("Path traversal attempt detected after normalization: " + normalized_str);
        }
        
        // For simple cases where the path doesn't need realpath validation,
        // just return the normalized path
        if (normalized_str == "." || normalized_str.empty()) {
            return ".";
        }
        
        // Construct the full path for realpath validation using filesystem::path
        std::filesystem::path base_path(base_dir);
        std::filesystem::path normalized_path_obj(normalized_str);
        std::filesystem::path full_path_obj = base_path / normalized_path_obj;
        std::string full_path = full_path_obj.string();
        
        // Use realpath to resolve any remaining path traversal and get canonical path
        char resolved_path[PATH_MAX];
        if (realpath(full_path.c_str(), resolved_path) == nullptr) {
            // If realpath fails, it might be because the file doesn't exist yet
            // In this case, we need to validate that the path would be safe if it did exist
            std::string parent_dir = normalized_path.parent_path().string();
            
            if (!parent_dir.empty() && parent_dir != ".") {
                // Handle the case where parent_dir might contain "."
                std::filesystem::path parent_path_obj(parent_dir);
                std::filesystem::path normalized_parent = parent_path_obj.lexically_normal();
                std::string normalized_parent_str = normalized_parent.string();
                
                // Skip validation if parent is current directory
                if (normalized_parent_str != "." && !normalized_parent_str.empty()) {
                    // Check if the parent directory exists and is within the base directory
                    std::filesystem::path parent_path_obj_safe(normalized_parent_str);
                    std::filesystem::path parent_full_path_obj = base_path / parent_path_obj_safe;
                    std::string parent_full_path = parent_full_path_obj.string();
                    if (realpath(parent_full_path.c_str(), resolved_path) != nullptr) {
                        // Parent directory exists, check it's within base directory
                        std::string resolved_parent = std::string(resolved_path);
                        if (resolved_parent.find(base_dir) != 0) {
                            throw std::runtime_error("Path traversal attempt detected: " + input_path);
                        }
                    } else {
                        // Parent directory doesn't exist, but we can still validate the path structure
                        // by checking that it doesn't contain path traversal patterns
                        if (contains_path_traversal(normalized_parent_str)) {
                            throw std::runtime_error("Path traversal attempt detected in parent directory: " + normalized_parent_str);
                        }
                        
                        // Additional check: ensure the parent path doesn't start with /
                        if (!normalized_parent_str.empty() && normalized_parent_str[0] == '/') {
                            throw std::runtime_error("Absolute path not allowed: " + normalized_parent_str);
                        }
                    }
                }
            }
            
            // For new files, return the normalized path
            return normalized_str;
        }
        
        // Check that the resolved path is within the base directory
        std::string resolved = std::string(resolved_path);
        if (resolved.find(base_dir) != 0) {
            throw std::runtime_error("Path traversal attempt detected: " + input_path);
        }
        
        // Return the relative path from base directory
        if (resolved == base_dir) {
            return ".";
        } else if (resolved.length() > base_dir.length() + 1) {
            return resolved.substr(base_dir.length() + 1);
        } else {
            return resolved.substr(base_dir.length());
        }
    } catch (const std::exception& e) {
        throw std::runtime_error("Path validation failed: " + std::string(e.what()));
    }
}

// Safe file opening with path validation
FILE* safe_fopen(const std::string& filename, const char* mode) {
    std::string validated_path = validate_file_path(filename);
    
    // For stdin, return nullptr to indicate stdin should be used
    if (validated_path == "-") {
        return nullptr;
    }
    
    // Use filesystem::path for safe path construction
    std::string base_dir = get_safe_base_directory();
    std::filesystem::path base_path(base_dir);
    std::filesystem::path file_path(validated_path);
    std::filesystem::path full_path = base_path / file_path;
    
    // Additional safety check: ensure the constructed path is within base directory
    std::string full_path_str = full_path.string();
    if (full_path_str.find(base_dir) != 0) {
        throw std::runtime_error("Path construction resulted in unsafe path: " + full_path_str);
    }
    
    return fopen(full_path_str.c_str(), mode);
}

// Safe file stream opening with path validation
std::ifstream safe_ifstream(const std::string& filename) {
    std::string validated_path = validate_file_path(filename);
    
    // For stdin, throw an exception as ifstream doesn't support stdin
    if (validated_path == "-") {
        throw std::runtime_error("stdin not supported for ifstream");
    }
    
    // Use filesystem::path for safe path construction
    std::string base_dir = get_safe_base_directory();
    std::filesystem::path base_path(base_dir);
    std::filesystem::path file_path(validated_path);
    std::filesystem::path full_path = base_path / file_path;
    
    // Additional safety check: ensure the constructed path is within base directory
    std::string full_path_str = full_path.string();
    if (full_path_str.find(base_dir) != 0) {
        throw std::runtime_error("Path construction resulted in unsafe path: " + full_path_str);
    }
    
    return std::ifstream(full_path_str);
}

// Safe stat with path validation
int safe_stat(const std::string& filename, struct stat* st) {
    std::string validated_path = validate_file_path(filename);
    
    // For stdin, return error
    if (validated_path == "-") {
        return -1;
    }
    
    // Use filesystem::path for safe path construction
    std::string base_dir = get_safe_base_directory();
    std::filesystem::path base_path(base_dir);
    std::filesystem::path file_path(validated_path);
    std::filesystem::path full_path = base_path / file_path;
    
    // Additional safety check: ensure the constructed path is within base directory
    std::string full_path_str = full_path.string();
    if (full_path_str.find(base_dir) != 0) {
        throw std::runtime_error("Path construction resulted in unsafe path: " + full_path_str);
    }
    
    return stat(full_path_str.c_str(), st);
}

#endif // PATH_VALIDATION_H 