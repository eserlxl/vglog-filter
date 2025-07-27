// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <algorithm>
#include <cctype>
#include <fstream>
#include <getopt.h>
#include <iostream>
#include <iterator>
#include <regex>
#include <sstream>
#include <string>
#include <unordered_set>
#include <vector>

using Str  = std::string;
using VecS = std::vector<Str>;

constexpr int DEFAULT_DEPTH = 1;
constexpr char DEFAULT_MARKER[] = "Successfully downloaded debug";

struct Options {
    int  depth        = DEFAULT_DEPTH;
    bool trim         = true;
    bool scrub_raw    = true;
    Str  marker       = DEFAULT_MARKER;
    Str  filename;
};

void usage(const char* prog) {
    std::cerr <<
        "Usage: " << prog << " [options] <valgrind_log>\n\n"
        "Options\n"
        "  -k, --keep-debug-info   Keep everything; do not trim above last debug marker.\n"
        "  -v, --verbose           Show completely raw blocks (no address / \"at:\" scrub).\n"
        "  -d N, --depth N         Signature depth (default: " << DEFAULT_DEPTH << ", 0 = unlimited).\n"
        "  -m S, --marker S        Marker string (default: \"" << DEFAULT_MARKER << "\").\n"
        "  -h, --help              Show this help.\n";
}

// ---------- helpers ---------------------------------------------------------

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

Str canon(Str s)
{
    static const std::regex re_addr(R"(0x[0-9a-fA-F]+)");
    static const std::regex re_line(R"(:[0-9]+)");
    static const std::regex re_array(R"(\[[0-9]+\])");
    static const std::regex re_template(R"(<[^>]*>)");
    static const std::regex re_ws(R"([ \t\v\f\r\n]+)");
    s = regex_replace_all(s, re_addr, "0xADDR");
    s = regex_replace_all(s, re_line, ":LINE");
    s = regex_replace_all(s, re_array, "[]");
    s = regex_replace_all(s, re_template, "<T>");
    s = regex_replace_all(s, re_ws, " ");
    s = rtrim(s);
    return s;
}

// ---------- main dedupe engine ---------------------------------------------

void process(std::istream& in, const Options& opt)
{
    const std::regex re_vg_line(R"(^==[0-9]+==)");
    const std::regex re_prefix(R"(^==[0-9]+==[ \t\v\f\r\n]*)");
    const std::regex re_start(
        R"((Invalid (read|write)|Syscall param|Use of uninitialised|" \
        "Conditional jump|bytes in [0-9]+ blocks|still reachable|"  \
        "possibly lost|definitely lost|Process terminating))");
    const std::regex re_bytes_head(R"([0-9]+ bytes in [0-9]+ blocks)");

    // raw scrubbing regexes
    const std::regex re_addr(R"(0x[0-9a-fA-F]+)");
    const std::regex re_at(R"(at : +)");
    const std::regex re_by(R"(by : +)");
    const std::regex re_q(R"(\?{3,})");

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
        if (!std::regex_search(line, re_vg_line)) continue;
        // strip "==PID== "
        line = std::regex_replace(line, re_prefix, "");
        if (std::regex_search(line, re_start)) {
            flush();
            if (std::regex_search(line, re_bytes_head)) continue;
        }
        Str rawLine = line;
        if (opt.scrub_raw) {
            rawLine = regex_replace_all(rawLine, re_addr, "");
            rawLine = regex_replace_all(rawLine, re_at, "");
            rawLine = regex_replace_all(rawLine, re_by, "");
            rawLine = regex_replace_all(rawLine, re_q, "");
        }
        if (trim(rawLine).empty()) continue;
        raw << rawLine << '\n';
        sig << canon(line) << '\n';
        sigLines.push_back(canon(line));
    }
    flush();
}

// ---------- load file + optional trim --------------------------------------

VecS read_file_lines(const Str& fname)
{
    std::ifstream in(fname);
    if (!in) throw std::runtime_error("Cannot open '" + fname + "'");
    VecS lines;
    Str  line;
    while (std::getline(in, line)) lines.push_back(std::move(line));
    return lines;
}

int main(int argc, char* argv[])
{
    Options opt;
    static const option long_opts[] = {
        {"keep-debug-info", no_argument,       nullptr, 'k'},
        {"verbose",         no_argument,       nullptr, 'v'},
        {"depth",           required_argument, nullptr, 'd'},
        {"marker",          required_argument, nullptr, 'm'},
        {"help",            no_argument,       nullptr, 'h'},
        {nullptr,           0,                 nullptr,  0 }
    };
    int c;
    while ((c = getopt_long(argc, argv, "kvd:m:h", long_opts, nullptr)) != -1) {
        switch (c) {
            case 'k': opt.trim = false; break;
            case 'v': opt.scrub_raw = false; break;
            case 'd': opt.depth = std::stoi(optarg); break;
            case 'm': opt.marker = optarg; break;
            case 'h': usage(argv[0]); return 0;
            default : usage(argv[0]); return 1;
        }
    }
    if (optind >= argc) { usage(argv[0]); return 1; }
    opt.filename = argv[optind];
    // read file
    VecS lines;
    try { lines = read_file_lines(opt.filename); }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
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
    std::stringstream work;
    std::copy(lines.begin() + static_cast<long>(start), lines.end(),
              std::ostream_iterator<Str>(work, "\n"));
    // run dedupe
    process(work, opt);
    return 0;
} 