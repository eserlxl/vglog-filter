// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <iostream>
#include <string>
#include <string_view>
#include <vector>
#include <cassert>
#include <sstream>
#include <cstring>

// Simple test framework
#define TEST_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            std::cerr << "FAIL: " << message << std::endl; \
            return false; \
        } \
    } while(0)

#define TEST_PASS(message) \
    do { \
        std::cout << "PASS: " << message << std::endl; \
    } while(0)

// Mock Options struct for testing (simplified version of the real one)
struct Options {
    int   depth           = 1;
    bool  trim            = true;
    bool  scrub_raw       = true;
    bool  stream_mode     = false;
    bool  show_progress   = false;
    bool  monitor_memory  = false;
    std::string marker    = "Successfully downloaded debug";
    std::string filename;
    bool  use_stdin       = false;
};

// Mock command-line argument parsing for testing
class CLIParser {
private:
    std::vector<std::string> args_;
    size_t current_arg_ = 0;

public:
    CLIParser(const std::vector<std::string>& args) : args_(args) {}
    
    bool has_next() const { return current_arg_ < args_.size(); }
    
    std::string next() {
        if (!has_next()) return "";
        return args_[current_arg_++];
    }
    
    std::string peek() const {
        if (!has_next()) return "";
        return args_[current_arg_];
    }
    
    void reset() { current_arg_ = 0; }
    
    size_t position() const { return current_arg_; }
    size_t size() const { return args_.size(); }
};

// Test helper function to simulate argument parsing
Options parse_arguments(const std::vector<std::string>& args) {
    Options opt;
    CLIParser parser(args);
    
    while (parser.has_next()) {
        std::string arg = parser.next();
        
        if (arg == "-h" || arg == "--help") {
            // Help flag - would normally print usage and exit
            continue;
        } else if (arg == "-V" || arg == "--version") {
            // Version flag - would normally print version and exit
            continue;
        } else if (arg == "-k" || arg == "--keep-debug-info") {
            opt.trim = false;
        } else if (arg == "-v" || arg == "--verbose") {
            opt.scrub_raw = false;
        } else if (arg == "-s" || arg == "--stream") {
            opt.stream_mode = true;
        } else if (arg == "-p" || arg == "--progress") {
            opt.show_progress = true;
        } else if (arg == "-M" || arg == "--memory") {
            opt.monitor_memory = true;
        } else if (arg == "-d" || arg == "--depth") {
            if (parser.has_next()) {
                std::string depth_str = parser.next();
                try {
                    opt.depth = std::stoi(depth_str);
                    if (opt.depth < 0) {
                        opt.depth = 0; // Unlimited
                    }
                } catch (const std::exception&) {
                    // Invalid depth, keep default
                }
            }
        } else if (arg == "-m" || arg == "--marker") {
            if (parser.has_next()) {
                opt.marker = parser.next();
            }
        } else if (arg == "-") {
            opt.use_stdin = true;
        } else if (arg[0] != '-') {
            // Non-option argument - treat as filename
            opt.filename = arg;
        }
    }
    
    return opt;
}

bool test_default_options() {
    // Test with no arguments
    std::vector<std::string> args = {};
    Options opt = parse_arguments(args);
    
    TEST_ASSERT(opt.depth == 1, "Default depth should be 1");
    TEST_ASSERT(opt.trim == true, "Default trim should be true");
    TEST_ASSERT(opt.scrub_raw == true, "Default scrub_raw should be true");
    TEST_ASSERT(opt.stream_mode == false, "Default stream_mode should be false");
    TEST_ASSERT(opt.show_progress == false, "Default show_progress should be false");
    TEST_ASSERT(opt.monitor_memory == false, "Default monitor_memory should be false");
    TEST_ASSERT(opt.marker == "Successfully downloaded debug", "Default marker should be correct");
    TEST_ASSERT(opt.filename.empty(), "Default filename should be empty");
    TEST_ASSERT(opt.use_stdin == false, "Default use_stdin should be false");
    
    TEST_PASS("Default options are set correctly");
    return true;
}

bool test_depth_option() {
    // Test depth option with various values
    std::vector<std::string> args = {"-d", "5"};
    Options opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 5, "Depth should be set to 5");
    
    args = {"--depth", "10"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 10, "Depth should be set to 10");
    
    args = {"-d", "0"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 0, "Depth should be set to 0 (unlimited)");
    
    args = {"-d", "-5"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 0, "Negative depth should be set to 0");
    
    // Test invalid depth
    args = {"-d", "abc"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 1, "Invalid depth should keep default");
    
    // Test missing depth value
    args = {"-d"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 1, "Missing depth value should keep default");
    
    TEST_PASS("Depth option parsing works correctly");
    return true;
}

