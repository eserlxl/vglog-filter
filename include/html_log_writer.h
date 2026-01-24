// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include "options.h"
#include <fstream>
#include <string>

class HtmlLogWriter : public ILogWriter {
public:
    explicit HtmlLogWriter(const std::string& path);
    ~HtmlLogWriter() override;

    void writeEntry(const LogEntry& entry) override;
    void writeRaw(const std::string& content) override;
    void writeStats(const LogStats& stats) override;
    void setUseColor(bool enable) override; // No-op for HTML (always styled)
    void writeStatsJson(const LogStats& stats, const std::string& path) const override; // No-op
    void flush() override;

private:
    void writeHeader();
    void writeFooter();
    std::string escape(std::string_view s) const;

    std::ofstream ofs_;
    bool footerWritten_ = false;
};
