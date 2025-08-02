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

[[nodiscard]] std::string_view trim_view(std::string_view s);
[[nodiscard]] std::string rtrim(std::string s);
[[nodiscard]] std::string canon(std::string s);
[[nodiscard]] std::string canon(std::string_view s);

} // namespace canonicalization
