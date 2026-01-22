// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "log_processor.h"

#include "canonicalization.h"
#include "file_utils.h"

#include <array>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <iostream>
#include <ranges>
#include <string>
#include <thread>

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

std::string escape_json(const std::string& s) {
  std::string out;
  out.reserve(s.size() + 8);
  for (char c : s) {
    switch (c) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\b':
        out += "\\b";
        break;
      case '\f':
        out += "\\f";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) {
          char buf[7];
          std::snprintf(buf, sizeof(buf), "\\u%04x", c);
          out += buf;
        } else {
          out += c;
        }
    }
  }
  return out;
}

} // namespace

LogProcessor::LogProcessor(const Options& options) : opt(options), stats{} {
  seen.reserve(256);
  pending_blocks.reserve(opt.stream_mode ? 64 : 0);
  sigLines.reserve(64);
  initialize_string_patterns();

  if (!opt.output_file.empty()) {
    auto fh = std::make_shared<FileHandle>(opt.output_file.c_str(), "w");
    out_fp = fh->get();
    file_handle_lifetime = std::static_pointer_cast<void>(fh);
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
  if (line.size() < 4)
    return false;
  if (line[0] != '=' || line[1] != '=')
    return false;
  std::size_t i = 2;
  while (i < line.size() && is_digit(line[i]))
    ++i;
  if (i < 4 || i + 1 >= line.size())
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
  static constexpr std::array<std::string_view, 10> keys{
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
  if (pos + 10 >= line.size() || line.substr(pos, 10) != " bytes in ")
    return false;
  pos += 10;
  if (pos >= line.size() || !is_digit(line[pos]))
    return false;
  while (pos < line.size() && is_digit(line[pos]))
    ++pos;
  if (pos + 7 > line.size())
    return false;
  return line.substr(pos, 7) == " blocks";
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

std::string LogProcessor::replace_prefix(std::string_view line) const {
  if (!matches_vg_line(line))
    return std::string{line};
  std::size_t i = 2;
  while (i < line.size() && is_digit(line[i]))
    ++i;
  i += 2; // ==
  while (i < line.size() && std::isspace(static_cast<unsigned char>(line[i])))
    ++i;
  return std::string{line.substr(i)};
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

void LogProcessor::process_stream(std::istream& in) {
  std::size_t bytes_processed = 0;
  std::size_t total_bytes = 0;
  if (opt.show_progress && !opt.use_stdin) {
    total_bytes = get_file_size_for_progress();
  }
  std::string line;
  while (std::getline(in, line)) {
    stats.lines_read++;
    validate_line_length(line);
    bytes_processed += line.size() + 1;
    if (should_report_progress(bytes_processed, total_bytes)) {
      report_progress(bytes_processed, total_bytes, opt.filename);
    }
    process_line(line);
  }
  stats.bytes_processed = bytes_processed;
  if (opt.show_progress && total_bytes > 0) {
    report_progress(bytes_processed, total_bytes, opt.filename);
  }
  flush();
  output_pending_blocks();
}

void LogProcessor::process_stream_cfile(std::FILE* fp) {
  if (fp == nullptr)
    return;
  std::size_t bytes_processed = 0;
  std::size_t total_bytes = 0;
  if (opt.show_progress && !opt.use_stdin) {
    total_bytes = get_file_size_for_progress();
  }
  std::string line;
  line.reserve(1024);
  char* buf = nullptr;
  size_t buf_size = 0;
  ssize_t read = -1;
  while ((read = ::getline(&buf, &buf_size, fp)) != -1) {
    if (read > 0 && buf[read - 1] == '\n') {
      line.assign(buf, static_cast<std::size_t>(read - 1));
      bytes_processed += static_cast<std::size_t>(read);
    } else {
      line.assign(buf, static_cast<std::size_t>(read));
      bytes_processed += static_cast<std::size_t>(read);
    }
    stats.lines_read++;
    validate_line_length(line);
    if (should_report_progress(bytes_processed, total_bytes)) {
      report_progress(bytes_processed, total_bytes, opt.filename);
    }
    process_line(line);
  }
  if (buf)
    std::free(buf);
  stats.bytes_processed = bytes_processed;
  if (opt.show_progress && total_bytes > 0) {
    report_progress(bytes_processed, total_bytes, opt.filename);
  }
  flush();
  output_pending_blocks();
}

std::size_t LogProcessor::get_file_size_for_progress() const {
  return get_file_size_bytes(opt.filename);
}

bool LogProcessor::should_report_progress(std::size_t bytes_processed,
                                          std::size_t total_bytes) const {
  return opt.show_progress && total_bytes > 0 &&
         (bytes_processed % PROGRESS_REPORT_INTERVAL == 0 || bytes_processed >= total_bytes);
}

void LogProcessor::output_pending_blocks() const {
  if (!opt.trim || marker_found) {
    for (const auto& b : pending_blocks) {
      if (opt.json_output) {
        write_json_record(b);
      } else {
        write_output(b.raw_content.data(), b.raw_content.size());
        write_output('\n');
      }
    }
  }
}

void LogProcessor::process_lines(const VecS& lines) {
  std::size_t start_index = 0;
  if (opt.trim) {
    start_index = find_marker(lines);
    if (start_index == 0)
      return;
  }
  for (std::size_t i = start_index; i < lines.size(); ++i) {
    stats.lines_read++;
    validate_line_length(lines[i]);
    process_line(lines[i]);
  }
  flush();
}

void LogProcessor::process_line(std::string_view line) {
  if (opt.trim && opt.stream_mode) {
    for (const auto& m : opt.markers) {
      if (line.find(m) != std::string_view::npos) {
        marker_found = true;
        reset_epoch();
        return;
      }
    }
  }

  if (!matches_vg_line(line))
    return;

  std::string processed = replace_prefix(line);

  if (matches_start_pattern(processed)) {
    flush();
    if (matches_bytes_head(processed))
      return;
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
  stats.blocks_found++;

  const std::string key = generate_signature_key();
  LogEntry entry = parse_entry(raw, key);

  // Filter check
  for (const auto& ex : opt.exclude_types) {
    if (entry.error_type.find(ex) != std::string::npos) {
      clear_current_state();
      return;
    }
  }

  if (seen.insert(key).second) {
    stats.unique_blocks++;
    if (opt.stream_mode) {
      validate_pending_blocks_count(pending_blocks.size());
      pending_blocks.emplace_back(std::move(entry));
    } else {
      if (opt.json_output) {
        write_json_record(entry);
      } else {
        write_output(entry.raw_content.data(), entry.raw_content.size());
        write_output('\n');
      }
    }
  }
  clear_current_state();
}

std::string LogProcessor::generate_signature_key() const {
  if (opt.depth <= 0)
    return sig;
  std::string key;
  key.reserve(256);
  for (const auto& line : sigLines | std::views::take(static_cast<std::size_t>(opt.depth))) {
    key.append(line).push_back('\n');
  }
  return key;
}

void LogProcessor::clear_current_state() noexcept {
  raw.clear();
  sig.clear();
  sigLines.clear();
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

void LogProcessor::write_output(const void* data, size_t size) const {
  if (out_fp && data && size > 0) {
    std::fwrite(data, 1, size, out_fp);
  }
}
void LogProcessor::write_output(char c) const {
  if (out_fp) {
    std::fputc(c, out_fp);
  }
}

void LogProcessor::write_json_record(const LogEntry& entry) const {
  if (!out_fp)
    return;
  std::string json = "{\"type\":\"record\"";
  json += ",\"raw\":\"" + escape_json(entry.raw_content) + "\"";
  json += ",\"signature\":\"" + escape_json(entry.signature) + "\"";
  if (!entry.error_type.empty()) {
    json += ",\"error_type\":\"" + escape_json(entry.error_type) + "\"";
  }
  if (!entry.pid.empty()) {
    json += ",\"pid\":\"" + escape_json(entry.pid) + "\"";
  }
  if (!entry.stack_trace.empty()) {
    json += ",\"stack_trace\":[";
    for (size_t i = 0; i < entry.stack_trace.size(); ++i) {
      if (i > 0)
        json += ",";
      json += "\"" + escape_json(entry.stack_trace[i]) + "\"";
    }
    json += "]";
  }
  json += "}\n";
  write_output(json.data(), json.size());
}

LogEntry LogProcessor::parse_entry(const std::string& raw_block,
                                   const std::string& signature) const {
  LogEntry entry;
  entry.raw_content = raw_block;
  entry.signature = signature;

  std::string_view sv = raw_block;
  // Parse first line for PID and Error Type
  size_t first_eol = sv.find('\n');
  if (first_eol == std::string_view::npos)
    first_eol = sv.size();
  std::string_view first_line = sv.substr(0, first_eol);

  // Extract PID: ==12345==
  if (first_line.size() >= 2 && first_line[0] == '=' && first_line[1] == '=') {
    size_t end_pid = first_line.find("==", 2);
    if (end_pid != std::string_view::npos) {
      entry.pid = std::string(first_line.substr(2, end_pid - 2));
    }
  }

  // Extract Error Type (rest of first line after prefix)
  entry.error_type = replace_prefix(first_line);
  if (!entry.error_type.empty() && entry.error_type.back() == '\r') {
    entry.error_type.pop_back();
  }

  // Populate stack trace from subsequent lines
  size_t pos = first_eol + 1;
  while (pos < sv.size()) {
    size_t eol = sv.find('\n', pos);
    if (eol == std::string_view::npos)
      eol = sv.size();
    std::string_view line = sv.substr(pos, eol - pos);
    std::string content = replace_prefix(line);
    if (!content.empty()) {
      // Trim newlines
      while (!content.empty() && (content.back() == '\n' || content.back() == '\r')) {
        content.pop_back();
      }
      entry.stack_trace.push_back(std::move(content));
    }
    pos = eol + 1;
  }

  return entry;
}

void LogProcessor::print_stats(std::FILE* out) const {
  if (!out)
    return;
  if (opt.json_output) {
    if (out_fp) {
      std::fprintf(out_fp,
                   "{\"type\":\"stats\",\"lines_read\":%zu,\"bytes_processed\":%zu,\"blocks_"
                   "found\":%zu,\"unique_blocks\":%zu}\n",
                   stats.lines_read, stats.bytes_processed, stats.blocks_found,
                   stats.unique_blocks);
    }
  } else {
    std::fprintf(out, "--- Statistics ---\n");
    std::fprintf(out, "Lines read      : %zu\n", stats.lines_read);
    std::fprintf(out, "Bytes processed : %zu\n", stats.bytes_processed);
    std::fprintf(out, "Blocks found    : %zu\n", stats.blocks_found);
    std::fprintf(out, "Unique blocks   : %zu\n", stats.unique_blocks);
  }
}