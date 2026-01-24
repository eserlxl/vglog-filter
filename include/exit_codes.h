// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

namespace exit_codes {
inline constexpr int SUCCESS = 0;
inline constexpr int GENERIC_ERROR = 1;
inline constexpr int INVALID_ARGUMENT = 2;
inline constexpr int FILE_ERROR = 3;
inline constexpr int STRICT_MODE_FAIL = 4;
inline constexpr int SIGNAL_INTERRUPT = 130; // 128 + 2 (SIGINT)
} // namespace exit_codes
