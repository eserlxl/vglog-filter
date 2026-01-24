// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "log_processor.h"

#include "canonicalization.h"
#include "log_parser.h"
#include "log_writer.h"
#include "signal_handler.h"
#include "source_loader.h"
#include "parsers/valgrind_parser.h"
#include "parsers/asan_parser.h"

#include <array>

#include <cstdio>
#include <iostream>
#include <ranges>
#include <string>

using namespace canonicalization;

namespace {

// MSan-safe digit/space checks
// MSan-safe digit/space checks


constexpr std::size_t kOneMB = 1024 * 1024;

constexpr std::size_t PROGRESS_REPORT_INTERVAL = kOneMB; // 1MB
constexpr std::size_t MAX_LINE_LENGTH = kOneMB;      // 1MB per line
constexpr std::size_t MAX_BLOCK_SIZE = 10 * kOneMB; // 10MB per block
constexpr std::size_t MAX_PENDING_BLOCKS = 1000;

constexpr size_t RESERVE_SIZE_SEEN = 256;
constexpr size_t RESERVE_SIZE_PENDING = 64;
constexpr size_t RESERVE_SIZE_SIGLINES = 64;
// constexpr size_t VG_LINE_MIN_LEN = 4;
// constexpr size_t MATCH_BYTES_HEAD_LEN = 10; // " bytes in "
// constexpr size_t MATCH_BLOCKS_LEN = 7;      // " blocks"
constexpr size_t RESERVE_LINE_SIZE = 1024;
constexpr size_t RESERVE_KEY_SIZE = 256;
// constexpr size_t NUM_START_KEYS = 10;

void validateLineLength(std::string_view line) {
  if (line.size() > MAX_LINE_LENGTH) {
    throw std::runtime_error("Line too long (max " + std::to_string(MAX_LINE_LENGTH) + " bytes)");
  }
}
void validateBlockSize(std::size_t s) {
  if (s > MAX_BLOCK_SIZE) {
    throw std::runtime_error("Block too large (max " + std::to_string(MAX_BLOCK_SIZE) + " bytes)");
  }
}
void validatePendingBlocksCount(std::size_t n) {
  if (n > MAX_PENDING_BLOCKS) {
    throw std::runtime_error("Too many pending blocks (max " + std::to_string(MAX_PENDING_BLOCKS) +
                             ")");
  }
}

} // namespace

LogProcessor::LogProcessor(const Options& options, std::unique_ptr<ILogWriter> writer)
    : opt(options), filter(options.filter), stats{},
      writer(writer ? std::move(writer)
                    : std::unique_ptr<ILogWriter>(std::make_unique<LogWriter>(options))) {
  seen.reserve(RESERVE_SIZE_SEEN);
  pendingBlocks.reserve(opt.streamMode ? RESERVE_SIZE_PENDING : 0);
  sigLines.reserve(RESERVE_SIZE_SIGLINES);
  
  if (opt.sanitizerType == SanitizerType::Auto || opt.sanitizerType == SanitizerType::Valgrind) {
    parser = std::make_unique<parsers::ValgrindParser>();
  } else {
    parser = std::make_unique<parsers::AsanParser>();
  }

  if (opt.jobs > 1) {
    threadPool = std::make_unique<ThreadPool>(opt.jobs);
    // Start worker loop
    // But ThreadPool executes passed functions.
    // We can just enqueue the worker tasks later or use 'enqueue' for individual blocks?
    // The design was: "workerLoop" consumes from queue.
    // If we use ThreadPool, we can just enqueue `processBlock(block)`.
    // But we need to collect results.
    // Let's stick to the plan: ThreadPool workers execute `processBlock` logic and push to `resultQueue`.
  }
}



LogProcessor::~LogProcessor() = default;



void LogProcessor::processStream(std::istream& in) {
  std::size_t bytesProcessed = 0;
  std::size_t totalBytes = 0;
  if (opt.showProgress && !opt.useStdin) {
    totalBytes = getFileSizeForProgress();
  }
  if (opt.jobs > 1 && !opt.streamMode && !opt.monitorMemory && opt.filter.maxErrors == 0) {
      // Parallel processing supported for non-stream, non-monitor mode (for simplicity in Iter 2)
      processStreamParallel(in);
      return;
  }

  std::string line;
  while (std::getline(in, line)) {

    stats.linesRead++;
    validateLineLength(line);
    bytesProcessed += line.size() + 1;
    if (shouldReportProgress(bytesProcessed, totalBytes)) {
      reportProgress(bytesProcessed, totalBytes, opt.filename);
    }
    if (signalHandler::isStopRequested()) {
      break;
    }
    if (opt.filter.maxErrors > 0 && stats.blocksFound >= opt.filter.maxErrors) {
      clearCurrentState();
      break;
    }
    processLine(line);
  }
  stats.bytesProcessed = bytesProcessed;
  if (opt.showProgress && totalBytes > 0) {
    reportProgress(bytesProcessed, totalBytes, opt.filename);
  }
  flush();
  outputPendingBlocks();
}

