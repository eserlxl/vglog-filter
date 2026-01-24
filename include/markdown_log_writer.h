#pragma once

#include "ilog_writer.h"
#include "diff_engine.h"
#include <fstream>
#include <string>

class MarkdownLogWriter : public ILogWriter {
public:
    explicit MarkdownLogWriter(const std::string& path);
    ~MarkdownLogWriter() override;

    void writeEntry(const LogEntry& entry) override;
    void writeRaw(const std::string& content) override;
    void writeStats(const LogStats& stats) override;
    void setUseColor(bool enable) override;
    void writeStatsJson(const LogStats& stats, const std::string& path) const override;
    void flush() override;
    void writeDiffSummary(const DiffEngine::DiffStats& stats) override;

private:
    void writeHeader();
    void writeFooter();
    std::string escape(std::string_view s) const;

    std::ofstream ofs_;
    bool footerWritten_ = false;
};
