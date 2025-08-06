// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include <string>
#include <string_view>

namespace canonicalization {

namespace {
    constexpr bool is_space(char c) noexcept {
        return std::isspace(static_cast<unsigned char>(c)) != 0;
    }

    constexpr std::string_view ltrim_view(std::string_view s) noexcept {
        size_t i = 0;
        while (i < s.size() && is_space(s[i])) ++i;
        return s.substr(i);
    }

    constexpr std::string_view rtrim_view_internal(std::string_view s) noexcept {
        size_t n = s.size();
        while (n > 0 && is_space(s[n - 1])) --n;
        return s.substr(0, n);
    }
}

[[nodiscard]] constexpr std::string_view trim_view(std::string_view s) noexcept {
    return rtrim_view_internal(ltrim_view(s));
}

[[nodiscard]] std::string rtrim(std::string s);
[[nodiscard]] std::string canon(std::string s);
[[nodiscard]] std::string canon(std::string_view s);

} // namespace canonicalization
