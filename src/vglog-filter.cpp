// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <getopt.h>
#include <iostream>
#include <iterator>
#include <regex>
#include <sstream>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>
#include <sys/stat.h> // Required for stat()

using Str  = std::string;
using StrView = std::string_view;
using VecS = std::vector<Str>;

constexpr int DEFAULT_DEPTH = 1;
constexpr const char* DEFAULT_MARKER = "Successfully downloaded debug";

struct Options {
    int  depth        = DEFAULT_DEPTH;
    bool trim         = true;
    bool scrub_raw    = true;
    bool stream_mode  = false;  // Enable stream processing for large files
    bool show_progress = false; // Show progress for large files
    Str  marker       = DEFAULT_MARKER;
    Str  filename;
    bool use_stdin    = false;  // Whether to read from stdin
};

void usage(const char* prog) {
    std::cerr << "Usage: " << prog << " [options] [valgrind_log]\n\n"
        "Input\n"
        "  valgrind_log            Path to Valgrind log file (default: stdin if omitted)\n"
        "  -                       Read from stdin (explicit)\n\n"
        "Options\n"
        "  -k, --keep-debug-info   Keep everything; do not trim above last debug marker.\n"
        "  -v, --verbose           Show completely raw blocks (no address / \"at:\" scrub).\n"
        "  -d N, --depth N         Signature depth (default: " << DEFAULT_DEPTH << ", 0 = unlimited).\n"
        "  -m S, --marker S        Marker string (default: \"" << DEFAULT_MARKER << "\").\n"
        "  -s, --stream            Force stream processing mode (auto-detected for files >5MB).\n"
        "  -p, --progress          Show progress for large files.\n"
        "  -V, --version           Show version information.\n"
        "  -h, --help              Show this help.\n\n"
        "Examples\n"
        "  " << prog << " log.txt                    # Process file\n"
        "  " << prog << " < log.txt                  # Process from stdin\n"
        "  " << prog << " - < log.txt                # Explicit stdin\n"
        "  valgrind ./prog 2>&1 | " << prog << "     # Direct pipe from valgrind\n";
}

// ---------- helpers ---------------------------------------------------------

// Helper function to create detailed error messages
Str create_error_message(const Str& operation, const Str& filename, const Str& details = "") {
    Str message = "Error during " + operation;
    if (!filename.empty()) {
        message += " for file '" + filename + "'";
    }
    if (!details.empty()) {
        message += ": " + details;
    }
    return message;
}

// Helper function to report progress for large files
void report_progress(size_t lines_processed, size_t total_lines, const Str& filename) {
    if (total_lines == 0) return;
    
    int percentage = static_cast<int>((lines_processed * 100) / total_lines);
    std::cerr << "\rProcessing " << filename << ": " << percentage << "% (" 
              << lines_processed << "/" << total_lines << " lines)" << std::flush;
    
    if (lines_processed >= total_lines) {
        std::cerr << std::endl;  // New line when complete
    }
}

static inline StrView ltrim_view(StrView s) {
    auto start = std::find_if(s.begin(), s.end(),
                              [](int ch){ return !std::isspace(ch); });
    return StrView(start, s.end() - start);
}

static inline StrView rtrim_view(StrView s) {
    auto end = std::find_if(s.rbegin(), s.rend(),
                            [](int ch){ return !std::isspace(ch); }).base();
    return StrView(s.begin(), end - s.begin());
}

static inline StrView trim_view(StrView s) { 
    return rtrim_view(ltrim_view(s)); 
}

static inline Str ltrim(Str s) {
    s.erase(s.begin(), std::find_if(s.begin(), s.end(),
                                    [](int ch){ return !std::isspace(ch); }));
    return s;
}

static inline Str rtrim(Str s) {
    s.erase(std::find_if(s.rbegin(), s.rend(),
                         [](int ch){ return !std::isspace(ch); }).base(),
            s.end());
    return s;
}

static inline Str trim(Str s) { return rtrim(ltrim(std::move(s))); }

Str regex_replace_all(const Str& src, const std::regex& re, const Str& repl)
{
    return std::regex_replace(src, re, repl,
                              std::regex_constants::format_default |
                              std::regex_constants::match_default);
}

// ---------- canonicalisation ------------------------------------------------

