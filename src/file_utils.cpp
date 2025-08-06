// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "file_utils.h"
#include "log_processor.h"
#include "path_validation.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <sys/resource.h> // Linux
#include <vector>

namespace {

constinit inline std::size_t MB_TO_BYTES = 1024u * 1024u;
constinit inline std::size_t MAX_FILE_SIZE_BYTES = 1024ull * 1024ull * 1024ull * 1024ull; // 1 TB
constinit inline std::size_t INITIAL_LINE_CAPACITY = 1024;
constinit inline std::size_t MAX_LINES = 1'000'000;

[[nodiscard]] std::string to_mb(std::size_t bytes) {
    return std::to_string(bytes / MB_TO_BYTES);
}

[[nodiscard]] std::string pct(std::size_t done, std::size_t total) {
    if (total == 0) return "0";
    return std::to_string(static_cast<int>((done * 100) / total));
}

void validate_file_size(std::size_t s) {
    if (s > MAX_FILE_SIZE_BYTES) {
        throw std::runtime_error("File too large (max " + to_mb(MAX_FILE_SIZE_BYTES) + " MB)");
    }
}
void validate_line_count(std::size_t n) {
    if (n > MAX_LINES) {
        throw std::runtime_error("Too many lines (max " + std::to_string(MAX_LINES) + ")");
    }
}

} // namespace

std::string create_error_message(std::string_view operation,
                                 std::string_view filename,
                                 std::string_view details) noexcept {
    std::string m = "Error during ";
    m.append(operation);
    if (!filename.empty()) {
        m.append(" for file '").append(filename).append("'");
    }
    if (!details.empty()) {
        m.append(": ").append(details);
    }
    return m;
}

void report_progress(std::size_t bytes_processed, std::size_t total_bytes, std::string_view filename) {
    if (total_bytes == 0 || bytes_processed > total_bytes) return;
    std::cerr << "\rProcessing " << filename << ": " << pct(bytes_processed, total_bytes)
              << "% (" << to_mb(bytes_processed) << "/" << to_mb(total_bytes) << " MB)" << std::flush;
    if (bytes_processed >= total_bytes) std::cerr << '\n';
}

std::size_t get_memory_usage_mb() noexcept {
#if defined(__linux__)
    rusage u{};
    if (getrusage(RUSAGE_SELF, &u) == 0) {
        return static_cast<std::size_t>(u.ru_maxrss) / 1024u; // KB → MB
    }
#endif
    return 0;
}

void report_memory_usage(std::string_view operation, std::string_view filename) {
    const auto mb = get_memory_usage_mb();
    if (mb > 0) {
        std::cerr << "Memory usage during " << operation;
        if (!filename.empty()) std::cerr << " for " << filename;
        std::cerr << ": " << mb << " MB\n";
    }
}

std::vector<std::string> read_file_lines(std::string_view fname) {
    if (fname.empty()) throw std::invalid_argument("Filename cannot be empty");

    auto ifs = path_validation::safe_ifstream(fname);
    ifs.exceptions(std::ios::badbit); // keep it cheap; avoid throw on eof

    std::vector<std::string> lines;
    lines.reserve(INITIAL_LINE_CAPACITY);

    std::string line;
    std::size_t count = 0;
    while (std::getline(ifs, line)) {
        validate_line_count(++count);
        lines.push_back(line);
    }
    return lines;
}

bool is_large_file(std::string_view fname) {
    if (fname.empty()) return false;
    try {
        const auto p = path_validation::validate_and_canonicalize(fname);
        const auto s = std::filesystem::file_size(p);
        validate_file_size(static_cast<std::size_t>(s));
        return s >= static_cast<std::uintmax_t>(LARGE_FILE_THRESHOLD_MB) * MB_TO_BYTES;
    } catch (...) {
        return false;
    }
}

void process_file_stream(std::string_view fname, const Options& opt) {
    if (fname.empty()) throw std::invalid_argument("Filename cannot be empty");
    auto ifs = path_validation::safe_ifstream(fname);
    LogProcessor processor(opt);
    processor.process_stream(ifs);
}