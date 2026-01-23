#pragma once

#include "log_entry.h"
// Forward declare LogStats

struct LogStats;

#include <cstdio>
#include <string>

class ILogWriter {
public:
  virtual ~ILogWriter() = default;

  virtual void writeEntry(const LogEntry& entry) = 0;
  virtual void writeStats(const LogStats& stats) = 0;
  virtual void writeStatsJson(const LogStats& stats, const std::string& filename) const = 0;
};
