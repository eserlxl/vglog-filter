// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "options.h"
#include "file_utils.h"
#include "log_processor.h"
#include <getopt.h>
#include <iostream>
#include <vector>
#include <algorithm>
#include <string>

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

int main(int argc, char* argv[])
{
    using Str = std::string;
    using VecS = std::vector<Str>;

    // Speed up I/O - but keep sync for MSAN compatibility
    std::ios::sync_with_stdio(true);
    std::cin.tie(nullptr);

    Options opt;
    constexpr int MAX_DEPTH = 1000;
    static const option long_opts[] = {
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

    int c;
    while ((c = getopt_long(argc, argv, "kvd:m:spMVh", long_opts, nullptr)) != -1) {
        switch (c) {
            case 'k': opt.trim = false; break;
            case 'v': opt.scrub_raw = false; break;
            case 'd':
                try {
                    const long depth_long = std::stol(optarg);
                    if (depth_long < 0 || depth_long > MAX_DEPTH) {
                        std::cerr << "Error: Depth must be between 0 and " << MAX_DEPTH << " (got: " << optarg << ")\n";
                        return 1;
                    }
                    opt.depth = static_cast<int>(depth_long);
                } catch (...) {
                    std::cerr << "Error: Invalid depth value '" << optarg << "' (expected non-negative integer)\n";
                    return 1;
                }
                break;
            case 'm':
                if (optarg && optarg[0] != '\0') {
                    opt.marker = optarg;
                } else {
                    std::cerr << "Error: Marker string cannot be empty\n";
                    return 1;
                }
                break;
            case 's': opt.stream_mode    = true; break;
            case 'p': opt.show_progress  = true; break;
            case 'M': opt.monitor_memory = true; break;
            case 'V':
                std::cout << "vglog-filter version " << TOSTRING(VGLOG_FILTER_VERSION) << std::endl;
                return 0;
            case 'h': usage(argv[0]); return 0;
            default : usage(argv[0]); return 1;
        }
    }

    // Input source
    if (optind >= argc) {
        opt.use_stdin = true;
        opt.filename  = "-";
    } else {
        opt.filename = argv[optind];
        if (opt.filename == "-") {
            opt.use_stdin = true;
        }
    }

    try {
        // Determine processing mode
        if (!opt.stream_mode) {
            if (opt.use_stdin) {
                opt.stream_mode = true; // stdin can't seek
            } else {
                opt.stream_mode = is_large_file(opt.filename);
                if (opt.stream_mode) {
                    std::cerr << "Info: Large file detected, using stream processing mode\n";
                }
            }
        }

        if (opt.monitor_memory) report_memory_usage("starting processing", opt.filename);

        LogProcessor processor(opt);
        if (opt.stream_mode) {
            if (opt.use_stdin) {
                processor.process_stream(std::cin);
            } else {
                process_file_stream(opt.filename, opt);
            }
        }
        else {
            const VecS lines = read_file_lines(opt.filename);
            if (lines.empty() && !opt.filename.empty() && opt.filename != "-") {
                std::cerr << "Warning: Input file '" << opt.filename << "' is empty\n";
                return 0;
            }
            processor.process_lines(lines);
        }

        if (opt.monitor_memory) report_memory_usage("completed processing", opt.filename);

    } catch (const std::exception& e) {
        std::cerr << create_error_message("processing", opt.filename, e.what()) << "\n";
        return 1;
    }

    return 0;
}