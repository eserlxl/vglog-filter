#include "stats_printer.h"
#include "options.h"
#include "test_helpers.h"
#include <cstdio>
#include <filesystem>
#include <string>

// 1. Test StatsPrinter Detailed JSON
bool test_stats_printer_detailed() {
    LogStats stats;
    stats.linesRead = 10;
    stats.errorCountsByPid[123] = 5;

    std::string filename = "test_stats_detailed.json";
    std::FILE* fp = std::fopen(filename.c_str(), "w");
    if (!fp) return false;

    StatsPrinter::print(stats, fp, StatsPrinter::Format::Json, true); // detailed=true
    std::fclose(fp);

    std::string content = read_file_to_string(filename);
    std::filesystem::remove(filename);

    if (content.find("\"errorCountsByPid\"") == std::string::npos) {
        std::cerr << "FAIL: Detailed JSON missing errorCountsByPid: " << content << std::endl;
        return false;
    }
    // SimpleJsonBuilder key-value output: "123":5. String key.
    if (content.find("\"123\":5") == std::string::npos) {
        std::cerr << "FAIL: Detailed JSON missing pid count: " << content << std::endl;
        return false;
    }
    TEST_PASS("test_stats_printer_detailed");
    return true;
}

// 2. Test Options Validation
bool test_options_validation() {
    Options opt;
    opt.jobs = 0; // Invalid
    bool caught = false;
    try {
        opt.validate();
    } catch (const std::exception& e) {
        caught = true;
    }
    if (!caught) {
        std::cerr << "FAIL: validate() accepted jobs=0" << std::endl;
        return false;
    }

    opt.jobs = 1;
    opt.depth = -1; // Invalid
    caught = false;
    try {
        opt.validate();
    } catch (...) {
        caught = true;
    }
    if (!caught) {
        std::cerr << "FAIL: validate() accepted depth=-1" << std::endl;
        return false;
    }

    TEST_PASS("test_options_validation");
    return true;
}

int main() {
    bool passed = true;
    passed &= test_stats_printer_detailed();
    passed &= test_options_validation();
    return passed ? 0 : 1;
}
