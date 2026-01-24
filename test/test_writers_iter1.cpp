// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "test_helpers.h"
#include "csv_log_writer.h"
#include "yaml_log_writer.h"
#include "file_utils.h"
#include "log_entry.h"
#include <cstdio>

bool test_csv_output() {
    LogEntry entry;
    entry.pid = "12345";
    entry.tid = 99;
    entry.errorType = "InvalidRead";
    entry.signature = "sig123";
    entry.stackFrames.push_back({"main", "main.cpp:55", "main", "main.cpp:55"});

    std::string path = "/tmp/test_csv.csv";
    {
        CsvLogWriter writer(path);
        writer.writeEntry(entry);
    } 

    std::string content = read_file_to_string(path);
    std::remove(path.c_str());

    TEST_ASSERT(content.find("Timestamp,PID,TID,ErrorType") != std::string::npos, "Header missing");
    TEST_ASSERT(content.find("12345,99,InvalidRead") != std::string::npos, "Content missing");
    TEST_ASSERT(content.find("main.cpp,55,main") != std::string::npos, "Stack missing");
    
    TEST_PASS("CSV Output works");
    return true;
}

bool test_yaml_output() {
    LogEntry entry;
    entry.pid = "12345";
    entry.tid = 99;
    entry.errorType = "InvalidRead";
    
    std::string path = "/tmp/test_yaml.yaml";
    {
        YamlLogWriter writer(path);
        writer.writeEntry(entry);
    }
    
    std::string content = read_file_to_string(path);
    std::remove(path.c_str());
    
    TEST_ASSERT(content.find("- type: \"InvalidRead\"") != std::string::npos, "Type missing");
    TEST_ASSERT(content.find("  pid: 12345") != std::string::npos, "PID missing");
    
    TEST_PASS("YAML Output works");
    return true;
}

bool test_gzip_output() {
    std::string path = "/tmp/test_gzip.txt.gz";
    {
        auto out = openOutputFile(path);
        *out << "Hello Gzip";
    }
    
    TEST_ASSERT(std::filesystem::exists(path), "Gzip file should exist");
    
    auto in = openInputFile(path);
    std::stringstream buffer;
    buffer << in->rdbuf();
    std::string content = buffer.str();
    
    std::remove(path.c_str());
    
    TEST_ASSERT(content == "Hello Gzip", "Gzip content mismatch");
    TEST_PASS("Gzip Output works");
    return true;
}

int main() {
    bool all = true;
    all &= test_csv_output();
    all &= test_yaml_output();
    all &= test_gzip_output();
    if (all) std::cout << "All writer tests passed\n";
    return all ? 0 : 1;
}
