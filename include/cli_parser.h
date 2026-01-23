// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "options.h"
#include <optional>

namespace cli {

/**
 * @brief Parses command line arguments into an Options struct.
 * @return std::optional<Options> containing options if successful, or nullopt if help/version was printed.
 * @throws std::runtime_error on invalid arguments.
 */
std::optional<Options> parseArgs(int argc, char* argv[]);

} // namespace cli
