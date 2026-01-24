#include "parsers/valgrind_parser.h"
#include "log_parser.h"
#include "canonicalization.h"

#include <algorithm>
#include <array>
#include <cctype>

namespace parsers {

namespace {
constexpr bool isDigit(char c) noexcept {
  return std::isdigit(static_cast<unsigned char>(c)) != 0;
}
constexpr size_t VG_LINE_MIN_LEN = 4;
constexpr size_t MATCH_BYTES_HEAD_LEN = 10;
constexpr size_t MATCH_BLOCKS_LEN = 7;
} // namespace

ValgrindParser::ValgrindParser() {
  startKeys = {
      "Invalid read",     "Invalid write",      "Syscall param",   "Use of uninitialised",
      "Conditional jump", "bytes in ",          "still reachable", "possibly lost",
      "definitely lost",  "Process terminating"};
}

bool ValgrindParser::matchesVgLine(std::string_view line) const noexcept {
  if (line.size() < VG_LINE_MIN_LEN)
    return false;
  if (line[0] != '=' || line[1] != '=')
    return false;
  std::size_t i = 2;
  while (i < line.size() && isDigit(line[i]))
    ++i;
  if (i < VG_LINE_MIN_LEN || i + 1 >= line.size())
    return false;
  return line[i] == '=' && line[i + 1] == '=';
}

bool ValgrindParser::matchesStartPattern(std::string_view line) const noexcept {
  for (const auto& k : startKeys) {
    if (line.find(k) != std::string_view::npos)
      return true;
  }
  return false;
}

bool ValgrindParser::matchesBytesHead(std::string_view line) const noexcept {
   // [digits] bytes in [digits] blocks
  std::size_t pos = 0;
  while (pos < line.size() && !isDigit(line[pos]))
    ++pos;
  if (pos == line.size())
    return false;
  while (pos < line.size() && isDigit(line[pos]))
    ++pos;
  
  if (pos + MATCH_BYTES_HEAD_LEN >= line.size() ||
      line.substr(pos, MATCH_BYTES_HEAD_LEN) != " bytes in ")
    return false;
    
  pos += MATCH_BYTES_HEAD_LEN;
  if (pos >= line.size() || !isDigit(line[pos]))
    return false;
    
  while (pos < line.size() && isDigit(line[pos]))
    ++pos;
    
  if (pos + MATCH_BLOCKS_LEN > line.size())
    return false;
    
  return line.substr(pos, MATCH_BLOCKS_LEN) == " blocks";
}

bool ValgrindParser::isBlockStart(std::string_view line) const {
  if (!matchesVgLine(line)) return false;
  auto processed = LogParser::removePrefix(line);
  if (matchesStartPattern(processed)) {
    // "bytes in" usually continues a leak summary unless it's the start
    // Logic from LogProcessor: if matchesStartPattern && matchesBytesHead -> return true/false?
    // LogProcessor: if matchesStartPattern { flush(); if matchesBytesHead return; }
    // This implies "matchesBytesHead" lines are NOT starts of new blocks if they appear alone?
    // Actually, "bytes in" IS in startKeys.
    // The previous logic was: if it is "bytes in ... blocks", it might be a header.
    // But Wait: "matchesBytesHead" checking was to avoid flushing if it was just a continuation?
    // LogProcessor logic: 
    //   if (matchesStartPattern) { flush(); ... if (matchesBytesHead) return; }
    // This means it FLUSHED (started new block).
    // The return was to avoid adding to *current* block? No, `processLine` continues.
    // Actually, `matchesBytesHead` check being true returned from `processLine` EARLY!
    // So it was ignored/skipped?
    // Ah, "bytes in" lines in Leak Summary are technically headers, but often ignored or treated specially.
    // For `isBlockStart`, we should return true if it triggers a flush.
    // The previous logic flushes on ANY start key.
    return true; 
  }
  return false;
}

bool ValgrindParser::isRelevant(std::string_view line) const {
  if (!matchesVgLine(line)) return false;
  // Also check if we should skip "bytes in" lines if they are not useful?
  // Previous logic: if matchesBytesHead(processed), return (skip).
  auto processed = LogParser::removePrefix(line);
  if (matchesStartPattern(processed)) {
      if (matchesBytesHead(processed)) return false;
  }
  return true;
}

LogEntry ValgrindParser::parseBlock(std::string_view rawBlock) const {
  LogEntry entry;
  entry.rawContent = rawBlock;

  std::string_view sv = rawBlock;
  if (sv.empty()) return entry;

  size_t first_eol = sv.find('\n');
  if (first_eol == std::string_view::npos) first_eol = sv.size();
  std::string_view first_line = sv.substr(0, first_eol);

  auto header = LogParser::parseHeader(first_line);
  if (header) {
    entry.pid = header->pid;
    entry.errorType = std::move(header->errorType);
    entry.tid = header->tid;
    entry.timestamp = std::move(header->timestamp);
  } else {
    entry.errorType = LogParser::removePrefix(first_line);
  }
  
  // Clean error type
  while (!entry.errorType.empty() && 
        (entry.errorType.back() == '\r' || entry.errorType.back() == '\n')) {
    entry.errorType.pop_back();
  }

  // Stack frames
  size_t pos = first_eol + 1;
  while (pos < sv.size()) {
    size_t eol = sv.find('\n', pos);
    if (eol == std::string_view::npos) eol = sv.size();
    
    std::string_view line = sv.substr(pos, eol - pos);
    auto content = LogParser::removePrefix(line);
    std::string s_content{content};

    // Trim content
    while (!s_content.empty() && (s_content.back() == '\n' || s_content.back() == '\r')) {
       s_content.pop_back();
    }

    if (!s_content.empty()) {
       auto structured = LogParser::parseFrameStructured(s_content);
       if (structured) {
         entry.stackFrames.push_back(std::move(*structured));
       }
       entry.stackTrace.push_back(std::move(s_content));
    }
    pos = eol + 1;
  }
  
  return entry;
}

std::string ValgrindParser::scrubLine(const std::string& line) const {
  // Use canonicalization::canon helper? 
  // LogProcessor used `canon(processed)` which does aggressive normalization.
  // It also used `replacePatterns` for raw scrubbing.
  // `scrubLine` is intended for signature generation?
  // The IParser interface said "Cleans a line for signature generation".
  // So yes, `canon`.
  // Wait, `LogProcessor` logic:
  //   auto rawLine = processRawLine(processed); (Scrub params like 0x...)
  //   raw.append(rawLine)
  //   sig.append(canon(processed))
  
  // So `scrubLine` should correspond to `canon`.
  // But wait, `LogProcessor` separated `raw` accumulation and `sig` accumulation.
  // `parseBlock` takes `rawBlock`.
  // `LogProcessor` generates signature from `sigLines` which are `canon(processed)`.
  // Does `parseBlock` need to generate signature? 
  // `LogEntry` has `signature` field.
  // `LogProcessor` passed signature TO `parseEntry`.
  
  // I should probably move signature generation INTO `parseBlock`?
  // Or expose `scrubLine` so `LogProcessor` can build the signature.
  // The interface has `scrubLine`.
  
  return canonicalization::canon(LogParser::removePrefix(line));
}

std::string ValgrindParser::cleanRaw(const std::string& line) const {
  if (!scrubRaw) return line;
  std::string out = line;
  {
    std::size_t pos = 0;
    while ((pos = out.find("0x", pos)) != std::string::npos) {
      std::size_t j = pos + 2;
      while (j < out.size() && std::isxdigit(static_cast<unsigned char>(out[j])))
        ++j;
      if (j > pos + 2)
        out.erase(pos, j - pos);
      else
        ++pos;
    }
  }
  for (auto token : {std::string_view{"at : "}, std::string_view{"by : "}}) {
    std::size_t pos = 0;
    while ((pos = out.find(token, pos)) != std::string::npos) {
      out.erase(pos, token.size());
    }
  }
  {
    std::size_t i = 0;
    while (i < out.size()) {
      if (out[i] == '?') {
        std::size_t j = i;
        while (j < out.size() && out[j] == '?')
          ++j;
        if (j - i >= 3)
          out.erase(i, j - i);
        else
          i = j;
      } else {
        ++i;
      }
    }
  }
  return out;
}


std::optional<int32_t> ValgrindParser::extractPid(std::string_view line) const {
  if (line.size() >= 4 && line[0] == '=' && line[1] == '=') {
    size_t end_pid = line.find("==", 2);
    if (end_pid != std::string_view::npos) {
      try {
          // PID string is between 2 and end_pid
          std::string pidStr(line.substr(2, end_pid - 2));
          return std::stoi(pidStr);
      } catch (...) {
          return std::nullopt;
      }
    }
  }
  return std::nullopt;
}

} // namespace parsers

