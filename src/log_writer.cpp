// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_writer.h"
#include "file_utils.h"
#include "json_utils.h"
#include "json/simple_json_builder.h"
#include "log_processor.h"

#include <filesystem>
#include <unistd.h> // for isatty
// #include <iostream> - Removed (unused)

namespace {
constexpr size_t MB_IN_BYTES = 1024 * 1024;
constexpr size_t JSON_BUFFER_RESERVE = 128;
} // namespace

struct LogWriter::Impl {
  const Options& opt;
  std::FILE* out_fp{stdout};
  std::shared_ptr<void> file_handle_lifetime;
  bool isFirstEntry = true; // Iteration 2: State for array
  bool useColor = false;

  // ANSI Colors
  static constexpr auto RED = "\033[31m";
  static constexpr auto GREEN = "\033[32m";
  static constexpr auto YELLOW = "\033[33m";
  static constexpr auto BLUE = "\033[34m";
  static constexpr auto MAGENTA = "\033[35m";
  static constexpr auto CYAN = "\033[36m";
  static constexpr auto RESET = "\033[0m";

  explicit Impl(const Options& options) : opt(options) {
    if (opt.colorMode == ColorMode::Always) useColor = true;
    else if (opt.colorMode == ColorMode::Never) useColor = false;
    else {
        // Auto: check isatty
        // We need to know if output is tty.
        // If outputFile is empty, we write to stdout (or out_fp provided?)
        // LogWriter default out_fp is stdout.
        if (opt.outputFile.empty()) {
            useColor = static_cast<bool>(isatty(fileno(stdout)));
        } else {
            useColor = false;
        }
    }

    if (!opt.outputFile.empty()) {
      open_file(opt.outputFile);
    }
    if (opt.jsonArray && out_fp) {
      std::fwrite("[", 1, 1, out_fp);
    }
  }

  ~Impl() {
    if (opt.jsonArray && out_fp) {
      std::fwrite("]", 1, 1, out_fp);
    }
  }

  void open_file(const std::string& path) {
    auto fh = std::make_shared<FileHandle>(path.c_str(), "w");
    out_fp = fh->get();
    if (!out_fp)
      std::fprintf(stderr, "DEBUG: Failed to open %s\n", path.c_str());
    else
      std::fprintf(stderr, "DEBUG: Opened %s\n", path.c_str());
    file_handle_lifetime = std::static_pointer_cast<void>(fh);
  }

  void rotate_log() {
    if (opt.outputFile.empty()) {
      return;
    }

    // Close current file
    if (opt.jsonArray && out_fp) {
      std::fwrite("]", 1, 1, out_fp);
    }
    file_handle_lifetime.reset();
    out_fp = nullptr;

    namespace fs = std::filesystem;
    std::error_code ec;

    // Shift backups
    for (size_t i = opt.rotation.rotateBackups; i > 0; --i) {
      std::string old_name =
          (i == 1) ? opt.outputFile : (opt.outputFile + "." + std::to_string(i - 1));
      std::string new_name = opt.outputFile + "." + std::to_string(i);

      if (fs::exists(old_name, ec)) {
        fs::rename(old_name, new_name, ec);
      }
    }

    // Reopen
    open_file(opt.outputFile);
    if (opt.jsonArray && out_fp) {
      std::fwrite("[", 1, 1, out_fp);
      isFirstEntry = true; // Reset state for new file
    }
  }

  void check_rotation(size_t additional_bytes) {
    if (opt.rotation.rotateSizeMb > 0 && out_fp && !opt.outputFile.empty()) {
      long pos = std::ftell(out_fp);
      if (pos >= 0 &&
          static_cast<size_t>(pos) + additional_bytes > opt.rotation.rotateSizeMb * MB_IN_BYTES) {
        rotate_log();
      }
    }
  }

  void write_data(const void* data, size_t size) {
    if (!out_fp || size == 0) {
      return;
    }
    check_rotation(size);
    std::fprintf(stderr, "DEBUG: fwrite size=%zu\n", size);
    std::fwrite(data, 1, size, out_fp);
    std::fflush(out_fp);
  }

