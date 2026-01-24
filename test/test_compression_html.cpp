#include "file_utils.h"
#include "html_log_writer.h"
#include "log_entry.h"
#include "log_processor.h"
#include "options.h"

#include <cassert>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <unistd.h> // for unlink

// Helper to create a gzipped file
void createGzipFile(const std::string& path, const std::string& content) {
    std::string cmd = "echo \"" + content + "\" | gzip > " + path;
    int ret = std::system(cmd.c_str());
    (void)ret;
    assert(ret == 0);
}

void testCompression() {
    std::cout << "Testing Compression...\n";
    std::string path = "test_input.log.gz";
    std::string content = "==123== Memcheck, a memory error detector\n==123== ERROR SUMMARY: 0 errors\n";
    createGzipFile(path, content);

    auto stream = openInputFile(path);
    assert(stream != nullptr);

    std::string line;
    std::getline(*stream, line);
    assert(line.find("Memcheck") != std::string::npos); // Verify content reading

    std::cout << "Compression Test Passed\n";
    unlink(path.c_str());
}

void testHtmlOutput() {
    std::cout << "Testing HTML Output...\n";
    std::string path = "test_report.html";
    
    {
        HtmlLogWriter writer(path);
        LogEntry entry;
        entry.errorType = "InvalidRead";
        entry.pid = 1234;
        entry.tid = 1; // tid is optional<int32_t>
        entry.stackTrace.push_back("at main (main.cpp:10)");
        
        writer.writeEntry(entry);
        
        LogStats stats;
        stats.linesRead = 100;
        writer.writeStats(stats);
    } // Flush via destructor

    std::ifstream ifs(path);
    assert(ifs.is_open());
    std::string content((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
    
    assert(content.find("<html>") != std::string::npos);
    assert(content.find("InvalidRead") != std::string::npos);
    assert(content.find("badge-err") != std::string::npos);

    std::cout << "HTML Output Test Passed\n";
    unlink(path.c_str());
}

int main() {
    try {
        testCompression();
        testHtmlOutput();
    } catch (const std::exception& e) {
        std::cerr << "Test Failed: " << e.what() << "\n";
        return 1;
    }
    return 0;
}
