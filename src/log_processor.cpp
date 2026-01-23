// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "log_processor.h"

#include "canonicalization.h"
#include "log_parser.h"

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

LogProcessor::LogProcessor(const Options& options) : opt(options), stats{} {
  seen.reserve(RESERVE_SIZE_SEEN);
  pending_blocks.reserve(opt.streamMode ? RESERVE_SIZE_PENDING : 0);
  sigLines.reserve(RESERVE_SIZE_SIGLINES);
  initialize_string_patterns();

  writer = std::make_unique<LogWriter>(opt);

  // Pre-compile regexes
  try {
    for (const auto& pat : opt.excludeStackPatterns) {
      stack_regexes.emplace_back(pat, std::regex::optimize);
    }
  } catch (const std::regex_error& e) {
    throw std::runtime_error("Invalid regex in exclude-stack: " + std::string(e.what()));
  }
}

LogProcessor::~LogProcessor() = default;

void LogProcessor::initialize_string_patterns() {
  vg_pattern = "^==[0-9]+==";
  prefix_pattern = "^==[0-9]+==[ \\t\\v\\f\\r\\n]*";
  start_pattern =
      "(Invalid (read|write)|Syscall param|Use of uninitialised|Conditional jump|bytes in [0-9]+ "
      "blocks|still reachable|possibly lost|definitely lost|Process terminating)";
  bytes_head_pattern = "[0-9]+ bytes in [0-9]+ blocks";
  at_pattern = "at : ";
  by_pattern = "by : ";
  q_pattern = "\\?{3,}";
}