bool test_marker_option() {
    // Test marker option
    std::vector<std::string> args = {"-m", "Custom marker"};
    Options opt = parse_arguments(args);
    TEST_ASSERT(opt.marker == "Custom marker", "Marker should be set to custom value");
    
    args = {"--marker", "Another marker"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.marker == "Another marker", "Marker should be set to another value");
    
    // Test empty marker
    args = {"-m", ""};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.marker.empty(), "Empty marker should be allowed");
    
    // Test missing marker value
    args = {"-m"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.marker == "Successfully downloaded debug", "Missing marker value should keep default");
    
    TEST_PASS("Marker option parsing works correctly");
    return true;
}

bool test_boolean_options() {
    // Test keep-debug-info option
    std::vector<std::string> args = {"-k"};
    Options opt = parse_arguments(args);
    TEST_ASSERT(opt.trim == false, "Keep debug info should disable trim");
    
    args = {"--keep-debug-info"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.trim == false, "Keep debug info long form should disable trim");
    
    // Test verbose option
    args = {"-v"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.scrub_raw == false, "Verbose should disable raw scrubbing");
    
    args = {"--verbose"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.scrub_raw == false, "Verbose long form should disable raw scrubbing");
    
    // Test stream option
    args = {"-s"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.stream_mode == true, "Stream mode should be enabled");
    
    args = {"--stream"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.stream_mode == true, "Stream mode long form should be enabled");
    
    // Test progress option
    args = {"-p"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.show_progress == true, "Progress should be enabled");
    
    args = {"--progress"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.show_progress == true, "Progress long form should be enabled");
    
    // Test memory option
    args = {"-M"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.monitor_memory == true, "Memory monitoring should be enabled");
    
    args = {"--memory"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.monitor_memory == true, "Memory monitoring long form should be enabled");
    
    TEST_PASS("Boolean options parsing works correctly");
    return true;
}

bool test_stdin_option() {
    // Test stdin option
    std::vector<std::string> args = {"-"};
    Options opt = parse_arguments(args);
    TEST_ASSERT(opt.use_stdin == true, "Dash should enable stdin");
    
    // Test stdin with other options
    args = {"-s", "-p", "-"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.use_stdin == true, "Dash with other options should enable stdin");
    TEST_ASSERT(opt.stream_mode == true, "Stream mode should still be enabled");
    TEST_ASSERT(opt.show_progress == true, "Progress should still be enabled");
    
    TEST_PASS("Stdin option parsing works correctly");
    return true;
}

bool test_filename_argument() {
    // Test filename argument
    std::vector<std::string> args = {"test.log"};
    Options opt = parse_arguments(args);
    TEST_ASSERT(opt.filename == "test.log", "Filename should be set correctly");
    
    // Test filename with path
    args = {"/path/to/test.log"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.filename == "/path/to/test.log", "Filename with path should be set correctly");
    
    // Test filename with options
    args = {"-s", "-p", "test.log"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.filename == "test.log", "Filename with options should be set correctly");
    TEST_ASSERT(opt.stream_mode == true, "Stream mode should still be enabled");
    TEST_ASSERT(opt.show_progress == true, "Progress should still be enabled");
    
    // Test multiple filenames (should use last one)
    args = {"file1.log", "file2.log", "file3.log"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.filename == "file3.log", "Last filename should be used");
    
    TEST_PASS("Filename argument parsing works correctly");
    return true;
}

bool test_combined_options() {
    // Test multiple options together
    std::vector<std::string> args = {"-d", "3", "-m", "Custom", "-s", "-p", "-M", "test.log"};
    Options opt = parse_arguments(args);
    
    TEST_ASSERT(opt.depth == 3, "Depth should be 3");
    TEST_ASSERT(opt.marker == "Custom", "Marker should be Custom");
    TEST_ASSERT(opt.stream_mode == true, "Stream mode should be enabled");
    TEST_ASSERT(opt.show_progress == true, "Progress should be enabled");
    TEST_ASSERT(opt.monitor_memory == true, "Memory monitoring should be enabled");
    TEST_ASSERT(opt.filename == "test.log", "Filename should be test.log");
    
    // Test with long options
    args = {"--depth", "5", "--marker", "Long marker", "--stream", "--progress", "--memory", "long_test.log"};
    opt = parse_arguments(args);
    
    TEST_ASSERT(opt.depth == 5, "Depth should be 5");
    TEST_ASSERT(opt.marker == "Long marker", "Marker should be Long marker");
    TEST_ASSERT(opt.stream_mode == true, "Stream mode should be enabled");
    TEST_ASSERT(opt.show_progress == true, "Progress should be enabled");
    TEST_ASSERT(opt.monitor_memory == true, "Memory monitoring should be enabled");
    TEST_ASSERT(opt.filename == "long_test.log", "Filename should be long_test.log");
    
    TEST_PASS("Combined options parsing works correctly");
    return true;
}