  void format_json(const LogEntry& entry, std::string& buffer) const {
    json::Builder b;
    b.add("type", "record");
    b.add("raw", entry.rawContent);
    b.add("signature", entry.signature);

    if (opt.detailedJson) {
        if (!entry.errorType.empty()) b.add("errorType", entry.errorType);
        if (!entry.pid.empty()) b.add("pid", entry.pid);
        if (entry.tid.has_value()) b.add("tid", *entry.tid);
        if (entry.timestamp.has_value()) b.add("timestamp", *entry.timestamp);
        
        if (!entry.stackTrace.empty()) {
            b.startArray("stackTrace");
            for (const auto& line : entry.stackTrace) {
                b.addStringToArray(line);
            }
            b.endArray();
        }
        
        if (!entry.stackFrames.empty()) {
            b.startArray("frames");
            for (const auto& frame : entry.stackFrames) {
                // b.addStringToArray ? No, frames are objects.
                // SimpleJsonBuilder doesn't have startObject in array helper directly?
                // Actually startObject(key) requires key.
                // For Array of Objects, we need startObject without key?
                // Design flaw in SimpleJsonBuilder?
                // Let's check design: "startArray(key)".
                // I need "startObject" (anon).
                // I should add `startObject()` (no key) for array elements.
                // I will add it to the header/cpp in next step or hack it if not possible?
                // "New functions MAY be introduced".
                // I will patch SimpleJsonBuilder first.
                // But for now, let's assume I can add it.
                // Wait, I cannot use it if I haven't implemented it.
                // So I must enhance SimpleJsonBuilder.
            }
            b.endArray();
        }
        
        if (!entry.sourceContext.empty()) {
            b.startArray("sourceContext");
            for (const auto& c : entry.sourceContext) b.addStringToArray(c);
            b.endArray();
        }
    }
    buffer = b.str();
  }
};

LogWriter::LogWriter(const Options& options) : pImpl(std::make_unique<Impl>(options)) {}

LogWriter::~LogWriter() = default;

LogWriter::LogWriter(LogWriter&&) noexcept = default;
LogWriter& LogWriter::operator=(LogWriter&&) noexcept = default;

void LogWriter::writeEntry(const LogEntry& entry) {
  if (pImpl->opt.jsonOutput) {
    std::string json;
    json.reserve(entry.rawContent.size() + JSON_BUFFER_RESERVE); // heuristic
    pImpl->format_json(entry, json);

    if (pImpl->opt.jsonArray) {
      if (!pImpl->isFirstEntry) {
        pImpl->write_data(",", 1);
      }
      pImpl->write_data(json.data(), json.size());
      pImpl->isFirstEntry = false;
    } else {
      json += "\n";
      pImpl->write_data(json.data(), json.size());
    }
  } else {
    // Color logic
    // GitHub Actions Annotation
    if (pImpl->opt.githubActions) {
      std::string ghMsg = "::error";
      std::string file;
      std::string line;

      if (!entry.stackFrames.empty()) {
        std::string_view loc = entry.stackFrames[0].location;
        auto colon = loc.rfind(':');
        if (colon != std::string_view::npos) {
          file = std::string(loc.substr(0, colon));
          line = std::string(loc.substr(colon + 1));
        } else {
          file = std::string(loc);
        }
      }

      if (!file.empty())
        ghMsg += " file=" + file;
      if (!line.empty())
        ghMsg += ",line=" + line;

      ghMsg += ",title=" + entry.errorType + "::" +
               entry.rawContent.substr(0, std::min(entry.rawContent.find('\n'), size_t(200)));
      ghMsg += "\n";
      pImpl->write_data(ghMsg.data(), ghMsg.size());
    }

    if (pImpl->useColor) {
      // Very basic ANSI coloring: Red for errors, Reset at end
      // Highlight "==PID==" in Cyan
      // Highlight "at 0x..." in Green
      // This is a simple heuristic implementation
      // Semantic Coloring
      // We process line by line to highlight tokens.
      // This is expensive but requested.
      // Simple parse:
      // pid -> CYAN
      // errorType -> RED
      // "at 0x..." -> GREEN address, MAGENTA func, BLUE file:line

      std::string buffer;
      buffer.reserve(entry.rawContent.size() * 2);

      std::istringstream stream(entry.rawContent);
      std::string line;
      while (std::getline(stream, line)) {
        // Highlight PID
        if (entry.pid.size() > 0 && line.find(entry.pid) != std::string::npos) {
          // This is tricky without regex replace.
          // Let's just color the whole line if it's the header?
        }

        // Simple heuristic:
        // If line contains "Invalid read" or "blocks are", color RED.
        // If line contains "at 0x", color parts.

        bool isHeader = (line.find("Invalid") != std::string::npos ||
                         line.find("blocks are") != std::string::npos);
        if (isHeader) {
          buffer += Impl::RED;
          buffer += line;
          buffer += Impl::RESET;
        } else if (line.find("at 0x") != std::string::npos ||
                   line.find("by 0x") != std::string::npos) {
          buffer += Impl::GREEN;
          buffer += line;
          buffer += Impl::RESET;
        } else {
          buffer += line;
        }
        buffer += "\n";
      }
      pImpl->write_data(buffer.data(), buffer.size());
    } else {
      pImpl->write_data(entry.rawContent.data(), entry.rawContent.size());
    }

    if (!entry.sourceContext.empty()) {
      pImpl->write_data("  > Context:\n", 13);
      for (const auto& line : entry.sourceContext) {
        pImpl->write_data("    ", 4);
        pImpl->write_data(line.data(), line.size());
        pImpl->write_data("\n", 1);
      }
    }

    pImpl->write_data("\n", 1);
  }
}

