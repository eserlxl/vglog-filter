// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "html_log_writer.h"
#include "log_processor.h"
#include <iostream>
#include <iomanip>

HtmlLogWriter::HtmlLogWriter(const std::string& path) : ofs_(path) {
    if (!ofs_) {
        std::cerr << "Failed to open HTML report file: " << path << "\n";
    } else {
        writeHeader();
    }
}

HtmlLogWriter::~HtmlLogWriter() {
    writeFooter();
}

void HtmlLogWriter::writeHeader() {
    ofs_ << R"(<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Valgrind Log Report</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 20px; background: #f4f4f9; color: #333; }
h1 { color: #2c3e50; }
table { width: 100%; border-collapse: collapse; margin-top: 20px; background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; vertical-align: top; }
th { background-color: #f8f9fa; font-weight: 600; color: #555; }
tr:hover { background-color: #f1f1f1; }
.error-row { border-left: 5px solid #e74c3c; }
.leak-row { border-left: 5px solid #f39c12; }
.other-row { border-left: 5px solid #3498db; }
.stack { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 0.9em; white-space: pre-wrap; color: #444; }
.meta { font-size: 0.85em; color: #777; }
.badge { display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 0.8em; font-weight: bold; }
.badge-err { background: #fee; color: #c00; }
.badge-leak { background: #fff3cd; color: #856404; }
</style>
</head>
<body>
<h1>Valgrind Analysis Report</h1>
<table>
<thead>
<tr>
<th>Type</th>
<th>PID/TID</th>
<th>Stack Trace</th>
</tr>
</thead>
<tbody>
)";
}

void HtmlLogWriter::writeFooter() {
    if (footerWritten_ || !ofs_.is_open()) return;
    ofs_ << "</tbody></table></body></html>";
    footerWritten_ = true;
}

void HtmlLogWriter::writeEntry(const LogEntry& entry) {
    if (!ofs_.is_open()) return;

    std::string rowClass = "other-row";
    std::string badgeClass = "badge-info";
    
    // Simple heuristic for styling
    if (entry.errorType.find("Leak") != std::string::npos) {
        rowClass = "leak-row";
        badgeClass = "badge-leak";
    } else if (entry.errorType.find("Error") != std::string::npos || 
               entry.errorType.find("Invalid") != std::string::npos) {
        rowClass = "error-row";
        badgeClass = "badge-err";
    }

    ofs_ << "<tr class=\"" << rowClass << "\">\n";
    ofs_ << "<td><span class=\"badge " << badgeClass << "\">" << escape(entry.errorType) << "</span></td>\n";
    ofs_ << "<td class=\"meta\">PID: " << entry.pid << "<br>TID: ";
    if (entry.tid) ofs_ << *entry.tid;
    else ofs_ << "-";
    ofs_ << "</td>\n";
    
    ofs_ << "<td class=\"stack\">";
    if (!entry.stackFrames.empty()) {
        for (const auto& line : entry.stackTrace) {
             ofs_ << escape(line) << "\n";
        }
    } else {
        ofs_ << escape(entry.rawContent);
    }
    ofs_ << "</td>\n</tr>\n";
}

void HtmlLogWriter::writeRaw(const std::string& content) {
    if (!ofs_.is_open()) return;
    // Raw output not typically shown in table, maybe log as comment?
    ofs_ << "<!-- " << escape(content) << " -->\n";
}

void HtmlLogWriter::writeStats(const LogStats& stats) {
    if (!ofs_.is_open()) return;
    ofs_ << "</tbody></table>";
    
    // Add stats summary
    ofs_ << "<div style=\"margin-top: 30px; background: white; padding: 20px; border-radius: 5px;\">";
    ofs_ << "<h2>Statistics</h2>";
    ofs_ << "<p>Lines Processed: " << stats.linesRead << "</p>";
    ofs_ << "<p>Blocks Found: " << stats.blocksFound << "</p>";
    ofs_ << "<p>Unique Errors: " << stats.uniqueBlocks << "</p>";
    ofs_ << "</div>";
    
    ofs_ << "</body></html>";
    footerWritten_ = true;
}

void HtmlLogWriter::setUseColor(bool /*unused*/) { /* No-op */ }
void HtmlLogWriter::writeStatsJson(const LogStats& /*unused*/, const std::string& /*unused*/) const { /* No-op */ }

void HtmlLogWriter::flush() {
    if (ofs_.is_open()) ofs_.flush();
}

std::string HtmlLogWriter::escape(std::string_view s) const {
    std::string res;
    res.reserve(s.size());
    for (char c : s) {
        switch (c) {
            case '&': res += "&amp;"; break;
            case '<': res += "&lt;"; break;
            case '>': res += "&gt;"; break;
            case '"': res += "&quot;"; break;
            case '\'': res += "&#39;"; break;
            default: res += c; break;
        }
    }
    return res;
}

void HtmlLogWriter::writeDiffSummary(const DiffEngine::DiffStats& stats) {
    if (!ofs_.is_open()) return;
    
    // Inject summary before footer if possible, or just append if footer not written
    // But HTML structure matters. If we call this, we assume we want it inside BODY.
    // If footerWritten_ is true, we are outside body.
    
    ofs_ << R"(
<div class="summary-box" style="margin-top: 30px; background: white; padding: 20px; border-radius: 5px; border-left: 5px solid #6c5ce7;">
  <h3>Diff Summary</h3>
  <table style="width: auto;">
    <tr><th>Category</th><th>Count</th><th>Rate</th></tr>
)";
    
    auto row = [&](const char* label, size_t count, double rate) {
        ofs_ << "    <tr><td>" << label << "</td><td>" << count << "</td><td>" 
             << std::fixed << std::setprecision(1) << rate << "%</td></tr>\n";
    };

    row("New Errors", stats.totalNew, stats.regressionRate);
    row("Fixed Errors", stats.totalFixed, stats.fixRate);
    row("Common Errors", stats.totalCommon, 0.0);

    ofs_ << "  </table>\n</div>\n";
}
