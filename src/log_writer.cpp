// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_writer.h"
#include "file_utils.h"
#include "json_utils.h"
#include "log_processor.h"

#include <filesystem>
#include <iostream>

struct LogWriter::Impl {
  const Options& opt;
  std::FILE* out_fp{stdout};
  std::shared_ptr<void> file_handle_lifetime;

  explicit Impl(const Options& options) : opt(options) {
    if (!opt.outputFile.empty()) {
      open_file(opt.outputFile);
    }
  }

  void open_file(const std::string& path) {
    auto fh = std::make_shared<FileHandle>(path.c_str(), "w");
    out_fp = fh->get();
    file_handle_lifetime = std::static_pointer_cast<void>(fh);
  }

  void rotate_log() {
    if (opt.outputFile.empty()) {
      return;
    }

    // Close current file
    file_handle_lifetime.reset();
    out_fp = nullptr;

    namespace fs = std::filesystem;
    std::error_code ec;

    // Shift backups
    for (size_t i = opt.rotateBackups; i > 0; --i) {
      std::string old_name =
          (i == 1) ? opt.outputFile : (opt.outputFile + "." + std::to_string(i - 1));
      std::string new_name = opt.outputFile + "." + std::to_string(i);

      if (fs::exists(old_name, ec)) {
        fs::rename(old_name, new_name, ec);
      }
    }

    // Reopen
    open_file(opt.outputFile);
  }

  void check_rotation(size_t additional_bytes) {
    if (opt.rotateSizeMb > 0 && out_fp && !opt.outputFile.empty()) {
      long pos = std::ftell(out_fp);
      if (pos >= 0 &&
          static_cast<size_t>(pos) + additional_bytes > opt.rotateSizeMb * 1024 * 1024) {
        rotate_log();
      }
    }
  }

  void write_data(const void* data, size_t size) {
    if (!out_fp || size == 0) {
      return;
    }
    check_rotation(size);
    std::fwrite(data, 1, size, out_fp);
  }

  void format_json(const LogEntry& entry, std::string& buffer) const {
    buffer = "{\"type\":\"record\"";
    buffer += ",\"raw\":\"" + json_utils::escape_string(entry.rawContent) + "\"";
    buffer += ",\"signature\":\"" + json_utils::escape_string(entry.signature) + "\"";

    if (opt.detailedJson) {
      if (!entry.errorType.empty()) {
        buffer += ",\"errorType\":\"" + json_utils::escape_string(entry.errorType) + "\"";
      }
      if (!entry.pid.empty()) {
        buffer += ",\"pid\":\"" + json_utils::escape_string(entry.pid) + "\"";
      }
      if (entry.tid.has_value()) {
        buffer += ",\"tid\":" + std::to_string(*entry.tid);
      }
      if (!entry.stackTrace.empty()) {
        buffer += ",\"stackTrace\":[";
        for (size_t i = 0; i < entry.stackTrace.size(); ++i) {
          if (i > 0)
            buffer += ",";
          buffer += "\"" + json_utils::escape_string(entry.stackTrace[i]) + "\"";
        }
        buffer += "]";

        // Structured Frames
        if (!entry.stackFrames.empty()) {
          buffer += ",\"frames\":[";
          bool firstFrame = true;
          for (const auto& frame : entry.stackFrames) {
            if (!firstFrame)
              buffer += ",";
            buffer += "{";
            bool firstField = true;
            if (!frame.address.empty()) {
              buffer += "\"addr\":\"" + json_utils::escape_string(frame.address) + "\"";
              firstField = false;
            }
            if (!frame.function.empty()) {
              if (!firstField)
                buffer += ",";
              buffer += "\"func\":\"" + json_utils::escape_string(frame.function) + "\"";
              firstField = false;
            }
            if (!frame.location.empty()) {
              if (!firstField)
                buffer += ",";
              buffer += "\"loc\":\"" + json_utils::escape_string(frame.location) + "\"";
            }
            buffer += "}";
            firstFrame = false;
          }
          buffer += "]";
        }
      }
    }
    buffer += "}\n";
  }
};

LogWriter::LogWriter(const Options& options) : pImpl(std::make_unique<Impl>(options)) {}

LogWriter::~LogWriter() = default;

LogWriter::LogWriter(LogWriter&&) noexcept = default;
LogWriter& LogWriter::operator=(LogWriter&&) noexcept = default;

void LogWriter::writeEntry(const LogEntry& entry) {
  if (pImpl->opt.jsonOutput) {
    std::string json;
    json.reserve(entry.rawContent.size() + 128); // heuristic
    pImpl->format_json(entry, json);
    pImpl->write_data(json.data(), json.size());
  } else {
    pImpl->write_data(entry.rawContent.data(), entry.rawContent.size());
    // Raw content usually ends with newline, but ensure one if we're separating blocks?
    // The original code did `write_output('\n');` after content.
    // Let's stick to original behavior but check if content has newline.
    // Original code: write_output(b.rawContent.data(), b.rawContent.size()); write_output('\n');
    pImpl->write_data("\n", 1);
  }
}

void LogWriter::writeRaw(const std::string& content) {
  pImpl->write_data(content.data(), content.size());
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
    // We need to write to the file handle if it's not stdout
    // Using intermediate buffer or direct fwrite only if we have format access
    if (pImpl->out_fp) {
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
        if (!stats.errorCountsByPid.empty()) {
          std::fprintf(pImpl->out_fp, "\nError Breakdown by PID:\n");
          for (const auto& [pid, count] : stats.errorCountsByPid) {
            std::fprintf(pImpl->out_fp, "  PID %-36d : %zu\n", pid, count);
          }
        }
        if (!stats.errorCountsByTid.empty()) {
          std::fprintf(pImpl->out_fp, "\nError Breakdown by TID:\n");
          for (const auto& [tid, count] : stats.errorCountsByTid) {
            std::fprintf(pImpl->out_fp, "  TID %-36d : %zu\n", tid, count);
          }
        }
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