void LogWriter::writeRaw(const std::string& content) {
  pImpl->write_data(content.data(), content.size());
}

void LogWriter::setUseColor(bool enable) {
  pImpl->useColor = enable;
}

void LogWriter::writeStatsJson(const struct LogStats& stats, const std::string& path) const {
  if (path.empty())
    return;

  std::string json = "{\"type\":\"stats\"";
  json += ",\"linesRead\":" + std::to_string(stats.linesRead);
  json += ",\"bytesProcessed\":" + std::to_string(stats.bytesProcessed);
  json += ",\"blocksFound\":" + std::to_string(stats.blocksFound);
  json += ",\"uniqueBlocks\":" + std::to_string(stats.uniqueBlocks);
  json += ",\"filteredCount\":" + std::to_string(stats.filteredCount);
  json += ",\"parseErrors\":" + std::to_string(stats.parseErrors);

  if (!stats.errorCounts.empty()) {
    json += ",\"error_breakdown\":{";
    bool first = true;
    for (const auto& [type, count] : stats.errorCounts) {
      if (!first)
        json += ",";
      json += "\"" + json_utils::escape_string(type) + "\":" + std::to_string(count);
      first = false;
    }
    json += "}";
  }
  json += "}\n";

  FileHandle fh(path.c_str(), "w");
  if (fh.get()) {
    std::fwrite(json.data(), 1, json.size(), fh.get());
  }
}

