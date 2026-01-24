#include "json/simple_json_builder.h"

namespace json {

Builder::Builder() {
  buffer = "{";
  commaStack.push_back(false);
}

void Builder::ensureComma() {
  if (commaStack.back()) {
    buffer += ",";
  }
  commaStack.back() = true;
}

Builder& Builder::add(std::string_view key, std::string_view value) {
  ensureComma();
  buffer += "\"";
  buffer += key;
  buffer += "\":\"";
  buffer += json_utils::escape_string(std::string(value)); // Assuming standard escape util
  buffer += "\"";
  return *this;
}

Builder& Builder::add(std::string_view key, const char* value) {
  return add(key, std::string_view(value));
}

Builder& Builder::add(std::string_view key, int64_t value) {
  ensureComma();
  buffer += "\"";
  buffer += key;
  buffer += "\":";
  buffer += std::to_string(value);
  return *this;
}

Builder& Builder::add(std::string_view key, int value) {
  return add(key, static_cast<int64_t>(value));
}

Builder& Builder::add(std::string_view key, bool value) {
  ensureComma();
  buffer += "\"";
  buffer += key;
  buffer += "\":";
  buffer += (value ? "true" : "false");
  return *this;
}

Builder& Builder::addNull(std::string_view key) {
  ensureComma();
  buffer += "\"";
  buffer += key;
  buffer += "\":null";
  return *this;
}

Builder& Builder::startObject(std::string_view key) {
  ensureComma();
  buffer += "\"";
  buffer += key;
  buffer += "\":{";
  commaStack.push_back(false);
  return *this;
}

Builder& Builder::startObject() {
  ensureComma();
  buffer += "{";
  commaStack.push_back(false);
  return *this;
}

Builder& Builder::endObject() {
  buffer += "}";
  commaStack.pop_back();
  return *this;
}

Builder& Builder::startArray(std::string_view key) {
  ensureComma();
  buffer += "\"";
  buffer += key;
  buffer += "\":[";
  commaStack.push_back(false);
  return *this;
}

Builder& Builder::addStringToArray(std::string_view value) {
  ensureComma();
  buffer += "\"";
  buffer += json_utils::escape_string(std::string(value));
  buffer += "\"";
  return *this;
}

Builder& Builder::endArray() {
  buffer += "]";
  commaStack.pop_back();
  //// Restore parent comma state? No, commaStack tracks CURRENT level. Parent level handled by ensureComma on ENTRY.
  // When we pop, we are back to parent context. Parent context does NOT flag comma because we just finished a value (the array).
  // Wait, if we finish an array, the next add() in PARENT should add a comma.
  // My commaStack.back() refers to "nested" state. 
  // Reference logic: commaStack tracks "has elements been added to THIS scope". 
  // Correct.
  return *this;
}

std::string Builder::str() const {
  if (commaStack.size() == 1)
    return buffer + "}"; // Close root
  return buffer; // Should not happen if balanced
}

} // namespace json
