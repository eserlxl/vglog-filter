// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <canonicalization.h>
#include <algorithm>
#include <cctype>

namespace canonicalization {

using Str = std::string;
using StrView = std::string_view;

namespace { // Anonymous namespace for internal linkage

    StrView ltrim_view(StrView s) {
        auto start = std::find_if(s.begin(), s.end(),
                                [](int ch){ return !std::isspace(ch); });
        return StrView(start, static_cast<size_t>(s.end() - start));
    }

    StrView rtrim_view_internal(StrView s) {
        auto end = std::find_if(s.rbegin(), s.rend(),
                                [](int ch){ return !std::isspace(ch); }).base();
        return StrView(s.begin(), static_cast<size_t>(end - s.begin()));
    }

} // anonymous namespace

StrView trim_view(StrView s) {
    return rtrim_view_internal(ltrim_view(s));
}

Str rtrim(Str s) {
    s.erase(std::find_if(s.rbegin(), s.rend(),
                         [](int ch){ return !std::isspace(ch); }).base(),
            s.end());
    return s;
}

Str regex_replace_all(StrView src, const std::regex& re, StrView repl)
{
    return std::regex_replace(src.data(), re, repl.data());
}

const std::regex& get_re_addr() {
    static const std::regex re(R"(0x[0-9a-fA-F]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

const std::regex& get_re_line() {
    static const std::regex re(R"(:[0-9]+)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

const std::regex& get_re_array() {
    static const std::regex re(R"(\[[0-9]+\])", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

const std::regex& get_re_template() {
    static const std::regex re(R"(<[^>]*>)", std::regex::optimize | std::regex::ECMAScript);
    return re;
}

const std::regex& get_re_ws() {
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
    return Str(trim_view(s));
}

Str canon(StrView s)
{
    Str tmp(s);
    return canon(std::move(tmp));
}

} // namespace canonicalization
