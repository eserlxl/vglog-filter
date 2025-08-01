// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef CANONICALIZATION_H
#define CANONICALIZATION_H

#include <string>
#include <string_view>
#include <regex>
#include <algorithm>
#include <cctype>

namespace canonicalization {

using Str      = std::string;
using StrView  = std::string_view;

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

} // namespace canonicalization

#endif // CANONICALIZATION_H
