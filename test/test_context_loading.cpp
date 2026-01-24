#include "../include/log_processor.h"
#include "../include/options.h"
#include "../include/log_writer.h"
#include "test_helpers.h"
#include <cassert>
#include <sstream>
#include <iostream>
#include <fstream>
#include <filesystem>

// Mock Writer to capture output
class CapturingWriter : public ILogWriter {
public:
    std::vector<LogEntry> entries;
    void writeEntry(const LogEntry& entry) override {
        entries.push_back(entry);
    }
    void writeStats(const LogStats&) override {}
    void writeStatsJson(const LogStats&, const std::string&) const override {}
    void writeRaw(const std::string&) override {}
    void setUseColor(bool) override {}
    void flush() override {}
    void writeDiffSummary(const DiffEngine::DiffStats&) override {}
};

void test_context_loading() {
    // Create a dummy source file
    std::string srcFile = "dummy_source.c";
    std::ofstream ofs(srcFile);
    ofs << "int main() {\n";
    ofs << "  int* p = 0;\n";
    ofs << "  return *p;\n"; // Line 3
    ofs << "}\n";
    ofs.close();

    std::string absPath = std::filesystem::absolute(srcFile).string();

    Options opt;
    opt.contextLines = 1;
    opt.jobs = 2; // Force parallel
    // Need sanitized parser or auto
    opt.sanitizerType = SanitizerType::Valgrind;

    auto writer = std::make_unique<CapturingWriter>();
    auto* wPtr = writer.get();
    LogProcessor processor(opt, std::move(writer));

    std::stringstream input;
    input << "==123== Invalid read of size 4\n";
    // Using absolute path to ensuring match
    input << "==123==    at 0x400: main (" << absPath << ":3)\n"; 
    input << "==123==\n";

    processor.processStream(input);

    assert(wPtr->entries.size() == 1);
    const auto& entry = wPtr->entries[0];
    
    // Check context
    bool contextFound = false;
    for (const auto& line : entry.sourceContext) {
        if (line.find("return *p;") != std::string::npos) {
            contextFound = true;
        }
    }
    
    if (!contextFound) {
        std::cerr << "FAIL: Context not found in output\n";
        for (const auto& line : entry.sourceContext) std::cerr << "CTX: " << line << "\n";
        std::exit(1);
    }

    std::filesystem::remove(srcFile);
    std::cout << "test_context_loading passed\n";
}

int main() {
    test_context_loading();
    return 0;
}
