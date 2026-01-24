#pragma once

#include "parsers/i_parser.h"
#include <vector>
#include <regex>

namespace parsers {

class ValgrindParser : public IParser {
public:
  ValgrindParser();
  ~ValgrindParser() override = default;

  [[nodiscard]] bool isBlockStart(std::string_view line) const override;
  [[nodiscard]] bool isRelevant(std::string_view line) const override;
  [[nodiscard]] LogEntry parseBlock(std::string_view rawBlock) const override;
  [[nodiscard]] std::string scrubLine(const std::string& line) const override;
  [[nodiscard]] std::string cleanRaw(const std::string& line) const override;
  [[nodiscard]] std::optional<int32_t> extractPid(std::string_view line) const override;
  [[nodiscard]] std::string_view name() const override { return "Valgrind"; }


private:
  [[nodiscard]] bool matchesVgLine(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesStartPattern(std::string_view line) const noexcept;
  [[nodiscard]] bool matchesBytesHead(std::string_view line) const noexcept;
  
  std::vector<std::string> startKeys;
  bool scrubRaw = true;
};

} // namespace parsers
