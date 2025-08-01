// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef PATH_VALIDATION_H
#define PATH_VALIDATION_H

#include <string>
#include <filesystem>
#include <fstream>

namespace path_validation {

// Validates a given file path to ensure it is safe to use.
// A path is considered safe if it is within the current working directory.
// Returns the absolute, canonical path if valid.
std::filesystem::path validate_and_canonicalize(const std::string& input_path);

// Safely opens a file stream (ifstream) after validating the path.
std::ifstream safe_ifstream(const std::string& filename);

} // namespace path_validation

#endif // PATH_VALIDATION_H