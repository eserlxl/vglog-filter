// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "yaml_log_writer.h"
#include "file_utils.h"
#include "json_utils.h" // For basic string escaping
#include <iostream>

YamlLogWriter::YamlLogWriter(const std::string& fname) : filename(fname) {
  out = openOutputFile(filename);
}

YamlLogWriter::~YamlLogWriter() {
  flush();
}

void YamlLogWriter::writeEntry(const LogEntry& entry) {
  if (!out) return;

  *out << "- type: \"" << json_utils::escape_string(entry.errorType) << "\"\n";
  *out << "  pid: " << entry.pid << "\n";
  if (entry.tid) {
    *out << "  tid: " << *entry.tid << "\n";
  }
  
  if (!entry.stackFrames.empty()) {
      *out << "  stack:\n";
      for (const auto& frame : entry.stackFrames) {
          *out << "    - function: \"" << json_utils::escape_string(frame.function) << "\"\n";
          if (!frame.location.empty()) {
            *out << "      location: \"" << json_utils::escape_string(frame.location) << "\"\n";
          }
      }
  }
  
  *out << "  signature: \"" << json_utils::escape_string(entry.signature) << "\"\n";
}

void YamlLogWriter::writeRaw(const std::string& raw) {
    if (!out) return;
    *out << "- raw: \"" << json_utils::escape_string(raw) << "\"\n";
}

void YamlLogWriter::writeStats(const LogStats&) {
    // YAML stats?
}

void YamlLogWriter::setUseColor(bool) {}

void YamlLogWriter::writeStatsJson(const LogStats&, const std::string&) const {}

void YamlLogWriter::flush() {
  if (out) out->flush();
}

void YamlLogWriter::writeDiffSummary(const DiffEngine::DiffStats& stats) {
    if (out) {
        *out << "# Diff Summary: New=" << stats.totalNew << "\n";
    }
}
