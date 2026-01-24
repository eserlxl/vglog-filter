#include "parsers/asan_parser.h"
#include <charconv>
#include <sstream>

namespace parsers {

bool AsanParser::isBlockStart(std::string_view line) const {
  if (line.starts_with("=================")) return true;
  if (line.find("ERROR: AddressSanitizer:") != std::string_view::npos) return true;
  return false;
}

bool AsanParser::isRelevant(std::string_view line) const {
  if (isBlockStart(line)) return true;
  if (line.find("    #") != std::string_view::npos) return true;
  if (line.find("SUMMARY: AddressSanitizer:") != std::string_view::npos) return true;
  return false;
}

std::optional<AsanParser::ParsedHeader> AsanParser::parseHeader(std::string_view line) const {
  // Try finding PID enclosure
  size_t first_eq = line.find("==");
  if (first_eq == std::string_view::npos) return std::nullopt;
  
  size_t second_eq = line.find("==", first_eq + 2);
  if (second_eq == std::string_view::npos) return std::nullopt;
  
  // Check for ERROR: AddressSanitizer:
  size_t err_pos = line.find("ERROR: AddressSanitizer:", second_eq);
  if (err_pos == std::string_view::npos) return std::nullopt;
  
  ParsedHeader h;
  auto pid_str = line.substr(first_eq + 2, second_eq - (first_eq + 2));
  h.pid = std::string(pid_str);
  
  size_t type_start = err_pos + 24; // "ERROR: AddressSanitizer:".length()
  // Trim spaces
  while (type_start < line.size() && line[type_start] == ' ') type_start++;
  
  // Find next space or punctuation? Usually type ends with space "heap-buffer-overflow on..."
  size_t type_end = line.find(' ', type_start);
  if (type_end == std::string_view::npos) type_end = line.size();
  
  h.errorType = std::string(line.substr(type_start, type_end - type_start));
  return h;
}

LogEntry AsanParser::parseBlock(std::string_view rawBlock) const {
  LogEntry entry;
  entry.rawContent = rawBlock;
  
  std::istringstream iss{std::string(rawBlock)};
  std::string line_str;
  
  bool headerFound = false;
  
  while (std::getline(iss, line_str)) {
    if (line_str.empty()) continue;
    std::string_view line = line_str;
    
    if (!headerFound) {
      if (line.starts_with("====") && line.find("ERROR") == std::string_view::npos) {
          // Separator
          continue;
      }
      auto h = parseHeader(line);
      if (h) {
          entry.pid = h->pid;
          entry.errorType = h->errorType;
          headerFound = true;
      }
    }
    
    // Stack Frame parsing
    size_t hashPos = line.find("    #");
    if (hashPos != std::string_view::npos) {
       // Format: "    #0 0x123 in func path/to/file:line:col"
       // We want "func" and "path/to/file:line"
       
       LogEntry::StackFrame frame;
       size_t inPos = line.find(" in ");
       if (inPos != std::string_view::npos) {
           size_t funcStart = inPos + 4;
           size_t fileStart = line.rfind(' '); // Naive: file is last token
           if (fileStart != std::string_view::npos && fileStart > funcStart) {
               frame.function = std::string(line.substr(funcStart, fileStart - funcStart));
               frame.location = std::string(line.substr(fileStart + 1));
           } else {
               frame.function = std::string(line.substr(funcStart));
           }
           entry.stackFrames.push_back(frame);
           entry.stackTrace.push_back(line_str);
       }
    }
  }
  
  if (entry.errorType.empty()) entry.errorType = "UnknownAsanError";
  
  return entry;
}

std::string AsanParser::scrubLine(const std::string& line) const {
  // Remove addresses 0x...
  std::string out = line;
  size_t pos = 0;
  while ((pos = out.find("0x", pos)) != std::string::npos) {
      size_t end = pos + 2;
      while (end < out.size() && (std::isxdigit(out[end]))) end++;
      out.erase(pos, end - pos);
      out.insert(pos, "0xADDR");
      pos += 6;
  }
  
  // Remove line numbers from location if present?
  // Use generic canonical logic if possible or custom.
  // For signature, we care about function names.
  return out;
}

std::string AsanParser::cleanRaw(const std::string& line) const {
    // Reuse scrubLine logic for now, as ASAN raw scrubbing requirement is similar (addresses)
    return scrubLine(line);
}


std::optional<std::string> AsanParser::extractPid(std::string_view line) const {
  if (line.size() >= 4 && line[0] == '=' && line[1] == '=') {
     size_t end_pid = line.find("==", 2);
     if (end_pid != std::string_view::npos) {
        return std::string(line.substr(2, end_pid - 2));
     }
  }
  return std::nullopt;
}

} // namespace parsers