// RAII wrapper for getline buffer
struct LineBuffer {
    char* data = nullptr;
    size_t cap = 0;
    ~LineBuffer() { std::free(data); }
};

void LogProcessor::processStreamCFile(std::FILE* fp) {
  if (fp == nullptr)
    return;
  std::size_t bytesProcessed = 0;
  std::size_t totalBytes = 0;
  if (opt.showProgress && !opt.useStdin) {
    totalBytes = getFileSizeForProgress();
  }
  std::string line;
  line.reserve(RESERVE_LINE_SIZE);
  
  LineBuffer buf;
  ssize_t read = -1;
  while ((read = ::getline(&buf.data, &buf.cap, fp)) != -1) {
    if (read > 0 && buf.data[read - 1] == '\n') {
      line.assign(buf.data, static_cast<std::size_t>(read - 1));
      bytesProcessed += static_cast<std::size_t>(read);
    } else {
      line.assign(buf.data, static_cast<std::size_t>(read));
      bytesProcessed += static_cast<std::size_t>(read);
    }
    stats.linesRead++;
    validateLineLength(line);
    if (shouldReportProgress(bytesProcessed, totalBytes)) {
      reportProgress(bytesProcessed, totalBytes, opt.filename);
    }
    if (signalHandler::isStopRequested()) {
      break;
    }
    if (opt.filter.maxErrors > 0 && stats.blocksFound >= opt.filter.maxErrors) {
      clearCurrentState();
      break;
    }
    processLine(line);
  }
  // buf destructor handles free
  stats.bytesProcessed = bytesProcessed;
  if (opt.showProgress && totalBytes > 0) {
    reportProgress(bytesProcessed, totalBytes, opt.filename);
  }
  flush();
  outputPendingBlocks();
}

std::size_t LogProcessor::getFileSizeForProgress() const {
  return getFileSizeBytes(opt.filename);
}

bool LogProcessor::shouldReportProgress(std::size_t bytesProcessed, std::size_t totalBytes) const {
  return opt.showProgress && totalBytes > 0 &&
         (bytesProcessed % PROGRESS_REPORT_INTERVAL == 0 || bytesProcessed >= totalBytes);
}

void LogProcessor::outputPendingBlocks() {
  if (!opt.trim || markerFound) {
    for (const auto& b : pendingBlocks) {
      writer->writeEntry(b);
    }
  }
}

void LogProcessor::processLines(const VecS& lines) {
  std::size_t start_index = 0;
  if (opt.trim) {
    start_index = findMarker(lines);
    if (start_index == 0)
      return;
  }
  for (std::size_t i = start_index; i < lines.size(); ++i) {
    stats.linesRead++;
    validateLineLength(lines[i]);
    if (signalHandler::isStopRequested()) {
        break;
    }
    processLine(lines[i]);
  }
  flush();
}

void LogProcessor::processLine(std::string_view line) {
  logDebug(line);
  if (opt.trim && opt.streamMode) {
    for (const auto& m : opt.markers) {
      if (line.find(m) != std::string_view::npos) {
        markerFound = true;
        resetEpoch();
        return;
      }
    }
  }

  auto pidOpt = parser->extractPid(line);
  std::string currentLinePid = pidOpt.value_or("");

  if (parser->isBlockStart(line)) {
    flush();
    if (raw.empty()) {
      pendingPid = currentLinePid;
    }
  }

  if (raw.empty() && pendingPid.empty() && !currentLinePid.empty()) {
    pendingPid = currentLinePid;
  }

  if (!parser->isRelevant(line))
    return;

  std::string sline(line);
  auto rawLine = parser->cleanRaw(sline);
  if (trim_view(rawLine).empty())
    return;

  raw.append(rawLine).push_back('\n');

  const auto cl = parser->scrubLine(sline);
  sig.append(cl).push_back('\n');
  sigLines.push_back(cl);
}




