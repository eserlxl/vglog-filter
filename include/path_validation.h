// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include <string>
#include <string_view>
#include <filesystem>
#include <fstream>

namespace path_validation {

// Validates a given file path to ensure it is safe to use.
// A path is considered safe if it is within the current working directory.
// Returns the absolute, canonical path if valid.
[[nodiscard]] std::filesystem::path validate_and_canonicalize(std::string_view input_path);

// Sanitizes and validates a path string, returning a safe path string for file operations.
// This function avoids MSAN issues by using string-based validation instead of filesystem::path.
[[nodiscard]] std::string sanitize_path_for_file_access(std::string_view input_path);

// Safely opens a file stream (ifstream) after validating the path.
[[nodiscard]] std::ifstream safe_ifstream(std::string_view filename);

} // namespace path_validation
