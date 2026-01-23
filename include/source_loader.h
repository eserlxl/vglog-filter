#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

class SourceLoader {
public:
  // Load context lines around a specific line in a file.
  // Returns empty vector if file cannot be read or line is invalid.
  // Load context lines around a specific line in a file.
  // Returns empty vector if file cannot be read or line is invalid.
  // Caches file content for subsequent accesses.
  std::vector<std::string> loadContext(const std::string& path, int line, int contextLines);

private:
  struct CachedFile {
    std::vector<std::string> lines;
    // timestamp? size? For now simple cache.
  };
  std::map<std::string, CachedFile> fileCache;
};
