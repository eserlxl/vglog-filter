// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "file_utils.h"
#include "log_processor.h"
#include <path_validation.h>
#include <iostream>
#include <fstream>
#include <sys/resource.h>
#include <filesystem>
#include <stdexcept>
#include <limits>
#include <sys/stat.h> // Required for stat()

using Str = std::string;
using VecS = std::vector<Str>;

namespace {
    constexpr size_t INITIAL_LINE_CAPACITY = 1024;
    constexpr size_t MB_TO_BYTES = 1024 * 1024;
    constexpr size_t MAX_FILE_SIZE = 1024ULL * 1024 * 1024 * 1024; // 1TB
    constexpr size_t MAX_LINES = 1000000; // 1 million lines
    
    // Helper function to format file size in MB
    std::string format_file_size_mb(size_t bytes) {
        return std::to_string(bytes / MB_TO_BYTES);
    }
    
    // Helper function to format percentage
    std::string format_percentage(size_t bytes_processed, size_t total_bytes) {
        if (total_bytes == 0) return "0";
        return std::to_string(static_cast<int>((bytes_processed * 100) / total_bytes));
    }
    
    // Validate file size for security
    void validate_file_size(size_t file_size) {
        if (file_size > MAX_FILE_SIZE) {
            throw std::runtime_error("File too large (max " + std::to_string(MAX_FILE_SIZE / MB_TO_BYTES) + " MB)");
        }
    }
    
    // Validate line count for security
    void validate_line_count(size_t line_count) {
        if (line_count > MAX_LINES) {
            throw std::runtime_error("Too many lines (max " + std::to_string(MAX_LINES) + ")");
        }
    }
    
    // Validate input parameters for security
    void validate_input_parameters(std::string_view operation, std::string_view filename) {
        if (operation.empty()) {
            throw std::invalid_argument("Operation cannot be empty");
        }
        
        if (filename.empty() && operation != "processing") {
            throw std::invalid_argument("Filename cannot be empty for operation: " + std::string(operation));
        }
    }
}

// Helper function to create detailed error messages
Str create_error_message(std::string_view operation, std::string_view filename, std::string_view details) {
    validate_input_parameters(operation, filename);
    
    Str message = "Error during ";
    message += operation;
    
    if (!filename.empty()) {
        message += " for file '";
        message += filename;
        message += "'";
    }
    
    if (!details.empty()) {
        message += ": ";
        message += details;
    }
    
    return message;
}

// Helper function to report progress for large files
void report_progress(size_t bytes_processed, size_t total_bytes, std::string_view filename) {
    if (total_bytes == 0) {
        return;
    }
    
    // Validate input parameters
    if (bytes_processed > total_bytes) {
        std::cerr << "Warning: Progress reporting inconsistency detected\n";
        return;
    }
    
    const std::string percentage = format_percentage(bytes_processed, total_bytes);
    const std::string processed_mb = format_file_size_mb(bytes_processed);
    const std::string total_mb = format_file_size_mb(total_bytes);
    
    std::cerr << "\rProcessing " << filename << ": " << percentage << "% (" 
              << processed_mb << "/" << total_mb << " MB)" << std::flush;
    
    if (bytes_processed >= total_bytes) {
        std::cerr << std::endl;  // New line when complete
    }
}

// Helper function to get current memory usage in MB
size_t get_memory_usage_mb() {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) == 0) {
        // ru_maxrss is in KB on Linux, convert to MB
        return static_cast<size_t>(usage.ru_maxrss) / 1024;
    }
    return 0; // Return 0 if unable to get memory usage
}

// Helper function to report memory usage
void report_memory_usage(std::string_view operation, std::string_view filename) {
    validate_input_parameters(operation, filename);
    
    const size_t memory_mb = get_memory_usage_mb();
    if (memory_mb > 0) {
        std::cerr << "Memory usage during " << operation;
        if (!filename.empty()) {
            std::cerr << " for " << filename;
        }
        std::cerr << ": " << memory_mb << " MB" << std::endl;
    }
}

VecS read_file_lines(std::string_view fname) {
    if (fname.empty()) {
        throw std::invalid_argument("Filename cannot be empty");
    }
    
    // Create explicit string copy to avoid uninitialized memory
    const std::string filename_str(fname);
    std::ifstream file = path_validation::safe_ifstream(filename_str);
    if (!file) {
        throw std::runtime_error(create_error_message("opening file", fname, ""));
    }

    VecS lines;
    lines.reserve(INITIAL_LINE_CAPACITY); // Reserve capacity for better performance

    Str line;
    line.reserve(1024); // Pre-allocate line buffer for better performance
    
    size_t line_count = 0;
    while (std::getline(file, line)) {
        // Security validation
        validate_line_count(++line_count);
        lines.push_back(std::move(line));
    }

    return lines;
}

// Check if file is large enough to warrant stream processing
bool is_large_file(std::string_view fname) {
    if (fname.empty()) {
        return false;
    }
    
    try {
        // Use explicit string conversion to avoid MSAN issues with string_view data access
        const std::string filename_str(fname);
        
        // Use stat() instead of std::ifstream to avoid MSAN issues
        // This is more efficient and avoids the standard library MSAN problems
        struct stat file_stat;
        if (stat(filename_str.c_str(), &file_stat) != 0) {
            return false;
        }
        
        const size_t file_size = static_cast<size_t>(file_stat.st_size);
        
        // Security validation
        validate_file_size(file_size);
        
        return file_size >= (LARGE_FILE_THRESHOLD_MB * MB_TO_BYTES);
    } catch (const std::exception&) {
        return false;
    }
}

// Stream wrapper for files
void process_file_stream(std::string_view fname, const Options& opt) {
    if (fname.empty()) {
        throw std::invalid_argument("Filename cannot be empty");
    }
    
    // Create explicit string copy to avoid uninitialized memory
    const std::string filename_str(fname);
    std::ifstream file = path_validation::safe_ifstream(filename_str);
    if (!file) {
        throw std::runtime_error(create_error_message("opening file", fname, ""));
    }
    
    LogProcessor processor(opt);
    processor.process_stream(file);
}