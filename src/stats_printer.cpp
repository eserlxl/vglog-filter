#include "stats_printer.h"
#include <algorithm>
#include <vector>
#include <map>

void StatsPrinter::print(const LogStats& stats, std::FILE* out, Format format) {
  if (format == Format::Json) {
    printJson(stats, out);
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

void StatsPrinter::printJson(const LogStats& stats, std::FILE* out) {
  std::fprintf(out, "{\n");
  std::fprintf(out, "  \"linesRead\": %zu,\n", stats.linesRead);
  std::fprintf(out, "  \"bytesProcessed\": %zu,\n", stats.bytesProcessed);
  std::fprintf(out, "  \"blocksFound\": %zu,\n", stats.blocksFound);
  std::fprintf(out, "  \"uniqueBlocks\": %zu,\n", stats.uniqueBlocks);
  std::fprintf(out, "  \"filteredCount\": %zu,\n", stats.filteredCount);
  std::fprintf(out, "  \"parseErrors\": %zu,\n", stats.parseErrors);
  std::fprintf(out, "  \"errorCounts\": {\n");

  auto it = stats.errorCounts.begin();
  for (size_t i = 0; i < stats.errorCounts.size(); ++i, ++it) {
    std::fprintf(out, "    \"%s\": %zu%s\n", it->first.c_str(), it->second,
                 (i < stats.errorCounts.size() - 1) ? "," : "");
  }
  std::fprintf(out, "  },\n");
  
  std::fprintf(out, "  \"errorCountsByTid\": {\n");
  auto tid_it = stats.errorCountsByTid.begin();
  for (size_t i = 0; i < stats.errorCountsByTid.size(); ++i, ++tid_it) {
      std::fprintf(out, "    \"%d\": %zu%s\n", tid_it->first, tid_it->second,
                   (i < stats.errorCountsByTid.size() - 1) ? "," : "");
  }
  std::fprintf(out, "  }\n"); // End tid
  
  std::fprintf(out, "}\n");
}
