#include "json/json_parser.h"
#include <charconv>
#include <cctype>
#include <stdexcept>
#include <iostream>

namespace json {

namespace {

class JsonParserImpl {
public:
  explicit JsonParserImpl(std::string_view in) : input(in), pos(0) {}

  std::optional<Value> parse() {
    skipWhitespace();
    if (pos >= input.size()) return std::nullopt;
    return parseValue();
  }

private:
  std::string_view input;
  size_t pos;

  void skipWhitespace() {
    while (pos < input.size() && std::isspace(static_cast<unsigned char>(input[pos]))) {
      pos++;
    }
  }

  std::optional<Value> parseValue() {
    skipWhitespace();
    if (pos >= input.size()) return std::nullopt;

    char c = input[pos];
    if (c == '{') return parseObject();
    if (c == '[') return parseArray();
    if (c == '"') return parseString();
    if (c == 't') return parseTrue();
    if (c == 'f') return parseFalse();
    if (c == 'n') return parseNull();
    if (c == '-' || std::isdigit(static_cast<unsigned char>(c))) return parseNumber();

    return std::nullopt;
  }

  std::optional<Value> parseObject() {
    Value val;
    val.type = Value::Type::Object;
    pos++; // skip '{'

    while (true) {
      skipWhitespace();
      if (pos >= input.size()) return std::nullopt;
      if (input[pos] == '}') {
        pos++;
        return val;
      }

      auto keyVal = parseString();
      if (!keyVal || keyVal->type != Value::Type::String) return std::nullopt;
      std::string key = keyVal->stringVal;

      skipWhitespace();
      if (pos >= input.size() || input[pos] != ':') return std::nullopt;
      pos++; // skip ':'

      auto memberVal = parseValue();
      if (!memberVal) return std::nullopt;

      val.objectVal[key] = std::move(*memberVal);

      skipWhitespace();
      if (pos >= input.size()) return std::nullopt;
      if (input[pos] == ',') {
        pos++;
      } else if (input[pos] == '}') {
        pos++;
        return val;
      } else {
        return std::nullopt;
      }
    }
  }

  std::optional<Value> parseArray() {
    Value val;
    val.type = Value::Type::Array;
    pos++; // skip '['

    while (true) {
      skipWhitespace();
      if (pos >= input.size()) return std::nullopt;
      if (input[pos] == ']') {
        pos++;
        return val;
      }

      auto elem = parseValue();
      if (!elem) return std::nullopt;
      val.arrayVal.push_back(std::move(*elem));

      skipWhitespace();
      if (pos >= input.size()) return std::nullopt;
      if (input[pos] == ',') {
        pos++;
      } else if (input[pos] == ']') {
        pos++;
        return val;
      } else {
        return std::nullopt;
      }
    }
  }

  std::optional<Value> parseString() {
    Value val;
    val.type = Value::Type::String;
    pos++; // skip '"'
    
    std::string out;
    while (pos < input.size()) {
      char c = input[pos];
      if (c == '"') {
        pos++;
        val.stringVal = out;
        return val;
      }
      if (c == '\\') {
        pos++;
        if (pos >= input.size()) return std::nullopt;
        char esc = input[pos];
        switch (esc) {
          case '"': out += '"'; break;
          case '\\': out += '\\'; break;
          case '/': out += '/'; break;
          case 'b': out += '\b'; break;
          case 'f': out += '\f'; break;
          case 'n': out += '\n'; break;
          case 'r': out += '\r'; break;
          case 't': out += '\t'; break;
          case 'u': 
            // Minimal unicode skip (4 chars) - not implementing full unicode for this iteration
            if (pos + 4 < input.size()) pos += 4; 
            break; 
          default: out += esc; break;
        }
      } else {
        out += c;
      }
      pos++;
    }
    return std::nullopt;
  }

  std::optional<Value> parseNumber() {
    size_t start = pos;
    if (input[pos] == '-') pos++;
    while (pos < input.size() && std::isdigit(static_cast<unsigned char>(input[pos]))) pos++;
    
    // Naive integer parse
    std::string numStr(input.substr(start, pos - start));
    long valLong = 0;
    auto res = std::from_chars(numStr.data(), numStr.data() + numStr.size(), valLong);
    if (res.ec != std::errc()) return std::nullopt;

    Value val;
    val.type = Value::Type::Number;
    val.numberVal = valLong;
    return val;
  }

  std::optional<Value> parseTrue() {
    if (input.substr(pos).starts_with("true")) {
      pos += 4;
      Value val;
      val.type = Value::Type::Boolean;
      val.boolVal = true;
      return val;
    }
    return std::nullopt;
  }

  std::optional<Value> parseFalse() {
    if (input.substr(pos).starts_with("false")) {
      pos += 5;
      Value val;
      val.type = Value::Type::Boolean;
      val.boolVal = false;
      return val;
    }
    return std::nullopt;
  }

  std::optional<Value> parseNull() {
    if (input.substr(pos).starts_with("null")) {
      pos += 4;
      Value val;
      val.type = Value::Type::Null;
      return val;
    }
    return std::nullopt;
  }
};

} // namespace

std::optional<Value> Parser::parse(std::string_view input) {
  JsonParserImpl impl(input);
  return impl.parse();
}

} // namespace json
