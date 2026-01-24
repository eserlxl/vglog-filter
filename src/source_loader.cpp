#include "source_loader.h"
#include <algorithm>
#include <fstream>
#include <map>
#include <memory>

std::vector<std::string> SourceLoader::loadContext(const std::string& path, int line,
                                                   int contextLines) {
  if (line <= 0 || contextLines <= 0)
    return {};

  // Check cache
  auto it = fileCache.find(path);
  
  const std::vector<std::string>* pLines = nullptr;
  std::unique_ptr<std::vector<std::string>> tempLines;

  if (it != fileCache.end()) {
    pLines = &it->second.lines;
  } else {
    // Not in cache, try to load
    std::ifstream file(path);
    if (!file.is_open())
      return {};

    auto loaded = std::make_unique<std::vector<std::string>>();
    std::size_t sz = 0;
    std::string content;
    while (std::getline(file, content)) {
      loaded->push_back(content);
      sz += content.size() + 1; // +1 for newline approximation
    }

    // Decide whether to cache
    evictIfNeeded(sz);

    if (sz <= MAX_CACHE_BYTES) {
      CachedFile cf;
      cf.lines = *loaded; // copy (or move if we hadn't made it unique_ptr, but copy is fine here given structure)
      // optimization: we can avoid copy if we structure differently, but std::vector move is cheap.
      // *loaded is lvalue, so it copies.
      // Better: CachedFile cf; cf.lines = std::move(*loaded);
      cf.lines = std::move(*loaded);
      cf.sizeBytes = sz;
      
      currentCacheSize += sz;
      auto res = fileCache.emplace(path, std::move(cf));
      pLines = &res.first->second.lines;
    } else {
      // Too big to cache, use temporary
      tempLines = std::move(loaded);
      pLines = tempLines.get();
    }
  }

  if (!pLines || line > static_cast<int>(pLines->size()))
    return {};

  std::vector<std::string> result;
  // 1-based indexing for 'line' argument
  int startIdx = std::max(0, line - contextLines - 1);
  int endIdx = std::min(static_cast<int>(pLines->size()) - 1, line + contextLines - 1);

  if (startIdx <= endIdx) {
    result.reserve(static_cast<std::size_t>(endIdx - startIdx + 1));
    for (int i = startIdx; i <= endIdx; ++i) {
      result.push_back((*pLines)[static_cast<std::size_t>(i)]);
    }
  }

  return result;
}

void SourceLoader::evictIfNeeded(std::size_t requiredBytes) {
  if (requiredBytes > MAX_CACHE_BYTES)
    return; // Can't fit anyway
  while (currentCacheSize + requiredBytes > MAX_CACHE_BYTES && !fileCache.empty()) {
    // Simple eviction: remove first element
    auto it = fileCache.begin();
    currentCacheSize -= it->second.sizeBytes;
    fileCache.erase(it);
  }
}
