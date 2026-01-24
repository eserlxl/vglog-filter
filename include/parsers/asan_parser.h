#pragma once

#include "parsers/i_parser.h"

namespace parsers {

class AsanParser : public IParser {
public:
  ~AsanParser() override = default;

  [[nodiscard]] bool isBlockStart(std::string_view line) const override;
  [[nodiscard]] bool isRelevant(std::string_view line) const override;
  [[nodiscard]] LogEntry parseBlock(std::string_view rawBlock) const override;
  [[nodiscard]] std::string scrubLine(const std::string& line) const override;
  [[nodiscard]] std::string cleanRaw(const std::string& line) const override;
  [[nodiscard]] std::optional<int32_t> extractPid(std::string_view line) const override;
  [[nodiscard]] std::string_view name() const override { return "AddressSanitizer"; }


private:
  struct ParsedHeader {
    int32_t pid;
    // The previous edit for AsanParser.cpp used stoi.
    // So this internal struct should probably be int? Or string and convert?
    // Let's use int32_t to be safe/consistent.
    std::string errorType;
  };
  [[nodiscard]] std::optional<ParsedHeader> parseHeader(std::string_view line) const;
};

} // namespace parsers
