#include "json/simple_json_builder.h"
#include "signal_handler.h"
#include "test_helpers.h"
#include <iostream>
#include <string>

// 1. Test JsonBuilder Type Safety
bool test_json_builder_safety() {
    json::Builder b;
    b.add("str", "value"); // Should pick const char* -> string_view
    b.add("bool_true", true);
    b.add("bool_false", false);
    
    std::string json = b.str();
    bool passed = true;

    if (json.find("\"str\":\"value\"") == std::string::npos) {
        std::cerr << "FAIL: String literal treated incorrectly: " << json << std::endl;
        passed = false;
    }
    if (json.find("\"bool_true\":true") == std::string::npos) {
        std::cerr << "FAIL: Bool true incorrect: " << json << std::endl;
        passed = false;
    }
    if (json.find("\"bool_false\":false") == std::string::npos) {
        std::cerr << "FAIL: Bool false incorrect: " << json << std::endl;
        passed = false;
    }

    // Verify deleted overloads via compilation? 
    // We can't easily test "this code does not compile" in this harness.
    // relying on 'Audit' and header inspection.

    if (passed) TEST_PASS("test_json_builder_safety");
    return passed;
}

// 2. Test SignalHandler Default State
bool test_signal_handler_state() {
    // Should be false by default
    if (SignalHandler::isStopRequested()) {
        std::cerr << "FAIL: SignalHandler stopped at start" << std::endl;
        return false;
    }
    
    TEST_PASS("test_signal_handler_state");
    return true;
}

int main() {
    bool passed = true;
    passed &= test_json_builder_safety();
    passed &= test_signal_handler_state();
    return passed ? 0 : 1;
}
