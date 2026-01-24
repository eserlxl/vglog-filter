#include "log_entry.h"
#include "stats_printer.h"
#include "options.h"
#include "test_helpers.h"
#include "log_processor.h"

#include <sstream>
#include <cstdio>
#include <string>
#include <filesystem>

// 1. Test Semantic Helpers
bool test_semantic_helpers() {
    LogEntry entry;
    
    entry.errorType = "Invalid read of size 4";
    if (!entry.isInvalidAccess()) {
        std::cerr << "FAIL: isInvalidAccess false for 'Invalid read'" << std::endl;
        return false;
    }
    
    entry.errorType = "definitely lost: 10 bytes";
    if (!entry.isLeak()) {
        std::cerr << "FAIL: isLeak false for 'definitely lost'" << std::endl;
        return false;
    }
    
    entry.errorType = "Conditional jump or move depends on uninitialised value(s)";
    if (!entry.isUninitialized()) {
        std::cerr << "FAIL: isUninitialized false for 'uninitialised'" << std::endl;
        return false;
    }
    
    entry.tid = 1;
    if (!entry.hasThreadInfo()) {
        std::cerr << "FAIL: hasThreadInfo false when tid set" << std::endl;
        return false;
    }
    
    TEST_PASS("test_semantic_helpers");
    return true;
}

// 2. Test Stats Printer
bool test_stats_printer() {
    LogStats stats;
    stats.linesRead = 100;
    stats.errorCounts["Invalid read"] = 5;
    
    std::string filename = "test_stats_out.txt";
    std::FILE* fp = std::fopen(filename.c_str(), "w");
    if (!fp) return false;
    
    // Test Text Format
    StatsPrinter::print(stats, fp, StatsPrinter::Format::Text);
    std::fclose(fp);
    
    // Read back
    std::ifstream ifs(filename);
    std::string content((std::istreambuf_iterator<char>(ifs)),
                        (std::istreambuf_iterator<char>()));
    
    if (content.find("Lines Read:      100") == std::string::npos) {
        std::cerr << "FAIL: Text output missing lines read" << std::endl;
        return false;
    }
    
    // Test JSON Format
    fp = std::fopen(filename.c_str(), "w");
    StatsPrinter::print(stats, fp, StatsPrinter::Format::Json);
    std::fclose(fp);
    
    ifs.open(filename); // Reopen needed? or std::ifstream needs reset
    std::ifstream ifs2(filename);
    std::string jsonContent((std::istreambuf_iterator<char>(ifs2)),
                            (std::istreambuf_iterator<char>()));
                            
    if (jsonContent.find("\"linesRead\": 100") == std::string::npos) {
        std::cerr << "FAIL: JSON output missing linesRead" << std::endl;
        return false;
    }
    
    std::filesystem::remove(filename);
    TEST_PASS("test_stats_printer");
    return true;
}

// 3. Test Config Dump
bool test_config_dump() {
    Options opt;
    opt.depth = 42;
    opt.trim = true;
    
    std::stringstream ss;
    opt.dump(ss);
    std::string out = ss.str();
    
    if (out.find("\"depth\":42") == std::string::npos) { // Compact JSON
        std::cerr << "FAIL: Config dump missing depth" << std::endl;
        return false;
    }
    if (out.find("\"trim\":true") == std::string::npos) { // Compact JSON
        std::cerr << "FAIL: Config dump missing trim" << std::endl;
        return false;
    }
    
    TEST_PASS("test_config_dump");
    return true;
}

int main() {
    bool passed = true;
    passed &= test_semantic_helpers();
    passed &= test_stats_printer();
    passed &= test_config_dump();
    return passed ? 0 : 1;
}
