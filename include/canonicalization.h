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

namespace canonicalization {

using Str = std::string;
using StrView = std::string_view;

StrView trim_view(StrView s);
Str rtrim(Str s);
Str regex_replace_all(const Str& src, const std::regex& re, const Str& repl);
Str canon(Str s);
Str canon(StrView s);

// Regex getters
const std::regex& get_re_addr();
const std::regex& get_re_line();
const std::regex& get_re_array();
const std::regex& get_re_template();
const std::regex& get_re_ws();

} // namespace canonicalization

#endif // CANONICALIZATION_H