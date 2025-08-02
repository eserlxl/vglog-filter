// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "options.h"
#include "file_utils.h"
#include "log_processor.h"
#include "path_validation.h"
#include <getopt.h>
#include <iostream>
#include <vector>
#include <algorithm>
#include <string>
#include <stdexcept>
#include <limits>
#include <cstring>

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

namespace {
    constexpr int MAX_DEPTH = 1000;
    constexpr int MAX_MARKER_LENGTH = 1024;
    
    struct CommandLineOptions {
        static const option long_opts[];
        static const char* short_opts;
    };
    
    const option CommandLineOptions::long_opts[] = {
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
    
    const char* CommandLineOptions::short_opts = "kvd:m:spMVh";
    
    // Validate input arguments for security
    void validate_argument(const char* optarg, const char* option_name) {
        if (!optarg) {
            throw std::runtime_error("Missing argument for option: " + std::string(option_name));
        }
    }
    
    // Parse depth argument with proper validation and bounds checking
    int parse_depth_argument(const char* optarg) {
        validate_argument(optarg, "depth");
        
        // Check for null pointer
        if (!optarg) {
            throw std::runtime_error("Depth argument is null");
        }
        
        // Check for empty string
        if (optarg[0] == '\0') {
            throw std::runtime_error("Depth argument cannot be empty");
        }
        
        try {
            // Use strtol for better error handling
            char* endptr = nullptr;
            const long depth_long = std::strtol(optarg, &endptr, 10);
            
            // Check for conversion errors
            if (endptr == optarg || *endptr != '\0') {
                throw std::runtime_error("Invalid depth value: non-numeric characters found");
            }
            
            // Check for overflow/underflow
            if (depth_long < 0 || depth_long > MAX_DEPTH) {
                throw std::out_of_range("Depth out of valid range");
            }
            
            return static_cast<int>(depth_long);
        } catch (const std::exception& e) {
            throw std::runtime_error("Invalid depth value '" + std::string(optarg) + 
                                   "' (expected non-negative integer between 0 and " + 
                                   std::to_string(MAX_DEPTH) + "): " + e.what());
        }
    }
    
    // Parse marker argument with validation and length limits
    std::string parse_marker_argument(const char* optarg) {
        validate_argument(optarg, "marker");
        
        // Check for null pointer
        if (!optarg) {
            throw std::runtime_error("Marker argument is null");
        }
        
        // Check for empty string
        if (optarg[0] == '\0') {
            throw std::runtime_error("Marker string cannot be empty");
        }
        
        // Check for length limits
        const size_t length = std::strlen(optarg);
        if (length > MAX_MARKER_LENGTH) {
            throw std::runtime_error("Marker string too long (max " + 
                                   std::to_string(MAX_MARKER_LENGTH) + " characters)");
        }
        
        // Check for null bytes (security measure)
        if (std::string_view(optarg).find('\0') != std::string_view::npos) {
            throw std::runtime_error("Marker string contains null bytes");
        }
        
        return std::string(optarg);
    }
    
    // Process command line arguments with enhanced security
    Options parse_command_line(int argc, char* argv[]) {
        // Validate input parameters
        if (argc < 1 || !argv) {
            throw std::runtime_error("Invalid command line arguments");
        }
        
        Options opt;
        int c;
        
        while ((c = getopt_long(argc, argv, CommandLineOptions::short_opts, 
                               CommandLineOptions::long_opts, nullptr)) != -1) {
            switch (c) {
                case 'k': 
                    opt.trim = false; 
                    break;
                case 'v': 
                    opt.scrub_raw = false; 
                    break;
                case 'd':
                    opt.depth = parse_depth_argument(optarg);
                    break;
                case 'm':
                    opt.marker = parse_marker_argument(optarg);
                    break;
                case 's': 
                    opt.stream_mode = true; 
                    break;
                case 'p': 
                    opt.show_progress = true; 
                    break;
                case 'M': 
                    opt.monitor_memory = true; 
                    break;
                case 'V':
                    std::cout << "vglog-filter version " << TOSTRING(VGLOG_FILTER_VERSION) << std::endl;
                    std::exit(0);
                case 'h': 
                    usage(argv[0]); 
                    std::exit(0);
                default: 
                    usage(argv[0]); 
                    std::exit(1);
            }
        }
        
        return opt;
    }
    
    // Determine input source and processing mode with validation
    void setup_input_source(Options& opt, int argc, char* argv[]) {
        if (optind >= argc) {
            opt.use_stdin = true;
            opt.filename = "-";
        } else {
            // Validate filename argument
            if (!argv[optind]) {
                throw std::runtime_error("Invalid filename argument");
            }
            
            opt.filename = argv[optind];
            if (opt.filename == "-") {
                opt.use_stdin = true;
            } else {
                // Validate and canonicalize the filename for security
                try {
                    // Use string-based validation to avoid MSAN issues with filesystem::path
                    const std::string validated_path = path_validation::sanitize_path_for_file_access(opt.filename);
                    opt.filename = validated_path;
                } catch (const std::exception& e) {
                    throw std::runtime_error("Invalid filename: " + std::string(e.what()));
                }
            }
        }
        
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
    }
    
    // Process input based on mode with error handling
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
            if (lines.empty() && !opt.filename.empty() && opt.filename != "-") {
                std::cerr << "Warning: Input file '" << opt.filename << "' is empty\n";
                return;
            }
            processor.process_lines(lines);
        }
        
        if (opt.monitor_memory) {
            report_memory_usage("completed processing", opt.filename);
        }
    }
}

int main(int argc, char* argv[]) {
    // Speed up I/O - but keep sync for MSAN compatibility
    std::ios::sync_with_stdio(true);
    std::cin.tie(nullptr);
    
    try {
        Options opt = parse_command_line(argc, argv);
        setup_input_source(opt, argc, argv);
        process_input(opt);
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
    
    return 0;
}// Test change
