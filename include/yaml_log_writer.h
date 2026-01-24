// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include <memory>
#include <string>

class YamlLogWriter : public ILogWriter {
public:
  explicit YamlLogWriter(const std::string& filename);
  ~YamlLogWriter() override;

  void writeEntry(const LogEntry& entry) override;
  void writeRaw(const std::string& raw) override;
  void writeStats(const LogStats& stats) override;
  void setUseColor(bool useColor) override;
  void writeStatsJson(const LogStats& stats, const std::string& path) const override;
  void flush() override;
  void writeDiffSummary(const DiffEngine::DiffStats& stats) override;

private:
  std::unique_ptr<std::ostream> out;
  std::string filename;
};
