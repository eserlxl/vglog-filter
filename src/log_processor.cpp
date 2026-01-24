// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "log_processor.h"

#include "canonicalization.h"
#include "log_parser.h"
#include "log_writer.h"
#include "signal_handler.h"
#include "source_loader.h"

#include <array>
#include <cstdio>
#include <iostream>
#include <ranges>
#include <string>

using namespace canonicalization;

namespace {

// MSan-safe digit/space checks
constexpr bool is_digit(char c) noexcept {
  return std::isdigit(static_cast<unsigned char>(c)) != 0;
}

constinit inline std::size_t PROGRESS_REPORT_INTERVAL = 1024u * 1024u; // 1MB

constinit inline std::size_t MAX_LINE_LENGTH = 1024u * 1024u;      // 1MB per line
constinit inline std::size_t MAX_BLOCK_SIZE = 10u * 1024u * 1024u; // 10MB per block
constinit inline std::size_t MAX_PENDING_BLOCKS = 1000u;

constexpr size_t RESERVE_SIZE_SEEN = 256;
constexpr size_t RESERVE_SIZE_PENDING = 64;
constexpr size_t RESERVE_SIZE_SIGLINES = 64;
constexpr size_t VG_LINE_MIN_LEN = 4;
constexpr size_t MATCH_BYTES_HEAD_LEN = 10; // " bytes in "
constexpr size_t MATCH_BLOCKS_LEN = 7;      // " blocks"
constexpr size_t RESERVE_LINE_SIZE = 1024;
constexpr size_t RESERVE_KEY_SIZE = 256;
constexpr size_t NUM_START_KEYS = 10;

void validate_line_length(std::string_view line) {
  if (line.size() > MAX_LINE_LENGTH) {
    throw std::runtime_error("Line too long (max " + std::to_string(MAX_LINE_LENGTH) + " bytes)");
  }
}
void validate_block_size(std::size_t s) {
  if (s > MAX_BLOCK_SIZE) {
    throw std::runtime_error("Block too large (max " + std::to_string(MAX_BLOCK_SIZE) + " bytes)");
  }
}
void validate_pending_blocks_count(std::size_t n) {
  if (n > MAX_PENDING_BLOCKS) {
    throw std::runtime_error("Too many pending blocks (max " + std::to_string(MAX_PENDING_BLOCKS) +
                             ")");
  }
}

} // namespace

LogProcessor::LogProcessor(const Options& options, std::unique_ptr<ILogWriter> writer)
    : opt(options), filter(options.filter), stats{},
      writer(writer ? std::move(writer)
                    : std::unique_ptr<ILogWriter>(std::make_unique<LogWriter>(options))) {
  seen.reserve(RESERVE_SIZE_SEEN);
  pendingBlocks.reserve(opt.streamMode ? RESERVE_SIZE_PENDING : 0);
  sigLines.reserve(RESERVE_SIZE_SIGLINES);
  initializeStringPatterns();
  // Regex compilation moved to LogFilter
}

LogProcessor::~LogProcessor() = default;

void LogProcessor::initializeStringPatterns() {
  vgPattern = "^==[0-9]+==";
  prefixPattern = "^==[0-9]+==[ \\t\\v\\f\\r\\n]*";
  startPattern =
      "(Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ "
      "blocks|still reachable|possibly lost|definitely lost|Process terminating)";
  bytesHeadPattern = "[0-9]+ bytes in [0-9]+ blocks";
  atPattern = "at : ";
  byPattern = "by : ";
  qPattern = "\\?{3,}";
}

bool LogProcessor::matchesVgLine(std::string_view line) const noexcept {
  if (line.size() < VG_LINE_MIN_LEN)
    return false;
  if (line[0] != '=' || line[1] != '=')
    return false;
  std::size_t i = 2;
  while (i < line.size() && is_digit(line[i]))
    ++i;
  if (i < VG_LINE_MIN_LEN || i + 1 >= line.size())
    return false;
  return line[i] == '=' && line[i + 1] == '=';
}

bool LogProcessor::matchesPrefix(std::string_view line) const noexcept {
  if (!matchesVgLine(line))
    return false;
  std::size_t i = 2;
  while (i < line.size() && is_digit(line[i]))
    ++i;
  i += 2; // ==
  while (i < line.size() && std::isspace(static_cast<unsigned char>(line[i])))
    ++i;
  return true;
}

