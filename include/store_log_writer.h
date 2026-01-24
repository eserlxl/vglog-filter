// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include "log_entry.h"
#include <vector>

/**
 * @brief Accumulates LogEntry objects in memory.
 * 
 * Used for multi-pass analysis like Diff Generation.
 * Does NOT perform file I/O or JSON formatting.
 */
class StoreLogWriter : public ILogWriter {
public:
    void writeEntry(const LogEntry& entry) override;
    void writeRaw(const std::string& content) override;
    void writeStats(const LogStats& stats) override;
    void setUseColor(bool enable) override;
    void writeStatsJson(const LogStats& stats, const std::string& path) const override;
    void flush() override;

    [[nodiscard]] const std::vector<LogEntry>& getEntries() const;

private:
    std::vector<LogEntry> entries_;
};
