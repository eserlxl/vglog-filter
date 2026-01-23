#pragma once

#include <optional>
#include <string>
#include <vector>

class SourceLoader {
public:
  // Load context lines around a specific line in a file.
  // Returns empty vector if file cannot be read or line is invalid.
  static std::vector<std::string> loadContext(const std::string& path, int line, int contextLines);
};
