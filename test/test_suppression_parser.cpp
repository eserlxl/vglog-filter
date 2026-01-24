#include "../include/parsers/suppression_parser.h"
#include "../include/filter_config.h"
#include "test_helpers.h"
#include <cassert>
#include <iostream>
#include <algorithm>

void test_parse_content() {
    std::string content = R"(
{
   <leak_suppression>
   Memcheck:Leak
   fun:malloc
   fun:my_allocator
}
{
   <ignore_cond>
   Memcheck:Cond
   fun:risky_func
   obj:/usr/lib/libc.so
}
    )";

    FilterConfig config;
    SuppressionParser::parseContent(content, config);

    assert(config.excludeTypes.size() == 2);
    // Memcheck:Leak -> Leak
    // Memcheck:Cond -> Conditional jump
    
    // Check if "Leak" is present
    bool hasLeak = false;
    for (const auto& t : config.excludeTypes) {
        if (t == "Leak") hasLeak = true;
    }
    if (!hasLeak) {
        std::cerr << "FAIL: Missing 'Leak' in excludeTypes\n";
        std::exit(1);
    }

    // Check if "Conditional jump" is present
    bool hasCond = false;
    for (const auto& t : config.excludeTypes) {
        if (t == "Conditional jump") hasCond = true;
    }
    if (!hasCond) {
        std::cerr << "FAIL: Missing 'Conditional jump' in excludeTypes\n";
        std::exit(1);
    }

    if (config.excludeFunctions.size() != 3) {
         std::cerr << "FAIL: Expected 3 functions, got " << config.excludeFunctions.size() << "\n";
         std::exit(1);
    }
    // fun:malloc, fun:my_allocator, fun:risky_func
    
    auto hasFunc = [&](const std::string& name) {
        return std::find(config.excludeFunctions.begin(), config.excludeFunctions.end(), name) != config.excludeFunctions.end();
    };
    
    if (!hasFunc("malloc")) { std::cerr << "FAIL: Missing malloc\n"; std::exit(1); }
    if (!hasFunc("my_allocator")) { std::cerr << "FAIL: Missing my_allocator\n"; std::exit(1); }
    if (!hasFunc("risky_func")) { std::cerr << "FAIL: Missing risky_func\n"; std::exit(1); }

    std::cout << "test_parse_content passed\n";
}

int main() {
    test_parse_content();
    return 0;
}