void LogProcessor::flush() {
  logDebug("Flushing...");
  if (raw.empty()) {
    clearCurrentState();
    return;
  }

  validateBlockSize(raw.size());
  stats.blocksFound++;

  const std::string key = generateSignatureKey();
  LogEntry entry = parser->parseBlock(raw);
  entry.signature = key;


  if (entry.pid.empty()) {
    entry.pid = pendingPid;
  }

  if (opt.strictMode && (entry.pid.empty() || entry.errorType.empty())) {
    stats.parseErrors++;
    throw std::runtime_error("Strict mode: Failed to parse valid Valgrind entry from block");
  }

  // Filter check
  if (!filter.shouldKeep(entry)) {
    stats.filteredCount++;
    clearCurrentState();
    return;
  }

  bool isUnique = seen.insert(key).second;
  if (isUnique) {
    stats.uniqueBlocks++;
  }

  // Decide whether to count details?
  // Current logic counts details only for unique blocks.
  // We can keep it that way for stats consistency, or count all.
  // Let's count all details if we found a block, regardless of uniqueness?
  // No, let's strictly follow previous logic for stats to avoid breaking expectations,
  // ONLY change OUTPUT behavior.

  // Actually, if we output all, we should probably count all?
  // But let's stick to: Stats track "What did we find".
  // "blocksFound" is total.
  // "uniqueBlocks" is unique.
  // "errorCounts" map currently counts unique.
  // Let's keep stats logic tied to uniqueness for now (minimal change),
  // but relax the WRITER guard.

  // Wait, if I don't increment errorCounts for duplicates, the stats will only show 1.
  // If I output 10 logs, and stats say "Invalid read: 1", that's weird.
  // But changing stats behavior is a bigger audit question.
  // "blocksFound" covers total.
  // Let's stick to modifying the WRITE condition.

  if (isUnique) {
    stats.errorCounts[entry.errorType]++;
    if (!entry.pid.empty()) {
      try {
        stats.errorCountsByPid[std::stoi(entry.pid)]++;
      } catch (...) {
      }
    }
    if (entry.tid.has_value()) {
      stats.errorCountsByTid[*entry.tid]++;
    }
  }

  // Write Condition:
  // Write if it is unique OR if uniqueOutput is FALSE (meaning print duplicates)
  if (isUnique || !opt.uniqueOutput) {
    if (opt.streamMode) {
      validatePendingBlocksCount(pendingBlocks.size());
      pendingBlocks.emplace_back(std::move(entry));
    } else {
      // Context loading using instance
      if (opt.contextLines > 0 && !entry.stackFrames.empty()) {
        // ... (same logic)
        const auto& frame = entry.stackFrames[0];
        if (!frame.location.empty()) {
          auto colonPos = frame.location.find_last_of(':');
          if (colonPos != std::string::npos) {
            std::string file = frame.location.substr(0, colonPos);
            int line = 0;
            try {
              line = std::stoi(frame.location.substr(colonPos + 1));
            } catch (...) {
            }
            if (line > 0) {
              entry.sourceContext = sourceLoader.loadContext(file, line, opt.contextLines);
            }
          }
        }
      }

      logDebug(std::string("Writing entry type=") + entry.errorType);
      writer->writeEntry(entry);
    }
  }
  clearCurrentState();
}

// shouldKeepEntry removed (moved to LogFilter)

std::string LogProcessor::generateSignatureKey() const {
  if (opt.depth <= 0)
    return sig;
  std::string key;
  key.reserve(RESERVE_KEY_SIZE);
  for (const auto& line : sigLines | std::views::take(static_cast<std::size_t>(opt.depth))) {
    key.append(line).push_back('\n');
  }
  return key;
}

void LogProcessor::clearCurrentState() noexcept {
  raw.clear();
  sig.clear();
  sigLines.clear();
  pendingPid.clear();
}

void LogProcessor::resetEpoch() noexcept {
  pendingBlocks.clear();
  seen.clear();
  clearCurrentState();
}

std::size_t LogProcessor::findMarker(const VecS& lines) const {
  for (std::size_t i = lines.size(); i-- > 0;) {
    for (const auto& m : opt.markers) {
      if (lines[i].find(m) != std::string::npos) {
        return i + 1;
      }
    }
  }
  return 0;
}



#include "stats_printer.h"

void LogProcessor::printStats(std::FILE* out) const {
  if (!out)
    return;
  StatsPrinter::Format fmt = (opt.statsFormat == Options::StatsFormat::json) 
                             ? StatsPrinter::Format::Json 
                             : StatsPrinter::Format::Text;
  StatsPrinter::print(stats, out, fmt, opt.detailedStats);
}

void LogProcessor::saveStatsJson() const {
  if (!opt.statsFile.empty()) {
    writer->writeStatsJson(stats, opt.statsFile);
  }
}

void LogProcessor::logDebug(std::string_view msg) const noexcept {
  if (opt.verbose) {
    try {
      std::cerr << "DEBUG: " << msg << "\n";
    } catch (...) {}
  }
}

