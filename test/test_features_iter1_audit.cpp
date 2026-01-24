#include "time_utils.h"
#include "test_helpers.h"
#include <cassert>
#include <iostream>

void test_timestamp_safe() {
    using namespace time_utils;
    
    // Test valid
    auto res = timestampToMsSafe("01:00:00.000");
    assert(res.has_value());
    // 1h = 3600000ms
    assert(*res == 3600000);

    // Test invalid
    auto fail = timestampToMsSafe("invalid");
    assert(!fail.has_value());

    // Test partial
    // "HH:MM:SS" -> valid
    auto res2 = timestampToMsSafe("00:00:10");
    assert(res2.has_value());
    assert(*res2 == 10000);

    // Test date prefix stripping (handled by timestampToMsSafe? No, handled by normalizeTimestamp usually)
    // timestampToMsSafe calls internal logic which splits by :.
    /*
      The logic in src/time_utils.cpp:
      timestampToMsInternal splits by ':' directly.
      "day 01:00:00" -> split "day 01", "00", "00".
      parseComponent("day 01") -> std::from_chars("day 01").
      If starts with non-digit, from_chars fails.
      So "day 01" fails.
      
      However, isAfter calls normalizeTimestamp FIRST.
      Let's test isAfter/isBefore which use safe parsing.
    */
    
    assert(isAfter("02:00:00", "01:00:00"));
    assert(!isAfter("01:00:00", "02:00:00"));
    
    // Day prefix handling
    // normalizeTimestamp("day 01:00:00") -> "01:00:00"
    // So isAfter should work
    assert(isAfter("day 02:00:00", "day 01:00:00"));
    
    std::cout << "test_timestamp_safe passed\n";
}

int main() {
    test_timestamp_safe();
    return 0;
}
