// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "canonicalization.h"

#include <algorithm>
#include <cctype>
#include <string>
#include <string_view>

namespace canonicalization {

using Str     = std::string;
using StrView = std::string_view;

namespace {

// Safe wrappers for ctype (needed in implementation)
constexpr bool is_digit(char c) noexcept {
    return std::isdigit(static_cast<unsigned char>(c)) != 0;
}
constexpr bool is_xdigit(char c) noexcept {
    return std::isxdigit(static_cast<unsigned char>(c)) != 0;
}

// Simple string replacement functions to replace regex
Str replace_addr_pattern(Str s) {
    // Replace 0x[0-9a-fA-F]+ with 0xADDR
    size_t pos = 0;
    while ((pos = s.find("0x", pos)) != std::string::npos) {
        const size_t start = pos;
        pos += 2; // Skip "0x"
        
        // Find end of hex digits
        size_t j = pos;
        while (j < s.size() && is_xdigit(s[j])) ++j;
        
        // Replace if we found hex digits
        if (j > pos) {
            s.replace(start, j - start, "0xADDR");
            pos = start + 6; // Skip the replacement
        }
    }
    return s;
}

Str replace_line_pattern(Str s) {
    // Replace :[0-9]+ with :LINE
    size_t pos = 0;
    while ((pos = s.find(':', pos)) != std::string::npos) {
        const size_t start = pos++;
        
        // Find end of digits
        size_t j = pos;
        while (j < s.size() && is_digit(s[j])) ++j;
        
        // Replace if we found digits
        if (j > pos) {
            s.replace(start, j - start, ":LINE");
            pos = start + 5; // Skip the replacement
        }
    }
    return s;
}

Str replace_array_pattern(Str s) {
    // Replace [0-9]+ with []
    size_t pos = 0;
    while ((pos = s.find('[', pos)) != std::string::npos) {
        const size_t start = pos++;
        
        // Find end of digits
        size_t j = pos;
        while (j < s.size() && is_digit(s[j])) ++j;
        
        // Check if next char is ']'
        if (j < s.size() && s[j] == ']') {
            s.replace(start, j - start + 1, "[]");
            pos = start + 2; // Skip the replacement
        }
    }
    return s;
}

Str replace_template_pattern(Str s) {
    // Replace <[^>]*> with <T>
    size_t pos = 0;
    while ((pos = s.find('<', pos)) != std::string::npos) {
        const size_t start = pos++;
        
        // Find closing '>'
        size_t j = pos;
        while (j < s.size() && s[j] != '>') ++j;
        
        // Replace if we found closing '>'
        if (j < s.size()) {
            s.replace(start, j - start + 1, "<T>");
            pos = start + 3; // Skip the replacement
        }
    }
    return s;
}

Str replace_ws_pattern(Str s) {
    // Collapse runs of whitespace to a single space
    Str out;
    out.reserve(s.size());
    bool in_ws = false;
    for (char c : s) {
        if (is_space(c)) {
            if (!in_ws) {
                out.push_back(' ');
                in_ws = true;
            }
        } else {
            out.push_back(c);
            in_ws = false;
        }
    }
    return out;
}

} // namespace

Str rtrim(Str s) {
    auto it = std::find_if(s.rbegin(), s.rend(), [](char ch) { return !is_space(ch); });
    s.erase(it.base(), s.end());
    return s;
}

Str canon(Str s) {
    // Apply canonicalization transformations in sequence using string matching
    s = replace_addr_pattern(std::move(s));
    s = replace_line_pattern(std::move(s));
    s = replace_array_pattern(std::move(s));
    s = replace_template_pattern(std::move(s));
    s = replace_ws_pattern(std::move(s));
    
    // Return trimmed result
    return Str(trim_view(s));
}

Str canon(StrView s) {
    return canon(std::string{s});
}

} // namespace canonicalization
