// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include "options.h"

#include <cstddef>
#include <iosfwd>
#include <span>
#include <string>
#include <string_view>
#include <vector>

// Formatted error text
[[nodiscard]] std::string create_error_message(std::string_view operation,
                                               std::string_view filename,
                                               std::string_view details = {}) noexcept;

// Progress helpers
void report_progress(std::size_t bytes_processed, std::size_t total_bytes, std::string_view filename);
[[nodiscard]] std::size_t get_memory_usage_mb() noexcept;
void report_memory_usage(std::string_view operation, std::string_view filename = {});

// File helpers
[[nodiscard]] std::vector<std::string> read_file_lines(std::string_view fname);
[[nodiscard]] bool is_large_file(std::string_view fname);

// Stream processing wrapper
void process_file_stream(std::string_view fname, const Options& opt);