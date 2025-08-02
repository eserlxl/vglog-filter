// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <canonicalization.h>
#include <algorithm>
#include <cctype>
#include <stdexcept>

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

    // Simple string replacement functions to replace regex
    Str replace_addr_pattern(Str s) {
        // Replace 0x[0-9a-fA-F]+ with 0xADDR
        size_t pos = 0;
        while ((pos = s.find("0x", pos)) != std::string::npos) {
            size_t start = pos;
            pos += 2; // Skip "0x"
            
            // Find end of hex digits
            while (pos < s.size() && std::isxdigit(s[pos])) pos++;
            
            // Replace if we found hex digits
            if (pos > start + 2) {
                s.replace(start, pos - start, "0xADDR");
                pos = start + 6; // Skip the replacement
            }
        }
        return s;
    }
    
    Str replace_line_pattern(Str s) {
        // Replace :[0-9]+ with :LINE
        size_t pos = 0;
        while ((pos = s.find(':', pos)) != std::string::npos) {
            size_t start = pos;
            pos++; // Skip ':'
            
            // Find end of digits
            while (pos < s.size() && std::isdigit(s[pos])) pos++;
            
            // Replace if we found digits
            if (pos > start + 1) {
                s.replace(start, pos - start, ":LINE");
                pos = start + 5; // Skip the replacement
            }
        }
        return s;
    }
    
    Str replace_array_pattern(Str s) {
        // Replace [0-9]+ with []
        size_t pos = 0;
        while ((pos = s.find('[', pos)) != std::string::npos) {
            size_t start = pos;
            pos++; // Skip '['
            
            // Find end of digits
            while (pos < s.size() && std::isdigit(s[pos])) pos++;
            
            // Check if next char is ']'
            if (pos < s.size() && s[pos] == ']') {
                s.replace(start, pos - start + 1, "[]");
                pos = start + 2; // Skip the replacement
            }
        }
        return s;
    }
    
    Str replace_template_pattern(Str s) {
        // Replace <[^>]*> with <T>
        size_t pos = 0;
        while ((pos = s.find('<', pos)) != std::string::npos) {
            size_t start = pos;
            pos++; // Skip '<'
            
            // Find closing '>'
            while (pos < s.size() && s[pos] != '>') pos++;
            
            // Replace if we found closing '>'
            if (pos < s.size()) {
                s.replace(start, pos - start + 1, "<T>");
                pos = start + 3; // Skip the replacement
            }
        }
        return s;
    }
    
    Str replace_ws_pattern(Str s) {
        // Replace multiple whitespace with single space
        size_t pos = 0;
        while (pos < s.size()) {
            if (std::isspace(s[pos])) {
                size_t start = pos;
                // Find end of whitespace sequence
                while (pos < s.size() && std::isspace(s[pos])) pos++;
                
                // Replace with single space if multiple whitespace
                if (pos > start + 1) {
                    s.replace(start, pos - start, " ");
                    pos = start + 1; // Skip the replacement
                }
            } else {
                pos++;
            }
        }
        return s;
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
    Str tmp(s);
    return canon(std::move(tmp));
}

} // namespace canonicalization
