#include "diff_engine.h"
#include "log_entry.h"
#include <cassert>
#include <iostream>
#include <vector>

void testDiff() {
    std::cout << "Testing DiffEngine...\n";
    
    LogEntry e1;
    e1.signature = "sig1";
    e1.errorType = "Error1";
    
    LogEntry e2;
    e2.signature = "sig2";
    e2.errorType = "Error2";
    
    LogEntry e3;
    e3.signature = "sig3";
    e3.errorType = "Error3";
    
    std::vector<LogEntry> baseline = {e1, e2};
    std::vector<LogEntry> target = {e2, e3}; // e1 fixed, e3 new
    
    auto result = DiffEngine::compare(baseline, target);
    
    assert(result.newErrors.size() == 1);
    assert(result.newErrors[0].signature == "sig3");
    
    assert(result.fixedErrors.size() == 1);
    assert(result.fixedErrors[0].signature == "sig1");
    
    assert(result.commonErrors.size() == 1);
    assert(result.commonErrors[0].signature == "sig2");
    
    std::cout << "DiffEngine Test Passed\n";
}

int main() {
    try {
        testDiff();
    } catch (const std::exception& e) {
        std::cerr << "Test Failed: " << e.what() << "\n";
        return 1;
    }
    return 0;
}
