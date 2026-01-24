// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "csv_log_writer.h"
#include "file_utils.h"
#include <iostream>
#include <sstream>

namespace {
std::string escapeCsv(const std::string& s) {
  bool needsQuotes = false;
  for (char c : s) {
    if (c == ',' || c == '"' || c == '\n' || c == '\r') {
      needsQuotes = true;
      break;
    }
  }

  if (!needsQuotes) {
    return s;
  }

  std::string out;
  out.reserve(s.size() + 2);
  out.push_back('"');
  for (char c : s) {
    if (c == '"') {
      out.push_back('"'); // Escape quote with quote
    }
    out.push_back(c);
  }
  out.push_back('"');
  return out;
}
} // namespace

CsvLogWriter::CsvLogWriter(const std::string& fname) : filename(fname) {
  out = openOutputFile(filename);
  writeHeader();
}

CsvLogWriter::~CsvLogWriter() {
  flush();
}

void CsvLogWriter::writeHeader() {
  if (out) {
    *out << "Timestamp,PID,TID,ErrorType,SourceFile,Line,Function,Signature\n";
  }
}

void CsvLogWriter::writeEntry(const LogEntry& entry) {
  if (!out) return;

  std::string ts = entry.timestamp ? *entry.timestamp : "";
  // Use user-friendly timestamp string if possible? LogEntry stores raw string too?
  // LogEntry defines: std::optional<TimePoint> timestamp;
  // Let's use numeric timestamp for CSV or ISO8601?
  // Ideally ISO. But I don't see format helper in `time_utils.h`.
  // Let's check `time_utils.h` later. For now, empty or numeric.
  
  std::string file = "";
  std::string line = "";
  std::string func = "";

  if (!entry.stackFrames.empty()) {
      const auto& f = entry.stackFrames[0];
      func = f.function;
      auto colon = f.location.find_last_of(':');
      if (colon != std::string::npos) {
          file = f.location.substr(0, colon);
          line = f.location.substr(colon + 1);
      } else {
          file = f.location;
      }
  }

  *out << escapeCsv(ts) << ","
       << escapeCsv(std::to_string(entry.pid)) << ","
       << (entry.tid ? std::to_string(*entry.tid) : "") << ","
       << escapeCsv(entry.errorType) << ","
       << escapeCsv(file) << ","
       << escapeCsv(line) << ","
       << escapeCsv(func) << ","
       << escapeCsv(entry.signature) << "\n";
}

void CsvLogWriter::writeRaw(const std::string& raw) {
  // invalid for CSV structure, maybe ignore or write a comment?
  if (out) *out << "# Raw: " << escapeCsv(raw) << "\n";
}

void CsvLogWriter::writeStats(const LogStats&) {
    // CSV stats?
}

void CsvLogWriter::setUseColor(bool) {
    // No-op for CSV
}

void CsvLogWriter::writeStatsJson(const LogStats&, const std::string&) const {
    // Delegated (reuse existing logic or do nothing if not primary writer)
    // usually handled by StoreLogWriter or explicit call.
}

void CsvLogWriter::flush() {
  if (out) out->flush();
}

void CsvLogWriter::writeDiffSummary(const DiffEngine::DiffStats& stats) {
    if (out) {
        *out << "# Diff Summary: New=" << stats.totalNew 
             << " Fixed=" << stats.totalFixed
             << " Common=" << stats.totalCommon << "\n";
    }
}
