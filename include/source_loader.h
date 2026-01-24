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
    std::size_t sizeBytes = 0;
  };
  std::map<std::string, CachedFile> fileCache;
  std::size_t currentCacheSize = 0;
  // 50 MB limit
  static constexpr std::size_t MAX_CACHE_BYTES = 50 * 1024 * 1024;

  void evictIfNeeded(std::size_t requiredBytes);
};
