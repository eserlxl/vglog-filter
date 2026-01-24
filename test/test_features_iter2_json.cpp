#include "json/simple_json_builder.h"
#include <cassert>
#include <iostream>

void test_json_builder() {
    json::Builder b;
    b.add("key1", "value1");
    b.add("key2", 123);
    b.add("key3", true);
    
    // Nested object
    b.startObject("nested");
    b.add("inner", "val");
    b.endObject();
    
    // Array
    b.startArray("list");
    b.addStringToArray("a");
    b.addStringToArray("b");
    b.endArray();
    
    std::string s = b.str();
    std::cout << "JSON: " << s << "\n";
    
    // Simple validation (order based)
    // Expect: {"key1":"value1","key2":123,"key3":true,"nested":{"inner":"val"},"list":["a","b"]}
    std::string expected = "{\"key1\":\"value1\",\"key2\":123,\"key3\":true,\"nested\":{\"inner\":\"val\"},\"list\":[\"a\",\"b\"]}";
    assert(s == expected);
    
    std::cout << "test_json_builder passed\n";
}

int main() {
    test_json_builder();
    return 0;
}