// Function-local static regex objects to avoid recompilation and initialization issues
static const std::regex& get_re_addr() {
    static const std::regex re(R"(0x[0-9a-fA-F]+)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_line() {
    static const std::regex re(R"(:[0-9]+)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_array() {
    static const std::regex re(R"(\[[0-9]+\])", std::regex::optimize);
    return re;
}

static const std::regex& get_re_template() {
    static const std::regex re(R"(<[^>]*>)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_ws() {
    static const std::regex re(R"([ \t\v\f\r\n]+)", std::regex::optimize);
    return re;
}

Str canon(Str s)
{
    s = regex_replace_all(s, get_re_addr(), "0xADDR");
    s = regex_replace_all(s, get_re_line(), ":LINE");
    s = regex_replace_all(s, get_re_array(), "[]");
    s = regex_replace_all(s, get_re_template(), "<T>");
    s = regex_replace_all(s, get_re_ws(), " ");
    s = rtrim(s);
    return s;
}

Str canon(StrView s)
{
    Str result(s);
    return canon(std::move(result));
}

// ---------- main dedupe engine ---------------------------------------------

// Function-local static regex objects for process function
static const std::regex& get_re_vg_line() {
    static const std::regex re(R"(^==[0-9]+==)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_prefix() {
    static const std::regex re(R"(^==[0-9]+==[ \t\v\f\r\n]*)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_start() {
    static const std::regex re(
        R"((Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ blocks|still reachable|possibly lost|definitely lost|Process terminating))", 
        std::regex::optimize);
    return re;
}

static const std::regex& get_re_bytes_head() {
    static const std::regex re(R"([0-9]+ bytes in [0-9]+ blocks)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_at() {
    static const std::regex re(R"(at : +)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_by() {
    static const std::regex re(R"(by : +)", std::regex::optimize);
    return re;
}

static const std::regex& get_re_q() {
    static const std::regex re(R"(\?{3,})", std::regex::optimize);
    return re;
}

void process(std::istream& in, const Options& opt)
{
    std::ostringstream raw, sig;
    VecS sigLines;
    std::unordered_set<Str> seen;

    auto flush = [&]() {
        const Str rawStr = raw.str();
        if (rawStr.empty()) return;
        Str key;
        if (opt.depth > 0) {
            for (int i = 0; i < opt.depth && i < static_cast<int>(sigLines.size()); ++i) {
                key += sigLines[i] + '\n';
            }
        } else {
            key = sig.str();
        }
        if (seen.insert(key).second) {
            std::cout << rawStr << '\n'; // Add extra newline after each block
        }
        raw.str("");
        raw.clear();
        sig.str("");
        sig.clear();
        sigLines.clear();
    };

    Str line;
    while (std::getline(in, line)) {
        if (!std::regex_search(line, get_re_vg_line())) continue;
        // strip "==PID== "
        line = std::regex_replace(line, get_re_prefix(), "");
        if (std::regex_search(line, get_re_start())) {
            flush();
            if (std::regex_search(line, get_re_bytes_head())) continue;
        }
        Str rawLine = line;
        if (opt.scrub_raw) {
            rawLine = regex_replace_all(rawLine, get_re_addr(), "");
            rawLine = regex_replace_all(rawLine, get_re_at(), "");
            rawLine = regex_replace_all(rawLine, get_re_by(), "");
            rawLine = regex_replace_all(rawLine, get_re_q(), "");
        }
        if (trim_view(rawLine).empty()) continue;
        raw << rawLine << '\n';
        sig << canon(line) << '\n';
        sigLines.push_back(canon(line));
    }
    flush();
}

// ---------- load file + optional trim --------------------------------------

VecS read_file_lines(const Str& fname)
{
    FILE* file = fopen(fname.c_str(), "r");
    if (!file) throw std::runtime_error(create_error_message("opening file", fname));
    
    VecS lines;
    lines.reserve(1000); // Reserve capacity for better performance
    
    char* line_buffer = nullptr;
    size_t line_buffer_size = 0;
    ssize_t line_length;
    
    while ((line_length = getline(&line_buffer, &line_buffer_size, file)) != -1) {
        // Check for memory allocation failure
        if (line_buffer == nullptr) {
            fclose(file);
            throw std::runtime_error(create_error_message("reading file", fname, "Memory allocation failed"));
        }
        
        // Remove trailing newline if present
        if (line_length > 0 && line_buffer[line_length - 1] == '\n') {
            line_buffer[line_length - 1] = '\0';
            line_length--;
        }
        lines.emplace_back(line_buffer);
    }
    
    free(line_buffer);
    fclose(file);
    return lines;
}

// Check if file is large enough to warrant stream processing
bool is_large_file(const Str& fname, size_t threshold_mb = 5) {
    struct stat file_stat;
    if (stat(fname.c_str(), &file_stat) != 0) {
        return false;  // File doesn't exist or can't be accessed
    }
    
    if (!S_ISREG(file_stat.st_mode)) {
        return false;  // Not a regular file
    }
    
    // Convert to MB and compare with threshold
    size_t file_size_mb = static_cast<size_t>(file_stat.st_size) / (1024 * 1024);
    return file_size_mb >= threshold_mb;
}

// Stream processing version that accepts any istream
void process_stream(std::istream& in, const Options& opt)
{
    std::ostringstream raw, sig;
    VecS sigLines;
    std::unordered_set<Str> seen;
    bool found_marker = false;
    size_t lines_processed = 0;
    size_t total_lines = 0;

    // Count total lines for progress reporting if enabled
    if (opt.show_progress && !opt.use_stdin) {
        std::ifstream count_file(opt.filename);
        if (count_file) {
            total_lines = std::count(std::istreambuf_iterator<char>(count_file),
                                   std::istreambuf_iterator<char>(), '\n');
            count_file.close();
        }
    }

    auto flush = [&]() {
        const Str rawStr = raw.str();
        if (rawStr.empty()) return;
        Str key;
        if (opt.depth > 0) {
            for (int i = 0; i < opt.depth && i < static_cast<int>(sigLines.size()); ++i) {
                key += sigLines[i] + '\n';
            }
        } else {
            key = sig.str();
        }
        if (seen.insert(key).second) {
            std::cout << rawStr << '\n'; // Add extra newline after each block
        }
        raw.str("");
        raw.clear();
        sig.str("");
        sig.clear();
        sigLines.clear();
    };

    Str line;
    while (std::getline(in, line)) {
        lines_processed++;
        
        // Report progress every 1000 lines if enabled
        if (opt.show_progress && lines_processed % 1000 == 0) {
            report_progress(lines_processed, total_lines, opt.filename);
        }
        
        // Check for marker if trimming is enabled
        if (opt.trim && line.find(opt.marker) != Str::npos) {
            found_marker = true;
            continue; // Skip this line and continue from next
        }
        
        // If we haven't found the marker yet and trimming is enabled, skip
        if (opt.trim && !found_marker) {
            continue;
        }
        
        if (!std::regex_search(line, get_re_vg_line())) continue;
        // strip "==PID== "
        line = std::regex_replace(line, get_re_prefix(), "");
        if (std::regex_search(line, get_re_start())) {
            flush();
            if (std::regex_search(line, get_re_bytes_head())) continue;
        }
        Str rawLine = line;
        if (opt.scrub_raw) {
            rawLine = regex_replace_all(rawLine, get_re_addr(), "");
            rawLine = regex_replace_all(rawLine, get_re_at(), "");
            rawLine = regex_replace_all(rawLine, get_re_by(), "");
            rawLine = regex_replace_all(rawLine, get_re_q(), "");
        }
        if (trim_view(rawLine).empty()) continue;
        raw << rawLine << '\n';
        sig << canon(line) << '\n';
        sigLines.push_back(canon(line));
    }
    
    // Final progress report
    if (opt.show_progress) {
        report_progress(lines_processed, total_lines, opt.filename);
    }
    
    flush();
}

// Stream processing version for large files
void process_file_stream(const Str& fname, const Options& opt)
{
    // Create a proper stream processing implementation that doesn't load the entire file
    std::ifstream file(fname);
    if (!file) throw std::runtime_error(create_error_message("opening file", fname));
    
    // Process the file directly using the existing process_stream function
    process_stream(file, opt);
}

Str get_version()
{
    // Try multiple paths in order of preference
    const std::vector<Str> paths = {
        "./VERSION",                    // Local development
        "../VERSION",                   // Build directory
        "/usr/share/vglog-filter/VERSION", // System installation
        "/usr/local/share/vglog-filter/VERSION" // Local installation
    };
    
    for (const auto& path : paths) {
        FILE* version_file = fopen(path.c_str(), "r");
        if (version_file) {
            char* line_buffer = nullptr;
            size_t line_buffer_size = 0;
            ssize_t line_length = getline(&line_buffer, &line_buffer_size, version_file);
            fclose(version_file);
            
            if (line_length > 0) {
                Str version(line_buffer);
                free(line_buffer);
                
                // Remove any whitespace safely
                if (!version.empty()) {
                    size_t start = version.find_first_not_of(" \t\r\n");
                    if (start != Str::npos) {
                        version.erase(0, start);
                    }
                    size_t end = version.find_last_not_of(" \t\r\n");
                    if (end != Str::npos) {
                        version.erase(end + 1);
                    }
                }
                if (!version.empty()) {
                    return version;
                }
            } else {
                free(line_buffer);
            }
        }
    }
    return "unknown";
}

int main(int argc, char* argv[])
{
    Options opt;
    static const option long_opts[] = {
        {"keep-debug-info", no_argument,       nullptr, 'k'},
        {"verbose",         no_argument,       nullptr, 'v'},
        {"depth",           required_argument, nullptr, 'd'},
        {"marker",          required_argument, nullptr, 'm'},
        {"stream",          no_argument,       nullptr, 's'},
        {"progress",        no_argument,       nullptr, 'p'}, // Added progress option
        {"version",         no_argument,       nullptr, 'V'},
        {"help",            no_argument,       nullptr, 'h'},
        {nullptr,           0,                 nullptr,  0 }
    };
    int c;
    while ((c = getopt_long(argc, argv, "kvd:m:sVh", long_opts, nullptr)) != -1) {
        switch (c) {
            case 'k': opt.trim = false; break;
            case 'v': opt.scrub_raw = false; break;
            case 'd': 
                try {
                    opt.depth = std::stoi(optarg);
                    if (opt.depth < 0) {
                        std::cerr << "Error: Depth must be non-negative (got: " << optarg << ")" << std::endl;
                        return 1;
                    }
                    // Add reasonable upper limit to prevent excessive memory usage
                    if (opt.depth > 1000) {
                        std::cerr << "Error: Depth value too large (got: " << optarg << ", max: 1000)" << std::endl;
                        return 1;
                    }
                } catch (const std::exception& e) {
                    std::cerr << "Error: Invalid depth value '" << optarg << "' (expected: non-negative integer)" << std::endl;
                    return 1;
                }
                break;
            case 'm': 
                if (optarg && optarg[0] != '\0') {
                    opt.marker = optarg;
                } else {
                    std::cerr << "Error: Marker string cannot be empty" << std::endl;
                    return 1;
                }
                break;
            case 's': opt.stream_mode = true; break;
            case 'p': opt.show_progress = true; break; // Added progress option
            case 'V': 
                std::cout << "vglog-filter version " << get_version() << std::endl; 
                return 0;
            case 'h': usage(argv[0]); return 0;
            default : usage(argv[0]); return 1;
        }
    }
    // Handle input source
    if (optind >= argc) {
        // No filename provided, use stdin
        opt.use_stdin = true;
        opt.filename = "-";
    } else {
        opt.filename = argv[optind];
        if (opt.filename == "-") {
            opt.use_stdin = true;
        } else {
            // Check if file exists using fopen for better MSan compatibility
            FILE* test_file = fopen(opt.filename.c_str(), "r");
            if (!test_file) {
                std::cerr << create_error_message("opening file", opt.filename) << std::endl;
                std::cerr << "Please check that the file exists and is readable" << std::endl;
                return 1;
            }
            fclose(test_file);
        }
    }
    
    // Determine processing mode: manual override or automatic detection
    bool use_stream_mode = opt.stream_mode;
    
    if (!use_stream_mode) {
        if (opt.use_stdin) {
            // Always use stream mode for stdin since we can't seek
            use_stream_mode = true;
        } else {
            // Auto-detect large files (5MB threshold for testing, can be adjusted)
            use_stream_mode = is_large_file(opt.filename, 5);
            if (use_stream_mode) {
                std::cerr << "Info: Large file detected, using stream processing mode" << std::endl;
            }
        }
    }
    
    // Process input using appropriate mode
    if (use_stream_mode) {
        // Stream processing for large files or stdin
        try {
            if (opt.use_stdin) {
                // Process from stdin
                process_stream(std::cin, opt);
            } else {
                // Process from file
                process_file_stream(opt.filename, opt);
            }
        } catch (const std::exception& e) {
            std::cerr << create_error_message("stream processing", opt.filename, e.what()) << std::endl;
            return 1;
        }
    } else {
        // Memory-based processing for smaller files
        VecS lines;
        try { 
            lines = read_file_lines(opt.filename); 
        } catch (const std::exception& e) { 
            std::cerr << create_error_message("reading file", opt.filename, e.what()) << std::endl;
            return 1; 
        }
        
        // Check if file is empty
        if (lines.empty()) {
            std::cerr << "Warning: Input file '" << opt.filename << "' is empty" << std::endl;
            return 0;
        }
        // trim above last marker if requested
        size_t start = 0;
        if (opt.trim) {
            for (size_t i = lines.size(); i-- > 0;) {
                if (lines[i].find(opt.marker) != Str::npos) {
                    start = i + 1;
                    break;
                }
            }
        }
        
        // Ensure start doesn't exceed array bounds
        if (start >= lines.size()) {
            start = lines.size();
        }
        
        std::stringstream work;
        if (start < lines.size()) {
            std::copy(lines.begin() + static_cast<std::ptrdiff_t>(start), lines.end(),
                      std::ostream_iterator<Str>(work, "\n"));
        }
        // run dedupe
        process(work, opt);
    }
    return 0;
} 