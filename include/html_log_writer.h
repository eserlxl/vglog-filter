// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include "options.h"
#include "diff_engine.h"
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

    struct DiffStats; // Forward decl not enough if we need type, but DiffStats is in diff_engine.h. 
                      // We need to include diff_engine.h or use forward decl if possible.
                      // Given DiffEngine::DiffStats is a nested struct, forward declaring it is tricky in C++.
                      // Easier to include diff_engine.h in header or use void* (bad).
                      // We'll perform include of diff_engine.h in the header.

    void writeDiffSummary(const DiffEngine::DiffStats& stats);

private:
    void writeHeader();
    void writeFooter();
    std::string escape(std::string_view s) const;

    std::ofstream ofs_;
    bool footerWritten_ = false;
};
