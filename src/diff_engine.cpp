// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "diff_engine.h"
#include <string>
#include <unordered_set>

DiffResult DiffEngine::compare(const std::vector<LogEntry>& baseline,
                               const std::vector<LogEntry>& target) {
    DiffResult result;
    std::unordered_set<std::string> baselineSigs;
    
    for (const auto& entry : baseline) {
        baselineSigs.insert(entry.signature);
    }

    std::unordered_set<std::string> targetSigs;
    for (const auto& entry : target) {
        targetSigs.insert(entry.signature);
        if (baselineSigs.find(entry.signature) == baselineSigs.end()) {
            result.newErrors.push_back(entry);
        } else {
            result.commonErrors.push_back(entry);
        }
    }

    for (const auto& entry : baseline) {
        if (targetSigs.find(entry.signature) == targetSigs.end()) {
            result.fixedErrors.push_back(entry);
        }
    }

    return result;
}

DiffEngine::DiffStats DiffEngine::computeStats(const DiffResult& result) {
    DiffStats stats;
    stats.totalNew = result.newErrors.size();
    stats.totalFixed = result.fixedErrors.size();
    stats.totalCommon = result.commonErrors.size();

    size_t baselineTotal = stats.totalFixed + stats.totalCommon;
    
    if (baselineTotal > 0) {
        stats.regressionRate = (static_cast<double>(stats.totalNew) / static_cast<double>(baselineTotal)) * 100.0;
        stats.fixRate = (static_cast<double>(stats.totalFixed) / static_cast<double>(baselineTotal)) * 100.0;
    } else {
        stats.regressionRate = 0.0;
        stats.fixRate = 0.0;
    }
    
    return stats;
}
