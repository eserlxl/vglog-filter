// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Common test macros and helpers for vglog-filter tests
#pragma once
#include <iostream>
#include <string>
#include <string_view>
#include <regex>
#include <fstream>

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

inline std::string trim(std::string_view s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string_view::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return std::string(s.substr(start, end - start + 1));
}

inline std::string regex_replace_all(std::string_view src, const std::regex& re, std::string_view repl) {
    return std::regex_replace(std::string(src), re, std::string(repl));
}

inline std::string canon(std::string_view s) {
    std::string result(s);
    // Canonicalize addresses, line numbers, etc. (example logic)
    result = regex_replace_all(result, std::regex("0x[0-9A-Fa-f]+"), "0xADDR");
    result = regex_replace_all(result, std::regex(":\\d+"), ":LINE");
    result = regex_replace_all(result, std::regex("\\[\\d+\\]"), "[]");
    result = regex_replace_all(result, std::regex("<[^>]*>"), "<T>");
    return result;
}

class TempFile {
public:
    explicit TempFile(const char* path, std::ios::openmode mode = std::ios::out) 
        : path_(path), stream_(path, mode) {}
    ~TempFile() { 
        stream_.close();
        std::remove(path_); 
    }
    std::ofstream& get_stream() { return stream_; }
    const char* path() const { return path_; }
    void write(const std::string& content) { stream_ << content; }
    void close() { stream_.close(); }
    void flush() { stream_.flush(); }
private:
    const char* path_;
    std::ofstream stream_;
};