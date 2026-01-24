// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "test_helpers.h"
#include "diff_engine.h"
#include <sstream>

bool test_diff_json_export() {
    LogEntry e1;
    e1.errorType = "Leak";
    e1.pid = "100";
    e1.signature = "sig1";
    
    LogEntry e2;
    e2.errorType = "InvalidRead";
    e2.pid = "101";
    e2.signature = "sig2";
    
    std::vector<LogEntry> baseline = {e1};
    std::vector<LogEntry> target = {e2}; // e1 fixed (missing in target), e2 new (missing in baseline)
    
    auto result = DiffEngine::compare(baseline, target);
    auto stats = DiffEngine::computeStats(result);
    
    std::stringstream ss;
    DiffEngine::writeDiffJson(result, stats, ss);
    
    std::string json = ss.str();
    
    TEST_ASSERT(json.find("\"totalNew\": 1") != std::string::npos, "Stats New missing");
    TEST_ASSERT(json.find("\"totalFixed\": 1") != std::string::npos, "Stats Fixed missing");
    
    TEST_ASSERT(json.find("\"newErrors\": [") != std::string::npos, "New Errors array missing");
    TEST_ASSERT(json.find("\"type\": \"InvalidRead\"") != std::string::npos, "New error type missing");
    
    TEST_ASSERT(json.find("\"fixedErrors\": [") != std::string::npos, "Fixed Errors array missing");
    TEST_ASSERT(json.find("\"type\": \"Leak\"") != std::string::npos, "Fixed error type missing");
    
    TEST_PASS("Diff JSON Export works");
    return true;
}

int main() {
    if (test_diff_json_export()) {
        std::cout << "All diff tests passed\n";
        return 0;
    }
    return 1;
}
