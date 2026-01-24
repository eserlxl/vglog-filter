// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "source_loader.h"
#include <fstream>
#include <iostream>
#include <string>
#include <filesystem>

// Access private members for testing (legal hack for white-box testing if not friend)
// Actually we can infer from behavior: load 2 large files that sum > limit.
// Then delete one file from disk. If cached, it loads. If evicted/not cached, it fails to load.

bool test_cache_limit() {
    SourceLoader loader;
    std::string f1 = "large_1.txt";
    std::string f2 = "large_2.txt";
    
    // Create 30MB files (Limit is 50MB)
    std::string junk(1024 * 1024, 'x'); // 1MB line
    {
        std::ofstream ofs(f1);
        for(int i=0; i<30; ++i) ofs << junk << "\n";
    }
    {
        std::ofstream ofs(f2);
        for(int i=0; i<30; ++i) ofs << junk << "\n";
    }
    
    // Load f1. 30MB cached.
    auto ctx1 = loader.loadContext(f1, 1, 1);
    if (ctx1.empty()) {
        std::cerr << "FAIL: Failed to load f1\n";
        return false;
    }
    
    // Load f2. 30MB. Total 60MB > 50MB. f1 should be evicted (or f2 not cached).
    auto ctx2 = loader.loadContext(f2, 1, 1);
    if (ctx2.empty()) {
        std::cerr << "FAIL: Failed to load f2\n";
        return false;
    }
    
    // Delete f1 from disk.
    std::filesystem::remove(f1);
    
    // Try request f1 again.
    // If it was evicted, this should fail (empty).
    // If it was kept (and f2 not cached?), it succeeds.
    // Our logic evicts if current + required > MAX.
    // current(30) + required(30) = 60 > 50. Evict until clean.
    // So f1 should be gone.
    
    auto ctx1_again = loader.loadContext(f1, 1, 1);
    if (!ctx1_again.empty()) {
        // It MIGHT be that f2 wasn't cached instead?
        // Logic:
        // while (current + req > MAX) evict();
        // 30 + 30 > 50 -> evict f1. current=0.
        // cache f2.
        // So f1 should be gone.
        std::cerr << "FAIL: f1 should have been evicted and deleted from disk, but loadContext succeeded.\n"; 
        return false;
    }
    
    // Clean up
    std::filesystem::remove(f2);
    
    std::cout << "PASS: SourceLoader Cache Limit\n";
    return true;
}

int main() {
    return test_cache_limit() ? 0 : 1;
}