bool LogProcessor::matches_vg_line(std::string_view line) const noexcept {
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

bool LogProcessor::matches_prefix(std::string_view line) const noexcept {
  if (!matches_vg_line(line))
    return false;
  std::size_t i = 2;
  while (i < line.size() && is_digit(line[i]))
    ++i;
  i += 2; // ==
  while (i < line.size() && std::isspace(static_cast<unsigned char>(line[i])))
    ++i;
  return true;
}

bool LogProcessor::matches_start_pattern(std::string_view line) const noexcept {
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

bool LogProcessor::matches_bytes_head(std::string_view line) const noexcept {
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

bool LogProcessor::matches_at_pattern(std::string_view line) const noexcept {
  return line.find("at : ") != std::string_view::npos;
}
bool LogProcessor::matches_by_pattern(std::string_view line) const noexcept {
  return line.find("by : ") != std::string_view::npos;
}
bool LogProcessor::matches_q_pattern(std::string_view line) const noexcept {
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

std::string LogProcessor::replace_patterns(const std::string& line) const {
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

void LogProcessor::processStream(std::istream& in) {
  std::size_t bytesProcessed = 0;
  std::size_t total_bytes = 0;
  if (opt.showProgress && !opt.use_stdin) {
    total_bytes = get_file_size_for_progress();
  }
  std::string line;
  while (std::getline(in, line)) {
    stats.linesRead++;
    validate_line_length(line);
    bytesProcessed += line.size() + 1;
    if (should_report_progress(bytesProcessed, total_bytes)) {
      report_progress(bytesProcessed, total_bytes, opt.filename);
    }
    if (opt.maxErrors > 0 && stats.blocksFound >= opt.maxErrors) {
      clear_current_state();
      break;
    }
    process_line(line);
  }
  stats.bytesProcessed = bytesProcessed;
  if (opt.showProgress && total_bytes > 0) {
    report_progress(bytesProcessed, total_bytes, opt.filename);
  }
  flush();
  output_pending_blocks();
}

void LogProcessor::processStreamCFile(std::FILE* fp) {
  if (fp == nullptr)
    return;
  std::size_t bytesProcessed = 0;
  std::size_t total_bytes = 0;
  if (opt.showProgress && !opt.use_stdin) {
    total_bytes = get_file_size_for_progress();
  }
  std::string line;
  line.reserve(RESERVE_LINE_SIZE);
  char* buf = nullptr;
  size_t buf_size = 0;
  ssize_t read = -1;
  while ((read = ::getline(&buf, &buf_size, fp)) != -1) {
    if (read > 0 && buf[read - 1] == '\n') {
      line.assign(buf, static_cast<std::size_t>(read - 1));
      bytesProcessed += static_cast<std::size_t>(read);
    } else {
      line.assign(buf, static_cast<std::size_t>(read));
      bytesProcessed += static_cast<std::size_t>(read);
    }
    stats.linesRead++;
    validate_line_length(line);
    if (should_report_progress(bytesProcessed, total_bytes)) {
      report_progress(bytesProcessed, total_bytes, opt.filename);
    }
    if (opt.maxErrors > 0 && stats.blocksFound >= opt.maxErrors) {
      clear_current_state();
      break;
    }
    process_line(line);
  }
  if (buf)
    std::free(buf);
  stats.bytesProcessed = bytesProcessed;
  if (opt.showProgress && total_bytes > 0) {
    report_progress(bytesProcessed, total_bytes, opt.filename);
  }
  flush();
  output_pending_blocks();
}

std::size_t LogProcessor::get_file_size_for_progress() const {
  return get_file_size_bytes(opt.filename);
}

bool LogProcessor::should_report_progress(std::size_t bytesProcessed,
                                          std::size_t total_bytes) const {
  return opt.showProgress && total_bytes > 0 &&
         (bytesProcessed % PROGRESS_REPORT_INTERVAL == 0 || bytesProcessed >= total_bytes);
}

void LogProcessor::output_pending_blocks() {
  if (!opt.trim || marker_found) {
    for (const auto& b : pending_blocks) {
      writer->writeEntry(b);
    }
  }
}

void LogProcessor::processLines(const VecS& lines) {
  std::size_t start_index = 0;
  if (opt.trim) {
    start_index = find_marker(lines);
    if (start_index == 0)
      return;
  }
  for (std::size_t i = start_index; i < lines.size(); ++i) {
    stats.linesRead++;
    validate_line_length(lines[i]);
    process_line(lines[i]);
  }
  flush();
}

void LogProcessor::process_line(std::string_view line) {
  if (opt.trim && opt.streamMode) {
    for (const auto& m : opt.markers) {
      if (line.find(m) != std::string_view::npos) {
        marker_found = true;
        reset_epoch();
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

  if (!matches_vg_line(line))
    return;

  std::string processed{LogParser::removePrefix(line)};

  if (matches_start_pattern(processed)) {
    flush();
    // After flush, we are starting a new block (potentially)
    // Update pendingPid with the PID from the current line that started this new block
    if (raw.empty()) {
      pendingPid = currentLinePid;
    }

    if (matches_bytes_head(processed))
      return;
  }

  // If we are starting a new block (and didn't flush above, or flushed and empty), capture PID
  if (raw.empty() && pendingPid.empty() && !currentLinePid.empty()) {
    pendingPid = currentLinePid;
  }

  auto rawLine = process_raw_line(processed);
  if (trim_view(rawLine).empty())
    return;

  raw.append(rawLine).push_back('\n');

  const auto cl = canon(processed);
  sig.append(cl).push_back('\n');
  sigLines.push_back(cl);
}

std::string LogProcessor::process_raw_line(const std::string& processed_line) const {
  if (!opt.scrub_raw)
    return processed_line;
  return replace_patterns(processed_line);
}

void LogProcessor::flush() {
  if (raw.empty()) {
    clear_current_state();
    return;
  }

  validate_block_size(raw.size());
  stats.blocksFound++;

  const std::string key = generate_signature_key();
  LogEntry entry = parse_entry(raw, key);

  if (entry.pid.empty()) {
    entry.pid = pendingPid;
  }

  if (opt.strictMode && (entry.pid.empty() || entry.errorType.empty())) {
    stats.parseErrors++;
    throw std::runtime_error("Strict mode: Failed to parse valid Valgrind entry from block");
  }

  // Filter check
  if (!shouldKeepEntry(entry)) {
    stats.filteredCount++;
    clear_current_state();
    return;
  }

  if (seen.insert(key).second) {
    stats.uniqueBlocks++;
    stats.errorCounts[entry.errorType]++;
    if (!entry.pid.empty()) {
      try {
        stats.errorCountsByPid[std::stoi(entry.pid)]++;
      } catch (...) {
        // Ignore non-numeric PID if any
      }
    }
    if (entry.tid.has_value()) {
      stats.errorCountsByTid[*entry.tid]++;
    }
    if (opt.streamMode) {
      validate_pending_blocks_count(pending_blocks.size());
      pending_blocks.emplace_back(std::move(entry));
    } else {
      writer->writeEntry(entry);
    }
  }
  clear_current_state();
}

bool LogProcessor::shouldKeepEntry(const LogEntry& entry) const {
  // Exclude Types
  for (const auto& ex : opt.excludeTypes) {
    if (entry.errorType.find(ex) != std::string::npos) {
      return false;
    }
  }

  // Stack Regex Filter
  if (!stack_regexes.empty()) {
    for (const auto& re : stack_regexes) {
      for (const auto& frame : entry.stackTrace) {
        if (std::regex_search(frame, re)) {
          return false;
        }
      }
    }
  }

  // Thread Filter
  if (entry.tid.has_value()) {
    for (auto t : opt.excludeThreads) {
      if (t == *entry.tid) {
        return false;
      }
    }
  }

  // Path Filter (Structured Stack)
  if (!opt.excludeSourcePaths.empty()) {
    for (const auto& frame : entry.stackFrames) {
      for (const auto& path : opt.excludeSourcePaths) {
        if (frame.location.find(path) != std::string::npos) {
          return false;
        }
      }
    }
  }

  // Function Name Exclusion
  if (!opt.excludeFunctions.empty()) {
    for (const auto& func : opt.excludeFunctions) {
      if (entry.hasFrameMatching(func)) {
        return false;
      }
    }
  }

  // Include-Only Logic
  bool includesActive = !opt.includeTypes.empty() || !opt.includeFunctions.empty();
  if (includesActive) {
    bool matched = false;
    // Check Types
    if (!opt.includeTypes.empty()) {
      for (const auto& type : opt.includeTypes) {
        if (entry.matchesErrorType(type)) {
          matched = true;
          break;
        }
      }
    }
    // Check Functions (if not already matched)
    if (!matched && !opt.includeFunctions.empty()) {
      for (const auto& func : opt.includeFunctions) {
        if (entry.hasFrameMatching(func)) {
          matched = true;
          break;
        }
      }
    }

    if (!matched) {
      return false;
    }
  }

  return true;
}

std::string LogProcessor::generate_signature_key() const {
  if (opt.depth <= 0)
    return sig;
  std::string key;
  key.reserve(RESERVE_KEY_SIZE);
  for (const auto& line : sigLines | std::views::take(static_cast<std::size_t>(opt.depth))) {
    key.append(line).push_back('\n');
  }
  return key;
}

void LogProcessor::clear_current_state() noexcept {
  raw.clear();
  sig.clear();
  sigLines.clear();
  pendingPid.clear();
}

void LogProcessor::reset_epoch() noexcept {
  pending_blocks.clear();
  seen.clear();
  clear_current_state();
}

std::size_t LogProcessor::find_marker(const VecS& lines) const {
  for (std::size_t i = lines.size(); i-- > 0;) {
    for (const auto& m : opt.markers) {
      if (lines[i].find(m) != std::string::npos) {
        return i + 1;
      }
    }
  }
  return 0;
}

LogEntry LogProcessor::parse_entry(const std::string& raw_block,
                                   const std::string& signature) const {
  LogEntry entry;
  entry.rawContent = raw_block;
  entry.signature = signature;

  std::string_view sv = raw_block;
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

void LogProcessor::printStats(std::FILE* out) const {
  if (!out)
    return;
  // Use LogWriter to format stats (Iter 1 requirement)
  writer->writeStats(stats);
}
