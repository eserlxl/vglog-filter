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

using Str = std::string;
using VecS = std::vector<Str>;

// Helper function to create detailed error messages
Str create_error_message(std::string_view operation, std::string_view filename, std::string_view details) {
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
    if (total_bytes == 0) return;
    
    int percentage = static_cast<int>((bytes_processed * 100) / total_bytes);
    std::cerr << "\rProcessing " << filename << ": " << percentage << "% (" 
              << bytes_processed / (1024 * 1024) << "/" << total_bytes / (1024 * 1024) << " MB)" << std::flush;
    
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
    const size_t memory_mb = get_memory_usage_mb();
    if (memory_mb > 0) {
        std::cerr << "Memory usage during " << operation;
        if (!filename.empty()) {
            std::cerr << " for " << filename;
        }
        std::cerr << ": " << memory_mb << " MB" << std::endl;
    }
}

VecS read_file_lines(std::string_view fname)
{
    std::ifstream file = path_validation::safe_ifstream(std::string(fname));
    if (!file) throw std::runtime_error(create_error_message("opening file", fname, ""));

    VecS lines;
    lines.reserve(1024); // Reserve capacity for better performance

    Str line;
    while (std::getline(file, line)) {
        lines.push_back(std::move(line));
    }

    return lines;
}

// Check if file is large enough to warrant stream processing
bool is_large_file(std::string_view fname) {
    try {
        const auto validated_path = path_validation::validate_and_canonicalize(std::string(fname));
        return std::filesystem::file_size(validated_path) >= (LARGE_FILE_THRESHOLD_MB * 1024 * 1024);
    } catch (const std::exception&) {
        return false;
    }
}

// Stream wrapper for files
void process_file_stream(std::string_view fname, const Options& opt) {
    std::ifstream file = path_validation::safe_ifstream(std::string(fname));
    if (!file) throw std::runtime_error(create_error_message("opening file", fname, ""));
    LogProcessor processor(opt);
    processor.process_stream(file);
}