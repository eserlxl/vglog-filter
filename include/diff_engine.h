// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "log_entry.h"
#include <vector>

/**
 * @brief Container for the results of a diff operation.
 */
struct DiffResult {
    std::vector<LogEntry> newErrors;    ///< Errors present in target but not baseline
    std::vector<LogEntry> fixedErrors;  ///< Errors present in baseline but not target
    std::vector<LogEntry> commonErrors; ///< Errors present in both
};

/**
 * @brief Logic for comparing two sets of log entries.
 */
class DiffEngine {
public:
    /**
     * @brief Compares a baseline set of errors against a target set.
     * 
     * Uses LogEntry::signature for matching.
     * 
     * @param baseline The reference set of errors (e.g. from main branch).
     * @param target The current set of errors (e.g. from local run).
     * @return DiffResult containing categorized errors.
     */
    static DiffResult compare(const std::vector<LogEntry>& baseline,
                              const std::vector<LogEntry>& target);

    struct DiffStats {
        size_t totalNew;
        size_t totalFixed;
        size_t totalCommon;
        double regressionRate; // new / baseline * 100
        double fixRate;        // fixed / baseline * 100
    };

    /**
     * @brief Computes statistics from a DiffResult.
     */
    static DiffStats computeStats(const DiffResult& result);

    /**
     * @brief Exports diff results as JSON.
     */
    static void writeDiffJson(const DiffResult& result, const DiffStats& stats, std::ostream& out);
};

