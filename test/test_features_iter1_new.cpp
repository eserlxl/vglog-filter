// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "diff_engine.h"
#include "store_log_writer.h"
#include "filter_config.h"
#include "log_entry.h"
#include <iostream>
#include <vector>
#include <cassert>

bool test_diff_engine_stats() {
    std::cout << "Testing DiffEngine Stats...\n";
    
    LogEntry e1; e1.signature = "sig1";
    LogEntry e2; e2.signature = "sig2";
    LogEntry e3; e3.signature = "sig3";

    std::vector<LogEntry> baseline = {e1, e2};
    std::vector<LogEntry> target = {e2, e3}; 
    // e1 is fixed (in baseline only)
    // e2 is common
    // e3 is new (in target only)

    auto result = DiffEngine::compare(baseline, target);
    auto stats = DiffEngine::computeStats(result);

    if (stats.totalNew != 1) return false;
    if (stats.totalFixed != 1) return false;
    if (stats.totalCommon != 1) return false;
    
    // Baseline total = 2.
    // Regression rate = 1/2 = 50%
    // Fix rate = 1/2 = 50%
    if (stats.regressionRate != 50.0) return false;
    if (stats.fixRate != 50.0) return false;

    std::cout << "PASS: DiffEngine Stats\n";
    return true;
}

bool test_store_log_writer_control() {
    std::cout << "Testing StoreLogWriter Control...\n";
    StoreLogWriter writer;
    
    LogEntry e;
    writer.writeEntry(e);
    writer.writeEntry(e);
    if (writer.getEntries().size() != 2) return false;

    writer.clear();
    if (!writer.getEntries().empty()) return false;

    writer.setCapacity(2);
    writer.writeEntry(e);
    writer.writeEntry(e);
    writer.writeEntry(e); // Should be dropped
    
    if (writer.getEntries().size() != 2) return false;
    if (!writer.isFull()) return false;

    std::cout << "PASS: StoreLogWriter Control\n";
    return true;
}

bool test_config_validation() {
    std::cout << "Testing Config Validation...\n";
    FilterConfig cfg;
    
    // Valid case
    if (!cfg.validate().empty()) return false;

    // PID Conflict
    cfg.includePids = {100};
    cfg.excludePids = {100, 101};
    auto errs = cfg.validate();
    if (errs.size() != 1) {
        std::cerr << "Expected 1 error, got " << errs.size() << "\n";
        return false;
    }
    if (errs[0].find("PID 100") == std::string::npos) return false;

    // Cleanup
    cfg.includePids.clear();
    cfg.excludePids.clear();

    // Thread Conflict
    cfg.includeThreads = {10, 20};
    cfg.excludeThreads = {20};
    errs = cfg.validate();
    if (errs.empty()) return false;
    
    std::cout << "PASS: Config Validation\n";
    return true;
}

int main() {
    bool pass = true;
    pass &= test_diff_engine_stats();
    pass &= test_store_log_writer_control();
    pass &= test_config_validation();
    return pass ? 0 : 1;
}
