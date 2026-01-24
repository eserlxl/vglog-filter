#include "stats_printer.h"
#include <algorithm>
#include <vector>
#include <map>

#include "json/simple_json_builder.h"
#include "json_utils.h"

void StatsPrinter::print(const LogStats& stats, std::FILE* out, Format format, bool detailed) {
  if (format == Format::Json) {
    printJson(stats, out, detailed);
  } else {
    printText(stats, out);
  }
}

void StatsPrinter::printText(const LogStats& stats, std::FILE* out) {
  std::fprintf(out, "Valgrind Log Analysis Summary\n");
  std::fprintf(out, "=============================\n");
  std::fprintf(out, "Lines Read:      %zu\n", stats.linesRead);
  std::fprintf(out, "Bytes Processed: %zu\n", stats.bytesProcessed);
  std::fprintf(out, "Blocks Found:    %zu\n", stats.blocksFound);
  std::fprintf(out, "Unique Blocks:   %zu\n", stats.uniqueBlocks);
  std::fprintf(out, "Filtered Out:    %zu\n", stats.filteredCount);
  std::fprintf(out, "Parse Errors:    %zu\n", stats.parseErrors);
  std::fprintf(out, "\nError Counts by Type:\n");

  // Sort by count descending
  using Pair = std::pair<std::string, std::size_t>;
  std::vector<Pair> sorted_counts(stats.errorCounts.begin(), stats.errorCounts.end());
  std::sort(sorted_counts.begin(), sorted_counts.end(),
            [](const Pair& a, const Pair& b) { return a.second > b.second; });

  for (const auto& [type, count] : sorted_counts) {
    std::fprintf(out, "  %zu: %s\n", count, type.c_str());
  }
  
  if (!stats.errorCountsByTid.empty()) {
      std::fprintf(out, "\nError Counts by Thread ID:\n");
      std::map<int32_t, std::size_t> sorted_tids(stats.errorCountsByTid.begin(), stats.errorCountsByTid.end());
       for (const auto& [tid, count] : sorted_tids) {
            std::fprintf(out, "  TID %d: %zu\n", tid, count);
       }
  }
}

void StatsPrinter::printJson(const LogStats& stats, std::FILE* out, bool detailed) {
  json::Builder b;
  b.add("linesRead", static_cast<int64_t>(stats.linesRead));
  b.add("bytesProcessed", static_cast<int64_t>(stats.bytesProcessed));
  b.add("blocksFound", static_cast<int64_t>(stats.blocksFound));
  b.add("uniqueBlocks", static_cast<int64_t>(stats.uniqueBlocks));
  b.add("filteredCount", static_cast<int64_t>(stats.filteredCount));
  b.add("parseErrors", static_cast<int64_t>(stats.parseErrors));
  
  if (!stats.errorCounts.empty()) {
      b.startObject("errorCounts");
      for (const auto& [type, count] : stats.errorCounts) {
          b.add(type, static_cast<int64_t>(count));
      }
      b.endObject();
  }
  
  if (detailed) {
      if (!stats.errorCountsByTid.empty()) {
          b.startObject("errorCountsByTid");
          for (const auto& [tid, count] : stats.errorCountsByTid) {
               b.add(std::to_string(tid), static_cast<int64_t>(count));
          }
          b.endObject();
      }
       if (!stats.errorCountsByPid.empty()) {
          b.startObject("errorCountsByPid");
          for (const auto& [pid, count] : stats.errorCountsByPid) {
               b.add(std::to_string(pid), static_cast<int64_t>(count));
          }
          b.endObject();
      }
  }

  std::string s = b.str();
  std::fprintf(out, "%s\n", s.c_str());
}
