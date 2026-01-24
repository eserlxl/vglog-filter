#include "../include/log_writer.h"
#include "../include/options.h"
#include "../include/log_entry.h"
#include "test_helpers.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

// Verify JSON array output
void test_json_array_empty() {
    std::string path = "test_array_empty.json";
    Options opt;
    opt.jsonOutput = true;
    opt.jsonArray = true;
    opt.outputFile = path;
    
    {
        LogWriter writer(opt);
        // No entries
    }
    
    std::string content = read_file_to_string(path);
    assert(content == "[]"); // Should be empty array
    
    std::filesystem::remove(path);
    std::cout << "test_json_array_empty passed\n";
}

void test_json_array_content() {
    std::string path = "test_array_content.json";
    Options opt;
    opt.jsonOutput = true;
    opt.jsonArray = true;
    opt.outputFile = path;
    
    {
        LogWriter writer(opt);
        LogEntry e1;
        e1.rawContent = "Entry1";
        e1.signature = "sig1";
        writer.writeEntry(e1);
        
        LogEntry e2;
        e2.rawContent = "Entry2";
        e2.signature = "sig2";
        writer.writeEntry(e2);
    }
    
    std::string content = read_file_to_string(path);
    
    // Check format: [ {...}, {...} ]
    assert(content.starts_with("["));
    assert(content.ends_with("]"));
    assert(content.find("\"raw\":\"Entry1\"") != std::string::npos);
    assert(content.find("\"raw\":\"Entry2\"") != std::string::npos);
    // Check for comma
    assert(content.find("},{") != std::string::npos || content.find("}, {") != std::string::npos);
    
    std::filesystem::remove(path);
    std::cout << "test_json_array_content passed\n";
}

int main() {
    test_json_array_empty();
    test_json_array_content();
    return 0;
}
