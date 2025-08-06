// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "file_utils.h"
#include "log_processor.h"
#include "options.h"
#include "path_validation.h"

#include <algorithm>
#include <charconv>
#include <cstring>
#include <getopt.h> // POSIX getopt_long
#include <iostream>
#include <limits>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#ifndef VGLOG_FILTER_VERSION
#define VGLOG_FILTER_VERSION 0.0.0
#endif

#define STRINGIFY(x) #x
#define TOSTRING(x)  STRINGIFY(x)

namespace {

inline constexpr int  MAX_DEPTH            = 1000;
inline constexpr auto STDIN_SENTINEL       = std::string_view{"-"};
inline constexpr auto VERSION_STRING       = std::string_view{TOSTRING(VGLOG_FILTER_VERSION)};
inline constexpr int  MAX_MARKER_LENGTH    = 1024;

// getopt_long table
// NOLINTNEXTLINE(modernize-avoid-c-arrays)
constinit option LONG_OPTS[] = {
    {"keep-debug-info", no_argument,       nullptr, 'k'},
    {"verbose",         no_argument,       nullptr, 'v'},
    {"depth",           required_argument, nullptr, 'd'},
    {"marker",          required_argument, nullptr, 'm'},
    {"stream",          no_argument,       nullptr, 's'},
    {"progress",        no_argument,       nullptr, 'p'},
    {"memory",          no_argument,       nullptr, 'M'},
    {"version",         no_argument,       nullptr, 'V'},
    {"help",            no_argument,       nullptr, 'h'},
    {nullptr,           0,                 nullptr,  0 }
};

inline constexpr auto SHORT_OPTS = std::string_view{"kvd:m:spMVh"};

[[nodiscard]] std::string make_range_error(std::string_view what, int lo, int hi) {
    std::string msg;
    msg.reserve(64);
    msg.append(what).append(" out of valid range [")
       .append(std::to_string(lo)).append("..").append(std::to_string(hi)).append("]");
    return msg;
}

[[nodiscard]] int parse_nonneg_int(std::string_view sv, int max_value) {
    if (sv.empty()) throw std::runtime_error("Value cannot be empty");
    int value = 0;
    const auto* first = sv.data();
    const auto* last  = sv.data() + sv.size();
    auto        ec    = std::from_chars(first, last, value).ec;
    if (ec != std::errc{} || first == last) {
        throw std::runtime_error("Invalid integer: '" + std::string(sv) + "'");
    }
    if (value < 0 || value > max_value) {
        throw std::out_of_range(make_range_error("Integer", 0, max_value));
    }
    return value;
}

[[nodiscard]] std::string parse_marker(std::string_view sv) {
    if (sv.empty()) throw std::runtime_error("Marker string cannot be empty");
    if (sv.size() > static_cast<size_t>(MAX_MARKER_LENGTH)) {
        throw std::runtime_error("Marker string too long (max " + std::to_string(MAX_MARKER_LENGTH) + " characters)");
    }
    if (sv.find('\0') != std::string_view::npos) {
        throw std::runtime_error("Marker string contains null bytes");
    }
    return std::string{sv};
}

// Returns std::nullopt when the program should exit early (help/version already printed).
[[nodiscard]] std::optional<Options> parse_command_line(int argc, char* argv[]) {
    if (argc < 1 || argv == nullptr) {
        throw std::runtime_error("Invalid command line arguments");
    }

    Options opt{};
    // Reset getopt state for safety in case of reuse
    optind = 1;

    for (;;) {
        const int c = ::getopt_long(argc, argv, SHORT_OPTS.data(), LONG_OPTS, nullptr);
        if (c == -1) break;

        switch (c) {
            case 'k': opt.trim         = false; break;
            case 'v': opt.scrub_raw    = false; break;
            case 'd': opt.depth        = parse_nonneg_int(optarg ? std::string_view{optarg} : std::string_view{}, MAX_DEPTH); break;
            case 'm': opt.marker       = parse_marker(optarg ? std::string_view{optarg} : std::string_view{}); break;
            case 's': opt.stream_mode  = true;  break;
            case 'p': opt.show_progress = true; break;
            case 'M': opt.monitor_memory = true; break;
            case 'V':
                std::cout << "vglog-filter version " << VERSION_STRING << '\n';
                return std::nullopt;
            case 'h':
                usage(argv[0]);
                return std::nullopt;
            default:
                usage(argv[0]);
                throw std::runtime_error("Invalid option. Use -h for help.");
        }
    }

    return opt;
}

void setup_input_source(Options& opt, int argc, char* argv[]) {
    if (optind >= argc) {
        opt.use_stdin = true;
        opt.filename  = std::string{STDIN_SENTINEL};
    } else {
        const char* arg = argv[optind];
        if (!arg) throw std::runtime_error("Invalid filename argument");

        const std::string_view name{arg};
        if (name == STDIN_SENTINEL) {
            opt.use_stdin = true;
            opt.filename  = std::string{STDIN_SENTINEL};
        } else {
            // Prefer string-based sanitization first; canonicalization happens in file helpers.
            opt.filename = path_validation::sanitize_path_for_file_access(name);
        }
    }

    // Auto-detect streaming when not explicitly requested
    if (!opt.stream_mode) {
        opt.stream_mode = opt.use_stdin ? true : is_large_file(opt.filename);
        if (opt.stream_mode && !opt.use_stdin) {
            std::cerr << "Info: Large file detected, using stream processing mode\n";
        }
    }
}

void process_input(const Options& opt) {
    if (opt.monitor_memory) {
        report_memory_usage("starting processing", opt.filename);
    }

    LogProcessor processor(opt);

    if (opt.stream_mode) {
        if (opt.use_stdin) {
            processor.process_stream(std::cin);
        } else {
            process_file_stream(opt.filename, opt);
        }
    } else {
        const std::vector<std::string> lines = read_file_lines(opt.filename);
        if (lines.empty() && !opt.filename.empty() && opt.filename != STDIN_SENTINEL) {
            std::cerr << "Warning: Input file '" << opt.filename << "' is empty\n";
            return;
        }
        processor.process_lines(lines);
    }

    if (opt.monitor_memory) {
        report_memory_usage("completed processing", opt.filename);
    }
}

} // namespace

int main(int argc, char* argv[]) {
    // Favor correctness with standard iostreams; keep sync enabled for tool-compat.
    std::ios::sync_with_stdio(true);
    std::cin.tie(nullptr);

    try {
        if (auto parsed = parse_command_line(argc, argv)) {
            auto& opt = *parsed;
            setup_input_source(opt, argc, argv);
            process_input(opt);
        } else {
            // Help/version printed; normal exit.
            return 0;
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << '\n';
        return 1;
    }

    return 0;
}
