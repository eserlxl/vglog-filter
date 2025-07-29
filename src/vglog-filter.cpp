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
#include <span>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>
#include <sys/types.h>   // ssize_t
#include <sys/stat.h>    // stat()
#include <sys/resource.h> // memory monitoring
#include <unistd.h>      // getopt_long()
#include <filesystem>    // path validation
#include <limits.h>      // PATH_MAX
#include <libgen.h>      // dirname, basename
#include <vglog-filter/path_validation.h>  // path validation functions

using Str      = std::string;
using StrView  = std::string_view;
using VecS     = std::vector<Str>;
using StrSpan  = std::span<const Str>;

constexpr int         DEFAULT_DEPTH  = 1;
constexpr const char* DEFAULT_MARKER = "Successfully downloaded debug";

struct Options {
    int   depth           = DEFAULT_DEPTH;
    bool  trim            = true;
    bool  scrub_raw       = true;
    bool  stream_mode     = false;   // Enable stream processing for large files or stdin
    bool  show_progress   = false;   // Show progress for large files
    bool  monitor_memory  = false;   // Monitor memory usage
    Str   marker          = DEFAULT_MARKER;
    Str   filename;
    bool  use_stdin       = false;   // Whether to read from stdin
};

void usage(const char* prog) {
    std::cerr
        << "Usage: " << prog << " [options] [valgrind_log]\n\n"
        << "Input\n"
        << "  valgrind_log            Path to Valgrind log file (default: stdin if omitted)\n"
        << "  -                       Read from stdin (explicit)\n\n"
        << "Options\n"
        << "  -k, --keep-debug-info   Keep everything; do not trim above last debug marker.\n"
        << "  -v, --verbose           Show completely raw blocks (no address / \"at:\" scrub).\n"
        << "  -d N, --depth N         Signature depth (default: " << DEFAULT_DEPTH << ", 0 = unlimited).\n"
        << "  -m S, --marker S        Marker string (default: \"" << DEFAULT_MARKER << "\").\n"
        << "  -s, --stream            Force stream processing mode (auto-detected for files >5MB).\n"
        << "  -p, --progress          Show progress for large files.\n"
        << "  -M, --memory            Monitor memory usage during processing.\n"
        << "  -V, --version           Show version information.\n"
        << "  -h, --help              Show this help.\n\n"
        << "Notes\n"
        << "  • In stream mode (including stdin), the tool outputs only the region after the *last*\n"
        << "    marker encountered (if any). If no marker is found, the entire input is processed.\n\n"
        << "Examples\n"
        << "  " << prog << " log.txt                    # Process file\n"
        << "  " << prog << " < log.txt                  # Process from stdin\n"
        << "  " << prog << " - < log.txt                # Explicit stdin\n"
        << "  valgrind ./prog 2>&1 | " << prog << "     # Direct pipe from valgrind\n";
}

// ---------- helpers ---------------------------------------------------------

// Forward declarations for path validation functions
FILE* safe_fopen(const Str& filename, const char* mode);
std::ifstream safe_ifstream(const Str& filename);
int safe_stat(const Str& filename, struct stat* st);

// Removed unused function is_space

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
void report_memory_usage(const Str& operation, const Str& filename = "") {
    size_t memory_mb = get_memory_usage_mb();
    if (memory_mb > 0) {
        std::cerr << "Memory usage during " << operation;
        if (!filename.empty()) {
            std::cerr << " for " << filename;
        }
        std::cerr << ": " << memory_mb << " MB" << std::endl;
    }
}

// Helper function to process string arrays using std::span
StrSpan create_span_from_vector(const VecS& vec) {
    return StrSpan(vec);
}

// Helper function to find marker in string span
size_t find_marker_in_span(StrSpan lines, const Str& marker) {
    for (size_t i = lines.size(); i-- > 0;) {
        if (lines[i].find(marker) != Str::npos) {
            return i + 1; // start after the marker line
        }
    }
    return 0; // process whole input when marker not found
}

static inline StrView ltrim_view(StrView s) {
    auto start = std::find_if(s.begin(), s.end(),
                              [](int ch){ return !std::isspace(ch); });
    return StrView(start, static_cast<size_t>(s.end() - start));
}

