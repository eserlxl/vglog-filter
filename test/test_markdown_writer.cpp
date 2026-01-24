#include "../include/markdown_log_writer.h"
#include "../include/log_entry.h"
#include "../include/log_processor.h" // For LogStats
#include "test_helpers.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

// Helper to read entire file
std::string readFile(const std::string& path) {
    std::ifstream t(path);
    std::string str((std::istreambuf_iterator<char>(t)),
                     std::istreambuf_iterator<char>());
    return str;
}

void test_markdown_creation() {
    std::string path = "test_output.md";
    {
        MarkdownLogWriter writer(path);
        // Header written on construction
    }
    
    std::string content = readFile(path);
    assert(content.find("# Valgrind Analysis Report") != std::string::npos);
    assert(content.find("| Type | Search | Details |") != std::string::npos);
    std::filesystem::remove(path);
    std::cout << "test_markdown_creation passed\n";
}

void test_markdown_entry() {
    std::string path = "test_entry.md";
    {
        MarkdownLogWriter writer(path);
        LogEntry entry;
        entry.errorType = "InvalidRead";
        entry.pid = 12345;
        entry.rawContent = "Raw Content";
        entry.stackTrace.push_back("main (main.cpp:10)");
        
        writer.writeEntry(entry);
    } // Flush destructor
    
    std::string content = readFile(path);
    assert(content.find("**InvalidRead**") != std::string::npos);
    assert(content.find("12345") != std::string::npos);
    assert(content.find("<details>") != std::string::npos);
    assert(content.find("main (main.cpp:10)") != std::string::npos);
    
    std::filesystem::remove(path);
    std::cout << "test_markdown_entry passed\n";
}

void test_markdown_diff_summary() {
    std::string path = "test_diff.md";
    {
        MarkdownLogWriter writer(path);
        DiffEngine::DiffStats stats;
        stats.totalNew = 5;
        stats.totalFixed = 2;
        stats.totalCommon = 10;
        stats.regressionRate = 10.5;
        stats.fixRate = 5.0;
        
        writer.writeDiffSummary(stats);
    }
    
    std::string content = readFile(path);
    assert(content.find("## Diff Summary") != std::string::npos);
    assert(content.find("| New Errors | 5 | 10.5% |") != std::string::npos);
    assert(content.find("| Fixed Errors | 2 | 5.000000% |") == std::string::npos); // std::to_string default float formatting? 
    // Writer uses stream formatting: std::fixed << std::setprecision(1) << stats.fixRate
    // So 5.0 should be "5.0%".
    // Check for "5.0%"
    assert(content.find("| Fixed Errors | 2 | 5.0% |") != std::string::npos || 
           content.find("| Fixed Errors | 2 | 5.0") != std::string::npos); // Safety

    std::filesystem::remove(path);
    std::cout << "test_markdown_diff_summary passed\n";
}

int main() {
    test_markdown_creation();
    test_markdown_entry();
    test_markdown_diff_summary();
    return 0;
}
