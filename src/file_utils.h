// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef FILE_UTILS_H
#define FILE_UTILS_H

#include <string>
#include <vector>
#include <iosfwd>
#include "options.h"

using Str = std::string;
using VecS = std::vector<Str>;

// Helper function to create detailed error messages
Str create_error_message(const Str& operation, const Str& filename, const Str& details = "");

// Helper function to report progress for large files
void report_progress(size_t bytes_processed, size_t total_bytes, const Str& filename);

// Helper function to get current memory usage in MB
size_t get_memory_usage_mb();

// Helper function to report memory usage
void report_memory_usage(const Str& operation, const Str& filename = "");

// Read all lines from a file
VecS read_file_lines(const Str& fname);

// Check if a file is large
bool is_large_file(const Str& fname);

// Process a file as a stream
void process_file_stream(const Str& fname, const Options& opt);

#endif // FILE_UTILS_H
