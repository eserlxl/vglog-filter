// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "log_entry.h"
#include <vector>

struct DiffResult {
    std::vector<LogEntry> newErrors;
    std::vector<LogEntry> fixedErrors;
    std::vector<LogEntry> commonErrors;
};

class DiffEngine {
public:
    static DiffResult compare(const std::vector<LogEntry>& baseline,
                              const std::vector<LogEntry>& target);
};
