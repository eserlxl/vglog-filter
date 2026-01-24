// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "html_log_writer.h"
#include "diff_engine.h"
#include "options_builder.h"
#include "log_entry.h"
#include "file_utils.h"
#include <iostream>
#include <filesystem>
#include <fstream>
#include <vector>
#include <cassert>

namespace {
    const double EXPECTED_REGRESSION_RATE = 33.3;
    const double EXPECTED_FIX_RATE = 16.6;
    const size_t NEW_ERRORS = 10;
    const size_t FIXED_ERRORS = 5;
    const size_t COMMON_ERRORS = 20;
}

bool testLogEntryEquality() {
    std::cout << "Testing LogEntry Equality...\n";
    LogEntry e1; e1.signature = "abc"; e1.errorType = "TypeA";
    LogEntry e2; e2.signature = "abc"; e2.errorType = "TypeA";
    LogEntry e3; e3.signature = "def"; e3.errorType = "TypeA";

    if (!(e1 == e2)) {
        std::cerr << "FAIL: e1 should equal e2\n";
        return false;
    }
    if (e1 == e3) {
        std::cerr << "FAIL: e1 should not equal e3\n";
        return false;
    }
    std::cout << "PASS: LogEntry Equality\n";
    return true;
}

bool testOptionsBuilderExtensions() {
    std::cout << "Testing OptionsBuilder Extensions...\n";
    OptionsBuilder b;
    b.setTimeAfter("10:00:00")
     .setTimeBefore("12:00:00")
     .addIncludeStackPattern("foo.*")
     .addExcludeTypeRegex("Leak.*")
     .addIncludeTypeRegex("Error.*")
     .addExcludeFunctionRegex("main")
     .addIncludeFunctionRegex("test");
     
    auto opts = b.build();
    
    if (opts.timeAfter != "10:00:00") return false;
    if (opts.timeBefore != "12:00:00") return false;
    if (opts.filter.includeStackPatterns.size() != 1) return false;
    if (opts.filter.includeStackPatterns[0] != "foo.*") return false;
    if (opts.filter.excludeTypesRegex.size() != 1) return false;
    if (opts.filter.excludeFunctionsRegex.size() != 1) return false;
    
    std::cout << "PASS: OptionsBuilder Extensions\n";
    return true;
}

bool testHtmlDiffSummary() {
    std::cout << "Testing HtmlLogWriter Diff Summary...\n";
    const std::string path = "test_html_diff.html";
    {
        HtmlLogWriter writer(path);
        DiffEngine::DiffStats stats;
        stats.totalNew = NEW_ERRORS;
        stats.totalFixed = FIXED_ERRORS;
        stats.totalCommon = COMMON_ERRORS;
        stats.regressionRate = EXPECTED_REGRESSION_RATE;
        stats.fixRate = EXPECTED_FIX_RATE;
        
        writer.writeDiffSummary(stats);
    }
    
    std::string content = readFileContent(path);
    
    if (content.find("Diff Summary") == std::string::npos) return false;
    if (content.find("New Errors") == std::string::npos) return false;
    if (content.find("33.3%") == std::string::npos) return false;

    std::filesystem::remove(path);
    std::cout << "PASS: HtmlLogWriter Diff Summary\n";
    return true;
}

int main() {
    bool pass = true;
    pass &= testLogEntryEquality();
    pass &= testOptionsBuilderExtensions();
    pass &= testHtmlDiffSummary();
    return pass ? 0 : 1;
}