bool LogProcessor::matchesStartPattern(std::string_view line) const noexcept {
  static constexpr std::array<std::string_view, NUM_START_KEYS> keys{
      "Invalid read",     "Invalid write",      "Syscall param",   "Use of uninitialised",
      "Conditional jump", "bytes in ",          "still reachable", "possibly lost",
      "definitely lost",  "Process terminating"};
  for (auto k : keys) {
    if (line.find(k) != std::string_view::npos)
      return true;
  }
  return false;
}

bool LogProcessor::matchesBytesHead(std::string_view line) const noexcept {
  // [digits] bytes in [digits] blocks
  std::size_t pos = 0;
  while (pos < line.size() && !is_digit(line[pos]))
    ++pos;
  if (pos == line.size())
    return false;
  while (pos < line.size() && is_digit(line[pos]))
    ++pos;
  if (pos + MATCH_BYTES_HEAD_LEN >= line.size() ||
      line.substr(pos, MATCH_BYTES_HEAD_LEN) != " bytes in ")
    return false;
  pos += MATCH_BYTES_HEAD_LEN;
  if (pos >= line.size() || !is_digit(line[pos]))
    return false;
  while (pos < line.size() && is_digit(line[pos]))
    ++pos;
  if (pos + MATCH_BLOCKS_LEN > line.size())
    return false;
  return line.substr(pos, MATCH_BLOCKS_LEN) == " blocks";
}

bool LogProcessor::matchesAtPattern(std::string_view line) const noexcept {
  return line.find("at : ") != std::string_view::npos;
}
bool LogProcessor::matchesByPattern(std::string_view line) const noexcept {
  return line.find("by : ") != std::string_view::npos;
}
bool LogProcessor::matchesQPattern(std::string_view line) const noexcept {
  int run = 0;
  for (char c : line) {
    if (c == '?') {
      if (++run >= 3)
        return true;
    } else {
      run = 0;
    }
  }
  return false;
}