bool test_help_and_version_options() {
    // Test help options (should not affect other options)
    std::vector<std::string> args = {"-h", "-d", "5", "test.log"};
    Options opt = parse_arguments(args);
    
    TEST_ASSERT(opt.depth == 5, "Depth should still be 5 even with help");
    TEST_ASSERT(opt.filename == "test.log", "Filename should still be set even with help");
    
    args = {"--help", "-s", "-p"};
    opt = parse_arguments(args);
    
    TEST_ASSERT(opt.stream_mode == true, "Stream mode should still be enabled even with help");
    TEST_ASSERT(opt.show_progress == true, "Progress should still be enabled even with help");
    
    // Test version options
    args = {"-V", "-d", "10", "version_test.log"};
    opt = parse_arguments(args);
    
    TEST_ASSERT(opt.depth == 10, "Depth should still be 10 even with version");
    TEST_ASSERT(opt.filename == "version_test.log", "Filename should still be set even with version");
    
    args = {"--version", "-M"};
    opt = parse_arguments(args);
    
    TEST_ASSERT(opt.monitor_memory == true, "Memory monitoring should still be enabled even with version");
    
    TEST_PASS("Help and version options parsing works correctly");
    return true;
}

bool test_edge_cases() {
    // Test empty argument list
    std::vector<std::string> args = {};
    Options opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 1, "Empty args should have default depth");
    
    // Test single dash
    args = {"-"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.use_stdin == true, "Single dash should enable stdin");
    
    // Test unknown options (should be ignored)
    args = {"--unknown", "-d", "5", "test.log"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 5, "Unknown options should not affect known options");
    TEST_ASSERT(opt.filename == "test.log", "Unknown options should not affect filename");
    
    // Test options with empty values
    args = {"-d", "", "-m", "", "test.log"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.depth == 1, "Empty depth should keep default");
    TEST_ASSERT(opt.marker.empty(), "Empty marker value should be set to empty string");
    TEST_ASSERT(opt.filename == "test.log", "Filename should still be set");
    
    // Test options at end of argument list
    args = {"test.log", "-d", "5"};
    opt = parse_arguments(args);
    TEST_ASSERT(opt.filename == "test.log", "Filename should be set even if options come after");
    TEST_ASSERT(opt.depth == 5, "Depth should be set even if it comes after filename");
    
    TEST_PASS("Edge cases are handled correctly");
    return true;
}

bool test_cli_parser_class() {
    // Test CLIParser class functionality
    std::vector<std::string> args = {"arg1", "arg2", "arg3"};
    CLIParser parser(args);
    
    TEST_ASSERT(parser.size() == 3, "Parser should have correct size");
    TEST_ASSERT(parser.position() == 0, "Parser should start at position 0");
    TEST_ASSERT(parser.has_next() == true, "Parser should have next at start");
    
    std::string arg = parser.next();
    TEST_ASSERT(arg == "arg1", "First argument should be arg1");
    TEST_ASSERT(parser.position() == 1, "Position should be 1 after first next()");
    TEST_ASSERT(parser.has_next() == true, "Parser should still have next");
    
    arg = parser.peek();
    TEST_ASSERT(arg == "arg2", "Peek should return arg2");
    TEST_ASSERT(parser.position() == 1, "Position should not change after peek()");
    
    arg = parser.next();
    TEST_ASSERT(arg == "arg2", "Second argument should be arg2");
    
    arg = parser.next();
    TEST_ASSERT(arg == "arg3", "Third argument should be arg3");
    TEST_ASSERT(parser.has_next() == false, "Parser should not have next after all args");
    
    parser.reset();
    TEST_ASSERT(parser.position() == 0, "Reset should set position to 0");
    TEST_ASSERT(parser.has_next() == true, "Parser should have next after reset");
    
    arg = parser.next();
    TEST_ASSERT(arg == "arg1", "After reset, first argument should be arg1");
    
    TEST_PASS("CLIParser class works correctly");
    return true;
}

int main() {
    std::cout << "Running CLI options tests for vglog-filter..." << std::endl;
    
    bool all_passed = true;
    
    all_passed &= test_default_options();
    all_passed &= test_depth_option();
    all_passed &= test_marker_option();
    all_passed &= test_boolean_options();
    all_passed &= test_stdin_option();
    all_passed &= test_filename_argument();
    all_passed &= test_combined_options();
    all_passed &= test_help_and_version_options();
    all_passed &= test_edge_cases();
    all_passed &= test_cli_parser_class();
    
    if (all_passed) {
        std::cout << "\nAll CLI options tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome CLI options tests failed!" << std::endl;
        return 1;
    }
} 