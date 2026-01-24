#include "markdown_log_writer.h"
#include "log_processor.h" // For LogStats if needed
#include <iostream>
#include <iomanip>

MarkdownLogWriter::MarkdownLogWriter(const std::string& path) : ofs_(path) {
    if (!ofs_) {
        std::cerr << "Failed to open Markdown report file: " << path << "\n";
    } else {
        writeHeader();
    }
}

MarkdownLogWriter::~MarkdownLogWriter() {
    writeFooter();
}

void MarkdownLogWriter::writeHeader() {
    ofs_ << "# Valgrind Analysis Report\n\n";
    ofs_ << "| Type | Search | Details |\n";
    ofs_ << "|---|---|---|\n";
}

void MarkdownLogWriter::writeFooter() {
    if (footerWritten_ || !ofs_.is_open()) return;
    footerWritten_ = true;
}

void MarkdownLogWriter::writeEntry(const LogEntry& entry) {
    if (!ofs_.is_open()) return;

    // Use <details> for stack trace to keep table clean
    // Columns: Type | key info | details
    
    std::string type = escape(entry.errorType);
    std::string pid = std::to_string(entry.pid) + (entry.tid ? ":" + std::to_string(*entry.tid) : "");
    
    ofs_ << "| **" << type << "** | " << pid << " | ";
    
    // Stack trace in details
    ofs_ << "<details><summary>Stack Trace</summary><br><pre>";
    if (!entry.sourceContext.empty()) {
        ofs_ << "\\n--- Source Context ---\\n";
        for (const auto& line : entry.sourceContext) {
            ofs_ << escape(line) << "\\n";
        }
    }
    for (const auto& line : entry.stackTrace) {
        ofs_ << escape(line) << "\\n";
    }
    // Also print raw content if needed?
    ofs_ << "</pre></details> |\n";
}

void MarkdownLogWriter::writeRaw(const std::string& content) {
    if (!ofs_.is_open()) return;
    ofs_ << "<!-- " << escape(content) << " -->\n";
}

void MarkdownLogWriter::writeStats(const LogStats& stats) {
    if (!ofs_.is_open()) return;

    // Add stats summary section
    ofs_ << "\n## Statistics\n\n";
    ofs_ << "- **Lines Processed**: " << stats.linesRead << "\n";
    ofs_ << "- **Blocks Found**: " << stats.blocksFound << "\n";
    ofs_ << "- **Unique Errors**: " << stats.uniqueBlocks << "\n";
    
    footerWritten_ = true;
}

void MarkdownLogWriter::setUseColor(bool /*enable*/) { /* No-op */ }
void MarkdownLogWriter::writeStatsJson(const LogStats& /*stats*/, const std::string& /*path*/) const { /* No-op */ }

void MarkdownLogWriter::flush() {
    if (ofs_.is_open()) ofs_.flush();
}

void MarkdownLogWriter::writeDiffSummary(const DiffEngine::DiffStats& stats) {
    if (!ofs_.is_open()) return;
    
    ofs_ << "\n## Diff Summary\n\n";
    ofs_ << "| Category | Count | Rate |\n";
    ofs_ << "|---|---|---|\n";
    ofs_ << "| New Errors | " << stats.totalNew << " | " << std::fixed << std::setprecision(1) << stats.regressionRate << "% |\n";
    ofs_ << "| Fixed Errors | " << stats.totalFixed << " | " << stats.fixRate << "% |\n";
    ofs_ << "| Common Errors | " << stats.totalCommon << " | - |\n";
}

std::string MarkdownLogWriter::escape(std::string_view s) const {
    std::string res;
    res.reserve(s.size());
    for (char c : s) {
        // Markdown escaping: escape pipe | and backtick ` and others?
        // Basic escaping for table cell protection.
        if (c == '|') res += "&#124;"; // HTML entity for pipe
        else if (c == '<') res += "&lt;";
        else if (c == '>') res += "&gt;";
        else if (c == '\n') res += "<br>"; // Newline in table?
        else if (c == '\r') {} // Ignore
        else res += c;
    }
    return res;
}