std::string LogProcessor::replacePatterns(const std::string& line) const {
  std::string out = line;
  { // ... (content unchanged, just method name) ...
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

void LogProcessor::processStream(std::istream& in) {
  std::size_t bytesProcessed = 0;
  std::size_t totalBytes = 0;
  if (opt.showProgress && !opt.useStdin) {
    totalBytes = getFileSizeForProgress();
  }
  std::string line;
  while (std::getline(in, line)) {
    stats.linesRead++;
    validate_line_length(line);
    bytesProcessed += line.size() + 1;
    if (shouldReportProgress(bytesProcessed, totalBytes)) {
      report_progress(bytesProcessed, totalBytes, opt.filename);
    }
    if (signal_handler::is_stop_requested()) {
      break;
    }
    if (opt.filter.maxErrors > 0 && stats.blocksFound >= opt.filter.maxErrors) {
      clearCurrentState();
      break;
    }
    processLine(line);
  }
  stats.bytesProcessed = bytesProcessed;
  if (opt.showProgress && totalBytes > 0) {
    report_progress(bytesProcessed, totalBytes, opt.filename);
  }
  flush();
  outputPendingBlocks();
}

void LogProcessor::processStreamCFile(std::FILE* fp) {
  if (fp == nullptr)
    return;
  std::size_t bytesProcessed = 0;
  std::size_t totalBytes = 0;
  if (opt.showProgress && !opt.useStdin) {
    totalBytes = getFileSizeForProgress();
  }
  // ... (content mostly same, just method calls) ...
  std::string line;
  line.reserve(RESERVE_LINE_SIZE);
  char* buf = nullptr;
  size_t buf_size = 0;
  ssize_t read = -1;
  while ((read = ::getline(&buf, &buf_size, fp)) != -1) {
    // ...
    if (read > 0 && buf[read - 1] == '\n') {
      line.assign(buf, static_cast<std::size_t>(read - 1));
      bytesProcessed += static_cast<std::size_t>(read);
    } else {
      line.assign(buf, static_cast<std::size_t>(read));
      bytesProcessed += static_cast<std::size_t>(read);
    }
    stats.linesRead++;
    validate_line_length(line);
    if (shouldReportProgress(bytesProcessed, totalBytes)) {
      report_progress(bytesProcessed, totalBytes, opt.filename);
    }
    if (signal_handler::is_stop_requested()) {
      break;
    }
    if (opt.filter.maxErrors > 0 && stats.blocksFound >= opt.filter.maxErrors) {
      clearCurrentState();
      break;
    }
    processLine(line);
  }
  if (buf)
    std::free(buf);
  stats.bytesProcessed = bytesProcessed;
  if (opt.showProgress && totalBytes > 0) {
    report_progress(bytesProcessed, totalBytes, opt.filename);
  }
  flush();
  outputPendingBlocks();
}

std::size_t LogProcessor::getFileSizeForProgress() const {
  return get_file_size_bytes(opt.filename);
}

bool LogProcessor::shouldReportProgress(std::size_t bytesProcessed, std::size_t totalBytes) const {
  return opt.showProgress && totalBytes > 0 &&
         (bytesProcessed % PROGRESS_REPORT_INTERVAL == 0 || bytesProcessed >= totalBytes);
}

void LogProcessor::outputPendingBlocks() {
  if (!opt.trim || markerFound) {
    for (const auto& b : pendingBlocks) {
      writer->writeEntry(b);
    }
  }
}

void LogProcessor::processLines(const VecS& lines) {
  std::size_t start_index = 0;
  if (opt.trim) {
    start_index = findMarker(lines);
    if (start_index == 0)
      return;
  }
  for (std::size_t i = start_index; i < lines.size(); ++i) {
    stats.linesRead++;
    validate_line_length(lines[i]);
    processLine(lines[i]);
  }
  flush();
}

void LogProcessor::processLine(std::string_view line) {
  std::cerr << "DEBUG: " << line << "\n";
  if (opt.trim && opt.streamMode) {
    for (const auto& m : opt.markers) {
      if (line.find(m) != std::string_view::npos) {
        markerFound = true;
        resetEpoch();
        return;
      }
    }
  }

  // Extract PID from line before it gets stripped
  std::string currentLinePid;
  if (line.size() >= 4 && line[0] == '=' && line[1] == '=') {
    size_t end_pid = line.find("==", 2);
    if (end_pid != std::string_view::npos) {
      currentLinePid = std::string(line.substr(2, end_pid - 2));
    }
  }

  if (!matchesVgLine(line))
    return;

  std::string processed{LogParser::removePrefix(line)};

  if (matchesStartPattern(processed)) {
    flush();
    // After flush, we are starting a new block (potentially)
    // Update pendingPid with the PID from the current line that started this new block
    if (raw.empty()) {
      pendingPid = currentLinePid;
    }

    if (matchesBytesHead(processed))
      return;
  }

  // If we are starting a new block (and didn't flush above, or flushed and empty), capture PID
  if (raw.empty() && pendingPid.empty() && !currentLinePid.empty()) {
    pendingPid = currentLinePid;
  }

  auto rawLine = processRawLine(processed);
  if (trim_view(rawLine).empty())
    return;

  raw.append(rawLine).push_back('\n');

  const auto cl = canon(processed);
  sig.append(cl).push_back('\n');
  sigLines.push_back(cl);
}

std::string LogProcessor::processRawLine(const std::string& processedLine) const {
  if (!opt.scrubRaw)
    return processedLine;
  return replacePatterns(processedLine);
}

void LogProcessor::flush() {
  std::cerr << "DEBUG: Flushing...\n";
  if (raw.empty()) {
    clearCurrentState();
    return;
  }

  validate_block_size(raw.size());
  stats.blocksFound++;

  const std::string key = generateSignatureKey();
  LogEntry entry = parseEntry(raw, key);

  if (entry.pid.empty()) {
    entry.pid = pendingPid;
  }

  if (opt.strictMode && (entry.pid.empty() || entry.errorType.empty())) {
    stats.parseErrors++;
    throw std::runtime_error("Strict mode: Failed to parse valid Valgrind entry from block");
  }

  // Filter check
  if (!filter.shouldKeep(entry)) {
    stats.filteredCount++;
    clearCurrentState();
    return;
  }

  bool isUnique = seen.insert(key).second;
  if (isUnique) {
    stats.uniqueBlocks++;
  }

  // Decide whether to count details?
  // Current logic counts details only for unique blocks.
  // We can keep it that way for stats consistency, or count all.
  // Let's count all details if we found a block, regardless of uniqueness?
  // No, let's strictly follow previous logic for stats to avoid breaking expectations,
  // ONLY change OUTPUT behavior.

  // Actually, if we output all, we should probably count all?
  // But let's stick to: Stats track "What did we find".
  // "blocksFound" is total.
  // "uniqueBlocks" is unique.
  // "errorCounts" map currently counts unique.
  // Let's keep stats logic tied to uniqueness for now (minimal change),
  // but relax the WRITER guard.

  // Wait, if I don't increment errorCounts for duplicates, the stats will only show 1.
  // If I output 10 logs, and stats say "Invalid read: 1", that's weird.
  // But changing stats behavior is a bigger audit question.
  // "blocksFound" covers total.
  // Let's stick to modifying the WRITE condition.

  if (isUnique) {
    stats.errorCounts[entry.errorType]++;
    if (!entry.pid.empty()) {
      try {
        stats.errorCountsByPid[std::stoi(entry.pid)]++;
      } catch (...) {
      }
    }
    if (entry.tid.has_value()) {
      stats.errorCountsByTid[*entry.tid]++;
    }
  }

  // Write Condition:
  // Write if it is unique OR if uniqueOutput is FALSE (meaning print duplicates)
  if (isUnique || !opt.uniqueOutput) {
    if (opt.streamMode) {
      validate_pending_blocks_count(pendingBlocks.size());
      pendingBlocks.emplace_back(std::move(entry));
    } else {
      // Context loading using instance
      if (opt.contextLines > 0 && !entry.stackFrames.empty()) {
        // ... (same logic)
        const auto& frame = entry.stackFrames[0];
        if (!frame.location.empty()) {
          auto colonPos = frame.location.find_last_of(':');
          if (colonPos != std::string::npos) {
            std::string file = frame.location.substr(0, colonPos);
            int line = 0;
            try {
              line = std::stoi(frame.location.substr(colonPos + 1));
            } catch (...) {
            }
            if (line > 0) {
              entry.sourceContext = sourceLoader.loadContext(file, line, opt.contextLines);
            }
          }
        }
      }

      std::cerr << "DEBUG: Writing entry type=" << entry.errorType << "\n";
      writer->writeEntry(entry);
    }
  }
  clearCurrentState();
}

// shouldKeepEntry removed (moved to LogFilter)

std::string LogProcessor::generateSignatureKey() const {
  if (opt.depth <= 0)
    return sig;
  std::string key;
  key.reserve(RESERVE_KEY_SIZE);
  for (const auto& line : sigLines | std::views::take(static_cast<std::size_t>(opt.depth))) {
    key.append(line).push_back('\n');
  }
  return key;
}

void LogProcessor::clearCurrentState() noexcept {
  raw.clear();
  sig.clear();
  sigLines.clear();
  pendingPid.clear();
}

void LogProcessor::resetEpoch() noexcept {
  pendingBlocks.clear();
  seen.clear();
  clearCurrentState();
}

std::size_t LogProcessor::findMarker(const VecS& lines) const {
  for (std::size_t i = lines.size(); i-- > 0;) {
    for (const auto& m : opt.markers) {
      if (lines[i].find(m) != std::string::npos) {
        return i + 1;
      }
    }
  }
  return 0;
}

LogEntry LogProcessor::parseEntry(const std::string& rawBlock, const std::string& signature) const {
  LogEntry entry;
  entry.rawContent = rawBlock;
  entry.signature = signature;

  std::string_view sv = rawBlock;
  // Parse first line for PID and Error Type
  size_t first_eol = sv.find('\n');
  if (first_eol == std::string_view::npos)
    first_eol = sv.size();
  std::string_view first_line = sv.substr(0, first_eol);

  auto header = LogParser::parseHeader(first_line);
  if (header) {
    entry.pid = std::move(header->pid);
    entry.errorType = std::move(header->errorType);
    entry.tid = header->tid;
    entry.timestamp = std::move(header->timestamp);
  } else {
    // Fallback
    entry.errorType = LogParser::removePrefix(first_line);
  }
  // Trim EOL from type
  while (!entry.errorType.empty() &&
         (entry.errorType.back() == '\r' || entry.errorType.back() == '\n')) {
    entry.errorType.pop_back();
  }

  // Populate stack trace from subsequent lines
  size_t pos = first_eol + 1;
  while (pos < sv.size()) {
    size_t eol = sv.find('\n', pos);
    if (eol == std::string_view::npos)
      eol = sv.size();
    std::string_view line = sv.substr(pos, eol - pos);

    // Use LogParser to clean line
    auto content = LogParser::removePrefix(line);
    std::string s_content{content};

    if (!s_content.empty()) {
      // Trim newlines
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
    }
    pos = eol + 1;
  }

  return entry;
}

#include "stats_printer.h"

void LogProcessor::printStats(std::FILE* out) const {
  if (!out)
    return;
  StatsPrinter::Format fmt = (opt.statsFormat == Options::StatsFormat::json) 
                             ? StatsPrinter::Format::Json 
                             : StatsPrinter::Format::Text;
  StatsPrinter::print(stats, out, fmt);
}

void LogProcessor::saveStatsJson() const {
  if (!opt.statsFile.empty()) {
    writer->writeStatsJson(stats, opt.statsFile);
  }
}
