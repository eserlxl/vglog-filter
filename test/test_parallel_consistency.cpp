#include "log_processor.h"
#include "options.h"
#include "log_writer.h"
#include "test_helpers.h"
#include <iostream>
#include <sstream>
#include <vector>
#include <algorithm>

// Define a simple in-memory writer for capturing output
class CapturingWriter : public ILogWriter {
public:
    void writeEntry(const LogEntry& entry) override {
        std::lock_guard<std::mutex> lock(mutex);
        entries.push_back(entry);
    }
    void writeStatsJson(const LogStats&, const std::string&) const override {}
    void writeRaw(const std::string&) override {}
    void writeStats(const LogStats&) override {}
    void setUseColor(bool) override {}
    void flush() override {}

    
    std::vector<LogEntry> entries;
    mutable std::mutex mutex;
};

std::string generate_dummy_log(int blocks) {
    std::stringstream ss;
    for (int i = 0; i < blocks; ++i) {
        ss << "==100" << i << "== Invalid read of size 4\n";
        ss << "==100" << i << "==    at 0x400: func" << i << " (file.c:1)\n";
        ss << "==100" << i << "==    by 0x500: main (main.c:1)\n";
        ss << "==100" << i << "==  Address 0x123 is 0 bytes inside a block of size 4 alloc'd\n";
        ss << "==100" << i << "==    at 0x600: malloc (vg_replace_malloc.c:2)\n";
        ss << "\n";
    }
    return ss.str();
}

bool test_parallel_consistency() {
    std::string input = generate_dummy_log(100);
    
    // Serial Run
    Options optSerial;
    optSerial.jobs = 1;
    optSerial.sanitizerType = SanitizerType::Valgrind;
    optSerial.streamMode = false; // Parallel logic enabled for non-stream currently
    
    auto writerSerial = std::make_unique<CapturingWriter>();
    auto* wsPtr = writerSerial.get();
    LogProcessor serialProcessor(optSerial, std::move(writerSerial));
    
    std::stringstream ssSerial(input);
    serialProcessor.processStream(ssSerial);
    
    // Parallel Run
    Options optParallel;
    optParallel.jobs = 4;
    optParallel.sanitizerType = SanitizerType::Valgrind;
    optParallel.streamMode = false;
    
    auto writerParallel = std::make_unique<CapturingWriter>();
    auto* wpPtr = writerParallel.get();
    LogProcessor parallelProcessor(optParallel, std::move(writerParallel));
    
    std::stringstream ssParallel(input);
    parallelProcessor.processStream(ssParallel);
    
    // Comparison
    TEST_ASSERT(wsPtr->entries.size() == 100, "Serial found 100 blocks");
    TEST_ASSERT(wpPtr->entries.size() == 100, "Parallel found 100 blocks");
    
    // Since parallel processing might reorder output in the writer (unless we implemented reordering),
    // we need to sort to compare content?
    // My implementation of resultQueue processing loops and writes.
    // If multiple threads push to queue, the order in queue is non-deterministic.
    // So output order IS non-deterministic currently.
    
    // Let's sort by PID to compare content equality
    auto sorter = [](const LogEntry& a, const LogEntry& b) {
        return a.pid < b.pid;
    };
    
    std::sort(wsPtr->entries.begin(), wsPtr->entries.end(), sorter);
    std::sort(wpPtr->entries.begin(), wpPtr->entries.end(), sorter);
    
    for (size_t i = 0; i < 100; ++i) {
        if (wsPtr->entries[i].pid != wpPtr->entries[i].pid) {
            std::cerr << "Mismatch at index " << i << ": " 
                      << wsPtr->entries[i].pid << " != " << wpPtr->entries[i].pid << "\n";
            return false;
        }
    }
    
    TEST_PASS("Parallel Consistency (100 blocks)");
    return true;
}

int main() {
    if (test_parallel_consistency()) {
        std::cout << "All Parallel Consistency Tests Passed" << std::endl;
        return 0;
    }
    return 1;
}
