#include "json/json_parser.h"
#include "test_helpers.h"
#include <iostream>
#include <string>

using namespace json;

bool test_parser_basic() {
  std::string json = R"({"key": "value", "num": 123, "bool": true, "null": null})";
  auto val = Parser::parse(json);
  
  TEST_ASSERT(val.has_value(), "Should parse valid json");
  TEST_ASSERT(val->isObject(), "Root is object");
  
  const auto& obj = val->objectVal;
  TEST_ASSERT(obj.count("key"), "Has key");
  TEST_ASSERT(obj.at("key").stringVal == "value", "String value");
  
  TEST_ASSERT(obj.at("num").type == Value::Type::Number, "Number type");
  TEST_ASSERT(obj.at("num").numberVal == 123, "Number value");
  
  TEST_ASSERT(obj.at("bool").type == Value::Type::Boolean, "Boolean type");
  TEST_ASSERT(obj.at("bool").boolVal == true, "Boolean value");
  
  TEST_ASSERT(obj.at("null").type == Value::Type::Null, "Null type");
  
  TEST_PASS("Basic JSON parsing");
  return true;
}

bool test_parser_nested() {
  std::string json = R"({
      "nested": {
          "deep": [1, 2, "three"]
      }
  })";
  auto val = Parser::parse(json);
  TEST_ASSERT(val.has_value(), "Should parse nested");
  
  const auto& obj = val->objectVal;
  TEST_ASSERT(obj.count("nested"), "Has nested");
  const auto& nested = obj.at("nested").objectVal;
  TEST_ASSERT(nested.count("deep"), "Has deep");
  const auto& arr = nested.at("deep").arrayVal;
  TEST_ASSERT(arr.size() == 3, "Array size 3");
  TEST_ASSERT(arr[0].numberVal == 1, "Elem 1");
  TEST_ASSERT(arr[1].numberVal == 2, "Elem 2");
  TEST_ASSERT(arr[2].stringVal == "three", "Elem 3");
  
  TEST_PASS("Nested JSON parsing");
  return true;
}

bool test_parser_escapes() {
  std::string json = R"({"str": "line1\nline2\"quoted\""})";
  auto val = Parser::parse(json);
  TEST_ASSERT(val.has_value(), "Should parse escapes");
  
  std::string expected = "line1\nline2\"quoted\"";
  TEST_ASSERT(val->objectVal.at("str").stringVal == expected, "Escapes decoded");
  
  TEST_PASS("Escape sequences");
  return true;
}

int main() {
  bool all = true;
  all &= test_parser_basic();
  all &= test_parser_nested();
  all &= test_parser_escapes();
  
  if (all) {
      std::cout << "All JSON Parser Tests Passed" << std::endl;
      return 0;
  }
  return 1;
}
