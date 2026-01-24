#pragma once

#include "json_utils.h"
#include <string>
#include <string_view>
#include <vector>

namespace json {

class Builder {
public:
  Builder();
  
  Builder& add(std::string_view key, std::string_view value);
  Builder& add(std::string_view key, const char* value); // Fix literal -> bool
  Builder& add(std::string_view key, int64_t value);
  Builder& add(std::string_view key, int value); // Ambiguity fix
  Builder& add(std::string_view key, bool value);
  Builder& addNull(std::string_view key);
  
  Builder& startObject(std::string_view key); // Start named object
  Builder& endObject();
  
  Builder& startArray(std::string_view key);
  Builder& addStringToArray(std::string_view value); // Add to current array
  Builder& endArray();

  std::string str() const;

private:
  void ensureComma();
  
  std::string buffer;
  bool needsComma = false;
  std::vector<bool> commaStack; // Stack to track comma state for nested objects/arrays
};

} // namespace json