static inline StrView rtrim_view(StrView s) {
    auto end = std::find_if(s.rbegin(), s.rend(),
                            [](int ch){ return !std::isspace(ch); }).base();
    return StrView(s.begin(), static_cast<size_t>(end - s.begin()));
}

static inline StrView trim_view(StrView s) { 
    return rtrim_view(ltrim_view(s)); 
}

// Removed unused function ltrim

static inline Str rtrim(Str s) {
    s.erase(std::find_if(s.rbegin(), s.rend(),
                         [](int ch){ return !std::isspace(ch); }).base(),
            s.end());
    return s;
}

Str regex_replace_all(const Str& src, const std::regex& re, const Str& repl)
{
    return std::regex_replace(src, re, repl,
                              std::regex_constants::format_default |
                              std::regex_constants::match_default);
}

// ---------- canonicalisation ------------------------------------------------

// Function-local static regex objects to avoid recompilation and initialization issues
static const std::regex& get_re_addr() {
    static const std::regex re(R"(0x[0-9a-fA-F]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_line() {
    static const std::regex re(R"(:[0-9]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_array() {
    static const std::regex re(R"(\[[0-9]+\])", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_template() {
    static const std::regex re(R"(<[^>]*>)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_ws() {
    static const std::regex re(R"([ \t\v\f\r\n]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

Str canon(Str s)
{
    s = regex_replace_all(s, get_re_addr(), "0xADDR");
    s = regex_replace_all(s, get_re_line(), ":LINE");
    s = regex_replace_all(s, get_re_array(), "[]");
    s = regex_replace_all(s, get_re_template(), "<T>");
    s = regex_replace_all(s, get_re_ws(), " ");
    s = rtrim(std::move(s));
    return s;
}

Str canon(StrView s)
{
    Str tmp(s);
    return canon(std::move(tmp));
}

// ---------- main dedupe engine ---------------------------------------------

// Function-local static regex objects for process function
static const std::regex& get_re_vg_line() {
    static const std::regex re(R"(^==[0-9]+==)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_prefix() {
    static const std::regex re(R"(^==[0-9]+==[ \t\v\f\r\n]*)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_start() {
    static const std::regex re(
        R"((Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ blocks|still reachable|possibly lost|definitely lost|Process terminating))",
        std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_bytes_head() {
    static const std::regex re(R"([0-9]+ bytes in [0-9]+ blocks)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_at() {
    static const std::regex re(R"(at : +)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_by() {
    static const std::regex re(R"(by : +)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

static const std::regex& get_re_q() {
    static const std::regex re(R"(\?{3,})", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

void process(std::istream& in, const Options& opt)
{
    std::ostringstream raw, sig;
    VecS sigLines;
    sigLines.reserve(64);

    std::unordered_set<Str> seen;
    seen.reserve(256);

    auto flush = [&]() {
        const Str rawStr = raw.str();
        if (rawStr.empty()) return;

        Str key;
        if (opt.depth > 0) {
            key.reserve(256);
            for (int i = 0; i < opt.depth && i < static_cast<int>(sigLines.size()); ++i) {
                key += sigLines[static_cast<size_t>(i)];
                key += '\n';
            }
        } else {
            key = sig.str();
        }
        if (seen.insert(key).second) {
            std::cout << rawStr << '\n'; // block separator
        }
        raw.str(""); raw.clear();
        sig.str(""); sig.clear();
        sigLines.clear();
    };

    Str line;
    while (std::getline(in, line)) {
        if (!std::regex_search(line, get_re_vg_line())) continue;

        // strip "==PID== "
        line = std::regex_replace(line, get_re_prefix(), "");

        if (std::regex_search(line, get_re_start())) {
            flush();
            if (std::regex_search(line, get_re_bytes_head())) {
                // Skip processing this line if it's a bytes header
                continue;
            }
            // Continue processing this line as the start of a new block
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

        // canonicalize once
        Str cl = canon(line);
        sig << cl << '\n';
        sigLines.push_back(std::move(cl));
    }
    flush();
}

// ---------- load file + optional trim --------------------------------------

VecS read_file_lines(const Str& fname)
{
    FILE* file = safe_fopen(fname, "r");
    if (!file) throw std::runtime_error(create_error_message("opening file", fname));

    VecS lines;
    lines.reserve(1024); // Reserve capacity for better performance

    char* line_buffer = nullptr;
    size_t line_buffer_size = 0;
    ssize_t line_length;

    while ((line_length = getline(&line_buffer, &line_buffer_size, file)) != -1) {
        // Check for memory allocation failure
        if (line_buffer == nullptr) {
            fclose(file);
            throw std::runtime_error(create_error_message("reading file", fname, "Memory allocation failed"));
        }
        // Remove trailing newline and possible CR
        if (line_length > 0 && (line_buffer[line_length - 1] == '\n' || line_buffer[line_length - 1] == '\r')) {
            while (line_length > 0 && (line_buffer[line_length - 1] == '\n' || line_buffer[line_length - 1] == '\r')) {
                line_buffer[--line_length] = '\0';
            }
        }
        lines.emplace_back(line_buffer);
    }

    free(line_buffer);
    fclose(file);
    return lines;
}

// Check if file is large enough to warrant stream processing
bool is_large_file(const Str& fname, size_t threshold_mb = 5) {
    struct stat st{};
    if (safe_stat(fname, &st) != 0) return false;
    if (!S_ISREG(st.st_mode))         return false;
    size_t file_size_mb = static_cast<size_t>(st.st_size) / (1024 * 1024);
    return file_size_mb >= threshold_mb;
}

// Stream processing (also used for stdin)
void process_stream(std::istream& in, const Options& opt) {
    std::ostringstream raw, sig;
    VecS sigLines;
    sigLines.reserve(64);

    // Keep outputs since the *last* marker only.
    std::vector<Str> pending_blocks;
    std::unordered_set<Str> seen;
    pending_blocks.reserve(64);
    seen.reserve(256);

    size_t lines_processed = 0;
    size_t total_lines     = 0;
    bool marker_found      = false;

    if (opt.show_progress && !opt.use_stdin) {
        std::ifstream count_file = safe_ifstream(opt.filename);
        if (count_file) {
            total_lines = static_cast<size_t>(
                std::count(std::istreambuf_iterator<char>(count_file),
                           std::istreambuf_iterator<char>(), '\n'));
        }
    }

    auto clear_current_state = [&](){
        raw.str(""); raw.clear();
        sig.str(""); sig.clear();
        sigLines.clear();
    };

    auto reset_epoch = [&](){
        // forget everything collected so far (we're starting after a newer marker)
        pending_blocks.clear();
        seen.clear();
        clear_current_state();
    };

    auto flush = [&]() {
        const Str rawStr = raw.str();
        if (rawStr.empty()) return;

        Str key;
        if (opt.depth > 0) {
            key.reserve(256);
            for (int i = 0; i < opt.depth && i < static_cast<int>(sigLines.size()); ++i) {
                key += sigLines[static_cast<size_t>(i)];
                key += '\n';
            }
        } else {
            key = sig.str();
        }
        if (seen.insert(key).second) {
            // store; we will print only after we are sure no newer marker appears
            pending_blocks.emplace_back(rawStr + '\n');
        }
        clear_current_state();
    };

    Str line;
    while (std::getline(in, line)) {
        ++lines_processed;

        if (opt.show_progress && (lines_processed % 1000 == 0)) {
            report_progress(lines_processed, total_lines, opt.filename);
        }

        // Marker handling:
        // If trimming is enabled and we see a marker, we drop everything collected so far
        // and start fresh — this achieves "trim to last marker" while remaining streaming-friendly.
        if (opt.trim && line.find(opt.marker) != Str::npos) {
            marker_found = true;
            reset_epoch();
            continue; // skip marker line itself
        }

        if (!std::regex_search(line, get_re_vg_line())) continue;

        // strip "==PID== "
        line = std::regex_replace(line, get_re_prefix(), "");

        if (std::regex_search(line, get_re_start())) {
            flush();
            if (std::regex_search(line, get_re_bytes_head())) {
                // Skip processing this line if it's a bytes header
                continue;
            }
            // Continue processing this line as the start of a new block
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
        Str cl = canon(line);
        sig << cl << '\n';
        sigLines.push_back(std::move(cl));
    }

    if (opt.show_progress) {
        report_progress(lines_processed, total_lines, opt.filename);
    }

    // Flush the last block
    flush();

    // Print only what belongs to the last segment (or all if no marker was found and trimming is disabled)
    if (!opt.trim || marker_found) {
        for (const auto& block : pending_blocks) {
            std::cout << block;
        }
    }
}

// Stream wrapper for files
void process_file_stream(const Str& fname, const Options& opt) {
    std::ifstream file = safe_ifstream(fname);
    if (!file) throw std::runtime_error(create_error_message("opening file", fname));
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
        FILE* version_file = safe_fopen(path, "r");
        if (version_file) {
            char* line_buffer = nullptr;
            size_t line_buffer_size = 0;
            ssize_t line_length = getline(&line_buffer, &line_buffer_size, version_file);
            fclose(version_file);
            
            if (line_length > 0 && line_buffer) {
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
    // speed up i/o
    std::ios::sync_with_stdio(false);
    std::cin.tie(nullptr);

    Options opt;
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

    // FIX: added 'p' and 'M' to short options (bug in original)
    int c;
    while ((c = getopt_long(argc, argv, "kvd:m:spMVh", long_opts, nullptr)) != -1) {
        switch (c) {
            case 'k': opt.trim = false; break;
            case 'v': opt.scrub_raw = false; break;
            case 'd':
                try {
                    opt.depth = std::stoi(optarg);
                    if (opt.depth < 0) {
                        std::cerr << "Error: Depth must be non-negative (got: " << optarg << ")\n";
                        return 1;
                    }
                    if (opt.depth > 1000) {
                        std::cerr << "Error: Depth value too large (got: " << optarg << ", max: 1000)\n";
                        return 1;
                    }
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
                std::cout << "vglog-filter version " << get_version() << std::endl;
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
        } else {
            FILE* test_file = safe_fopen(opt.filename, "r");
            if (!test_file) {
                std::cerr << create_error_message("opening file", opt.filename) << "\n";
                std::cerr << "Please check that the file exists and is readable\n";
                return 1;
            }
            fclose(test_file);
        }
    }

    // Determine processing mode
    bool use_stream_mode = opt.stream_mode;
    if (!use_stream_mode) {
        if (opt.use_stdin) {
            use_stream_mode = true; // stdin can't seek
        } else {
            use_stream_mode = is_large_file(opt.filename, 5);
            if (use_stream_mode) {
                std::cerr << "Info: Large file detected, using stream processing mode\n";
            }
        }
    }

    try {
        if (use_stream_mode) {
            if (opt.monitor_memory) report_memory_usage("starting stream processing", opt.filename);
            if (opt.use_stdin) {
                process_stream(std::cin, opt);
            } else {
                process_file_stream(opt.filename, opt);
            }
            if (opt.monitor_memory) report_memory_usage("completed stream processing", opt.filename);
        } else {
            if (opt.monitor_memory) report_memory_usage("starting file reading", opt.filename);
            VecS lines = read_file_lines(opt.filename);
            if (opt.monitor_memory) report_memory_usage("completed file reading", opt.filename);

            if (lines.empty()) {
                std::cerr << "Warning: Input file '" << opt.filename << "' is empty\n";
                return 0;
            }

            size_t start = 0;
            if (opt.trim) {
                StrSpan lines_span = create_span_from_vector(lines);
                start = find_marker_in_span(lines_span, opt.marker); // 0 if not found
            }

            std::stringstream work;
            if (start > 0 && start < lines.size()) {
                std::copy(lines.begin() + static_cast<std::ptrdiff_t>(start), lines.end(),
                          std::ostream_iterator<Str>(work, "\n"));
            } else if (opt.trim && start == 0) {
                // No marker found and trimming is enabled, so no output
                return 0;
            } else if (!opt.trim) {
                // Trimming disabled, process entire file
                std::copy(lines.begin(), lines.end(),
                          std::ostream_iterator<Str>(work, "\n"));
            }

            if (opt.monitor_memory) report_memory_usage("starting deduplication", opt.filename);
            process(work, opt);
            if (opt.monitor_memory) report_memory_usage("completed deduplication", opt.filename);
        }
    } catch (const std::exception& e) {
        std::cerr << create_error_message("processing", opt.filename, e.what()) << "\n";
        return 1;
    }

    return 0;
}