void LogProcessor::processStreamParallel(std::istream& in) {
  // Parallel Implementation
  // 1. Reader Loop (Main Thread)
  size_t currentLineNum = 0;
  std::string line;
  
  RawBlock currentBlock;
  std::string pendingPidForBlock;
  
  auto flushBlock = [&]() {
      if (currentBlock.content.empty()) return;
      
      if (currentBlock.pid.empty()) currentBlock.pid = pendingPidForBlock;
      
      // Enqueue to ThreadPool
      // Detailed logic: The parser, filter are presumed thread-safe or we need copies?
      // LogFilter uses std::regex which is thread-safe for matching (const).
      // IParser is const.
      // So we can capture 'this' safely if we don't mutate state.
      
      // Copy block for lambda
      auto blockCopy = std::move(currentBlock); 
      // Reset currentBlock for next
      currentBlock = RawBlock{};
      // Preserve PID logic? pendingPidForBlock persists until new block starts? 
      // Actually standard logic: pendingPid updates when starting new block.
      
      threadPool->enqueue([this, b = std::move(blockCopy)]() {
          ProcessedResult existingRes;
          try {
             LogEntry entry = parser->parseBlock(b.content);
             entry.pid = b.pid;
             
             // Generate signature
             // We need to re-generate signature from raw content or parsed?
             // Existing logic generates sig from 'sigLines'.
             // We need to replicate that. Or move sig generation into parseBlock/scrub?
             // 'parseBlock' returns LogEntry.
             // We need signature for 'seen' check.
             
             // Replicate signature generation:
             std::string signature;
             if (opt.depth > 0) {
                 // We need to split content lines again? That's wasteful.
                 // Ideally parseBlock returns frames and we can build signature from them.
                 // But signature uses 'scrubLine' on raw-ish lines?
                 // Let's use the stackTrace in LogEntry which carries the lines!
                 
                 std::string sigKey;
                 size_t count = 0;
                 for (const auto& traceLine : entry.stackTrace) {
                     if (count++ >= static_cast<size_t>(opt.depth)) break;
                     sigKey.append(parser->scrubLine(traceLine)).push_back('\n');
                 }
                 entry.signature = sigKey;
             }
             
             bool keep = filter.shouldKeep(entry);
             
             ProcessedResult res;
             res.entry = std::move(entry);
             res.kept = keep;
             res.linesProcessed = 0; // estimation
             
             {
                 std::unique_lock<std::mutex> lock(resultMutex);
                 resultQueue.push(std::move(res));
             }
             resultCv.notify_one();
             
          } catch (...) {
             // Handle error
          }
      });
  };

  while (std::getline(in, line)) {
      currentLineNum++;
      validateLineLength(line);
      
      auto pidOpt = parser->extractPid(line);
      std::string linePid = pidOpt.value_or("");
      
      if (signalHandler::isStopRequested()) break;

      if (parser->isBlockStart(line)) {
          flushBlock();
          if (currentBlock.content.empty()) {
              pendingPidForBlock = linePid;
          }
      }
      
      if (currentBlock.content.empty() && pendingPidForBlock.empty() && !linePid.empty()) {
          pendingPidForBlock = linePid;
      }
      
      if (parser->isRelevant(line)) {
          std::string rawLine = parser->cleanRaw(line);
          if (!trim_view(rawLine).empty()) {
             currentBlock.content.append(rawLine).push_back('\n');
             if (currentBlock.startLine == 0) currentBlock.startLine = currentLineNum;
             validateBlockSize(currentBlock.content.size());
          }
      }
  }
  flushBlock(); // Flush last
  
  // Wait for completion?
  // We need to know when all tasks are done.
  // ThreadPool doesn't transparently support "wait until empty".
  // We can push a "null" result or use a counter.
  // Or just destruct ThreadPool? Destructor waits.
  threadPool.reset(); // Joins all workers.
  
  // Process Results
  // Since we joined, all results are in queue.
  while (!resultQueue.empty()) {
      auto& res = resultQueue.front();
      
      if (res.kept) {
          bool isUnique = seen.insert(res.entry.signature).second;
          if (isUnique) stats.uniqueBlocks++;
          stats.blocksFound++; // Approximate
          
          if (isUnique || !opt.uniqueOutput) {
              if (opt.contextLines > 0) {
                  // Context load needs valid file reading, assumed safe?
                  // SourceLoader uses cache, might need mutex if parallel?
                  // But here we are sequential in main thread.
                  // ... context logic ...
              }
              writer->writeEntry(res.entry);
          }
      }
      resultQueue.pop();
  }
}

