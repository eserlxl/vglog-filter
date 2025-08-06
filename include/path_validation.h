// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include <filesystem>
#include <fstream>
#include <string_view>
#include <string>

namespace path_validation {

// Validates a given path is *relative* and resolves within CWD (no traversal).
// Returns the resolved (weakly_canonical) absolute path.
// The literal "-" is treated as stdin sentinel and returned as-is.
[[nodiscard]] std::filesystem::path validate_and_canonicalize(std::string_view input_path);

// Sanitizes and validates a path string, returning a path string safe to open.
[[nodiscard]] std::string sanitize_path_for_file_access(std::string_view input_path);

// Safely opens an ifstream after validating the path (exceptions enabled).
[[nodiscard]] std::ifstream safe_ifstream(std::string_view filename);

} // namespace path_validation
