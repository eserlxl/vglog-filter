#pragma once

#include <map>
#include <string>
#include <vector>
#include <variant>
#include <optional>

namespace json {

struct Value;

using Object = std::map<std::string, Value>;
using Array = std::vector<Value>;

struct Value {
  enum class Type { Null, Object, Array, String, Number, Boolean };
  
  Type type = Type::Null;
  
  // Use std::variant or manual storage? simpler to use rigid struct for this task
  // std::variant can be heavy to compile/debug if we don't need visitor patterns
  // Let's use specific members
  
  std::string stringVal;
  Object objectVal;
  Array arrayVal;
  long numberVal = 0;
  bool boolVal = false;
  
  bool isNull() const { return type == Type::Null; }
  bool isObject() const { return type == Type::Object; }
  bool isArray() const { return type == Type::Array; }
};

class Parser {
public:
  static std::optional<Value> parse(std::string_view input);
};

} // namespace json
