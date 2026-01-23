#include "source_loader.h"
#include <algorithm>
#include <fstream>

std::vector<std::string> SourceLoader::loadContext(const std::string& path, int line,
                                                   int contextLines) {
  if (line <= 0 || contextLines <= 0)
    return {};

  std::ifstream file(path);
  if (!file.is_open())
    return {};

  std::vector<std::string> result;
  int currentLine = 1;
  std::string content;

  int startLine = std::max(1, line - contextLines);
  int endLine = line + contextLines;

  while (std::getline(file, content)) {
    if (currentLine >= startLine && currentLine <= endLine) {
      result.push_back(content);
    }
    if (currentLine > endLine)
      break;
    currentLine++;
  }

  return result;
}
