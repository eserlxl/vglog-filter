// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_writer.h"
#include "file_utils.h"
#include "json_utils.h"

#include <filesystem>
#include <iostream>

struct LogWriter::Impl {
  const Options& opt;
  std::FILE* out_fp{stdout};
  std::shared_ptr<void> file_handle_lifetime;

  explicit Impl(const Options& options) : opt(options) {
    if (!opt.output_file.empty()) {
      open_file(opt.output_file);
    }
  }

  void open_file(const std::string& path) {
    auto fh = std::make_shared<FileHandle>(path.c_str(), "w");
    out_fp = fh->get();
    file_handle_lifetime = std::static_pointer_cast<void>(fh);
  }

  void rotate_log() {
    if (opt.output_file.empty()) {
      return;
    }

    // Close current file
    file_handle_lifetime.reset();
    out_fp = nullptr;

    namespace fs = std::filesystem;
    std::error_code ec;

    // Shift backups
    for (size_t i = opt.rotate_backups; i > 0; --i) {
      std::string old_name =
          (i == 1) ? opt.output_file : (opt.output_file + "." + std::to_string(i - 1));
      std::string new_name = opt.output_file + "." + std::to_string(i);

      if (fs::exists(old_name, ec)) {
        fs::rename(old_name, new_name, ec);
      }
    }

    // Reopen
    open_file(opt.output_file);
  }

  void check_rotation(size_t additional_bytes) {
    if (opt.rotate_size_mb > 0 && out_fp && !opt.output_file.empty()) {
      long pos = std::ftell(out_fp);
      if (pos >= 0 &&
          static_cast<size_t>(pos) + additional_bytes > opt.rotate_size_mb * 1024 * 1024) {
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

  void format_json(const LogEntry& entry, std::string& buffer) {
    buffer = "{\"type\":\"record\"";
    buffer += ",\"raw\":\"" + json_utils::escape_string(entry.raw_content) + "\"";
    buffer += ",\"signature\":\"" + json_utils::escape_string(entry.signature) + "\"";

    if (opt.detailed_json) {
      if (!entry.error_type.empty()) {
        buffer += ",\"error_type\":\"" + json_utils::escape_string(entry.error_type) + "\"";
      }
      if (!entry.pid.empty()) {
        buffer += ",\"pid\":\"" + json_utils::escape_string(entry.pid) + "\"";
      }
      if (!entry.stack_trace.empty()) {
        buffer += ",\"stack_trace\":[";
        for (size_t i = 0; i < entry.stack_trace.size(); ++i) {
          if (i > 0)
            buffer += ",";
          buffer += "\"" + json_utils::escape_string(entry.stack_trace[i]) + "\"";
        }
        buffer += "]";
      }
    }
    buffer += "}\n";
  }
};

LogWriter::LogWriter(const Options& options) : pImpl(std::make_unique<Impl>(options)) {}

LogWriter::~LogWriter() = default;

LogWriter::LogWriter(LogWriter&&) noexcept = default;
LogWriter& LogWriter::operator=(LogWriter&&) noexcept = default;

void LogWriter::write_entry(const LogEntry& entry) {
  if (pImpl->opt.json_output) {
    std::string json;
    json.reserve(entry.raw_content.size() + 128); // heuristic
    pImpl->format_json(entry, json);
    pImpl->write_data(json.data(), json.size());
  } else {
    pImpl->write_data(entry.raw_content.data(), entry.raw_content.size());
    // Raw content usually ends with newline, but ensure one if we're separating blocks?
    // The original code did `write_output('\n');` after content.
    // Let's stick to original behavior but check if content has newline.
    // Original code: write_output(b.raw_content.data(), b.raw_content.size()); write_output('\n');
    pImpl->write_data("\n", 1);
  }
}

void LogWriter::write_raw(const std::string& content) {
  pImpl->write_data(content.data(), content.size());
}

void LogWriter::flush() {
  if (pImpl->out_fp) {
    std::fflush(pImpl->out_fp);
  }
}