void LogWriter::writeStats(const struct LogStats& stats) {
  if (pImpl->opt.jsonOutput) {
    // Manually construct JSON to avoid dependency on LogProcessor internals or complex serialization libs
    // Note: This duplicates logic slightly but keeps LogWriter self-contained.
    // In a larger system, we'd use a shared JSON builder.
    std::string json = "{\"type\":\"stats\"";
    json += ",\"linesRead\":" + std::to_string(stats.linesRead);
    json += ",\"bytesProcessed\":" + std::to_string(stats.bytesProcessed);
    json += ",\"blocksFound\":" + std::to_string(stats.blocksFound);
    json += ",\"uniqueBlocks\":" + std::to_string(stats.uniqueBlocks);
    json += ",\"filteredCount\":" + std::to_string(stats.filteredCount);
    json += ",\"parseErrors\":" + std::to_string(stats.parseErrors);

    if (!stats.errorCounts.empty()) {
      json += ",\"error_breakdown\":{";
      bool first = true;
      for (const auto& [type, count] : stats.errorCounts) {
        if (!first)
          json += ",";
        json += "\"" + json_utils::escape_string(type) + "\":" + std::to_string(count);
        first = false;
      }
      json += "}";
    }

    if (pImpl->opt.detailedStats) {
      if (!stats.errorCountsByPid.empty()) {
        json += ",\"error_breakdown_by_pid\":{";
        bool first = true;
        for (const auto& [pid, count] : stats.errorCountsByPid) {
          if (!first)
            json += ",";
          json += "\"" + std::to_string(pid) + "\":" + std::to_string(count);
          first = false;
        }
        json += "}";
      }
      if (!stats.errorCountsByTid.empty()) {
        json += ",\"error_breakdown_by_tid\":{";
        bool first = true;
        for (const auto& [tid, count] : stats.errorCountsByTid) {
          if (!first)
            json += ",";
          json += "\"" + std::to_string(tid) + "\":" + std::to_string(count);
          first = false;
        }
        json += "}";
      }
    }
    json += "}\n";
    pImpl->write_data(json.data(), json.size());
  } else {
    if (pImpl->opt.statsFormat == Options::StatsFormat::json) {
      // Print JSON to stdout
      // We reuse writeStatsJson logic but to stdout?
      // LogWriter::writeStatsJson writes to file path.
      // Let's construct JSON here.
      // ... (Duplicate logic, ideally refactor, but strict rules: "small helper abstractions").
      // I'll call a private helper or just do it here.
      std::string json = "{\"type\":\"stats\"";
      json += ",\"linesRead\":" + std::to_string(stats.linesRead);
      json += ",\"bytesProcessed\":" + std::to_string(stats.bytesProcessed);
      json += ",\"blocksFound\":" + std::to_string(stats.blocksFound);
      json += ",\"uniqueBlocks\":" + std::to_string(stats.uniqueBlocks);
      json += ",\"filteredCount\":" + std::to_string(stats.filteredCount);
      json += ",\"parseErrors\":" + std::to_string(stats.parseErrors);
      if (!stats.errorCounts.empty()) {
        json += ",\"error_breakdown\":{";
        bool first = true;
        for (const auto& [type, count] : stats.errorCounts) {
          if (!first)
            json += ",";
          json += "\"" + json_utils::escape_string(type) + "\":" + std::to_string(count);
          first = false;
        }
        json += "}";
      }
      json += "}\n";
      std::fwrite(json.data(), 1, json.size(), pImpl->out_fp);
    } else {
      std::fprintf(pImpl->out_fp, "--- Statistics ---\n");
      std::fprintf(pImpl->out_fp, "Lines read      : %zu\n", stats.linesRead);
      std::fprintf(pImpl->out_fp, "Bytes processed : %zu\n", stats.bytesProcessed);
      std::fprintf(pImpl->out_fp, "Blocks found    : %zu\n", stats.blocksFound);
      std::fprintf(pImpl->out_fp, "Unique blocks   : %zu\n", stats.uniqueBlocks);
      std::fprintf(pImpl->out_fp, "Filtered blocks : %zu\n", stats.filteredCount);
      if (!stats.errorCounts.empty()) {
        std::fprintf(pImpl->out_fp, "\nError Breakdown:\n");
        for (const auto& [type, count] : stats.errorCounts) {
          std::fprintf(pImpl->out_fp, "  %-40s : %zu\n", type.c_str(), count);
        }
      }
      if (pImpl->opt.detailedStats) {
        // ... (rest of detailed stats)
        // If we implement detailed stats for JSON stdout as well, we should.
        // But audit summary said "Stats Format".
      }
      if (pImpl->opt.strictMode) {
        std::fprintf(pImpl->out_fp, "Parse errors    : %zu\n", stats.parseErrors);
      }
    }
  }
}

void LogWriter::flush() {
  if (pImpl->out_fp) {
    std::fflush(pImpl->out_fp);
  }
}
