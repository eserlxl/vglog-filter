#include "source_loader.h"
#include <algorithm>
#include <fstream>
#include <map>

std::vector<std::string> SourceLoader::loadContext(const std::string& path, int line,
                                                   int contextLines) {
  if (line <= 0 || contextLines <= 0)
    return {};

  // Check cache
  auto it = fileCache.find(path);
  if (it == fileCache.end()) {
    std::ifstream file(path);
    if (!file.is_open())
      return {};

    CachedFile cached;
    std::string content;
    while (std::getline(file, content)) {
      cached.lines.push_back(content);
    }
    // Limit cache size? For now, unlimited (iteration 2 requirement is just basic cache).
    it = fileCache.emplace(path, std::move(cached)).first;
  }

  const auto& lines = it->second.lines;
  if (line > static_cast<int>(lines.size()))
    return {};

  std::vector<std::string> result;
  // 1-based indexing for 'line' argument
  int startIdx = std::max(0, line - contextLines - 1);
  int endIdx = std::min(static_cast<int>(lines.size()) - 1, line + contextLines - 1);

  if (startIdx <= endIdx) {
    for (int i = startIdx; i <= endIdx; ++i) {
      result.push_back(lines[i]);
    }
  }

  return result;
}
