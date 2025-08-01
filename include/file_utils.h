// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include <string>
#include <string_view>
#include <vector>
#include <iosfwd>
#include "options.h"

// Helper function to create detailed error messages
[[nodiscard]] std::string create_error_message(std::string_view operation, std::string_view filename, std::string_view details = "");

// Helper function to report progress for large files
void report_progress(size_t bytes_processed, size_t total_bytes, std::string_view filename);

// Helper function to get current memory usage in MB
[[nodiscard]] size_t get_memory_usage_mb();

// Helper function to report memory usage
void report_memory_usage(std::string_view operation, std::string_view filename = "");

// Read all lines from a file
[[nodiscard]] std::vector<std::string> read_file_lines(std::string_view fname);

// Check if a file is large
[[nodiscard]] bool is_large_file(std::string_view fname);

// Process a file as a stream
void process_file_stream(std::string_view fname, const Options& opt);