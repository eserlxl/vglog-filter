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
// constexpr size_t MATCH_BYTES_HEAD_LEN = 10; // " bytes in "
// constexpr size_t MATCH_BLOCKS_LEN = 7;      // " blocks"
constexpr size_t RESERVE_LINE_SIZE = 1024;
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

LogProcessor::LogProcessor(const Options& options, std::unique_ptr<ILogWriter> logWriter)
    : opt(options), filter(options.filter), stats{},
      writer(logWriter ? std::move(logWriter)
                    : std::unique_ptr<ILogWriter>(std::make_unique<LogWriter>(options))) {
  seen.reserve(RESERVE_SIZE_SEEN);
  pendingBlocks.reserve(opt.streamMode ? RESERVE_SIZE_PENDING : 0);

  
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

  auto pidOpt = parser->extractPid(line); // Returns optional<int32_t>
  int32_t currentLinePid = pidOpt.value_or(0);

  if (parser->isBlockStart(line)) {
    flush();
    if (raw.empty()) {
      pendingPid = currentLinePid;
    }
  }

  if (raw.empty() && pendingPid == 0 && currentLinePid != 0) {
    pendingPid = currentLinePid;
  }

  if (!parser->isRelevant(line))
    return;

  std::string sline(line);
  auto rawLine = parser->cleanRaw(sline);
  if (trim_view(rawLine).empty())
    return;

  raw.append(rawLine).push_back('\n');
}




void LogProcessor::flush() {
  logDebug("Flushing...");
  if (raw.empty()) {
    clearCurrentState();
    return;
  }

  RawBlock rb;
  rb.content = std::move(raw);
  rb.pid = pendingPid;

  validateBlockSize(rb.content.size());
  
  // Note: blocksFound is incremented for every flushed block candidate, before filtering
  stats.blocksFound++;

  ProcessedResult res = processBlock(std::move(rb));
  finalizeResult(res);

  clearCurrentState();
}

// shouldKeepEntry removed (moved to LogFilter)



void LogProcessor::clearCurrentState() noexcept {
  raw.clear();

  pendingPid = 0;
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
  size_t currentLineNum = 0;
  std::string line;
  
  RawBlock currentBlock;
  int32_t pendingPidForBlock = 0;
  
  auto flushBlock = [&]() {
      if (currentBlock.content.empty()) return;
      
      if (currentBlock.pid == 0) currentBlock.pid = pendingPidForBlock;
      
      auto blockCopy = std::move(currentBlock); 
      currentBlock = RawBlock{};
      
      threadPool->enqueue([this, b = std::move(blockCopy)]() mutable {
          ProcessedResult res = this->processBlock(std::move(b));
          
          {
              std::unique_lock<std::mutex> lock(resultMutex);
              resultQueue.push(std::move(res));
          }
          resultCv.notify_one();
      });
  };

  while (std::getline(in, line)) {
      currentLineNum++;
      validateLineLength(line);
      
      auto pidOpt = parser->extractPid(line);
      int32_t linePid = pidOpt.value_or(0);
      
      if (signalHandler::isStopRequested()) break;

      if (parser->isBlockStart(line)) {
          flushBlock();
          if (currentBlock.content.empty()) {
              pendingPidForBlock = linePid;
          }
      }
      
      if (currentBlock.content.empty() && pendingPidForBlock == 0 && linePid != 0) {
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
  flushBlock(); 
  
  threadPool.reset(); 
  
  while (!resultQueue.empty()) {
      auto& res = resultQueue.front();
      stats.blocksFound++; 
      finalizeResult(res);
      resultQueue.pop();
  }
}

LogProcessor::ProcessedResult LogProcessor::processBlock(RawBlock&& block) {
  ProcessedResult res;
  res.kept = false;
  res.error = false;
  
  try {
    LogEntry entry = parser->parseBlock(block.content);
    if (entry.pid == 0) {
      entry.pid = block.pid;
    }

    if (opt.strictMode && (entry.pid == 0 || entry.errorType.empty())) {
       throw std::runtime_error("Strict mode: Failed to parse valid Valgrind entry from block");
    }

    // Generate Signature (Stateless)
    std::string signature;
    if (opt.depth > 0) {
        size_t count = 0;
        for (const auto& traceLine : entry.stackTrace) {
            if (count++ >= static_cast<size_t>(opt.depth)) break;
            signature.append(parser->scrubLine(traceLine)).push_back('\n');
        }
        if (signature.empty()) signature = entry.errorType;
    } else {
        for (const auto& traceLine : entry.stackTrace) {
            signature.append(parser->scrubLine(traceLine)).push_back('\n');
        }
        if (signature.empty()) signature = entry.errorType; 
    }
    entry.signature = signature;

    if (filter.shouldKeep(entry)) {
        res.kept = true;
    }

    res.entry = std::move(entry);

  } catch (const std::exception& e) {
      logDebug(std::string("Error processing block: ") + e.what());
      res.error = true;
      if (opt.strictMode) throw; 
  }

  return res;
}

void LogProcessor::finalizeResult(ProcessedResult& res) {
  if (res.error) {
      stats.parseErrors++; 
      return; 
  }
  
  if (!res.kept) {
      stats.filteredCount++;
      return;
  }
  
  bool isUnique = seen.insert(res.entry.signature).second;
  if (isUnique) {
      stats.uniqueBlocks++;
  }
  
  if (isUnique) {
      stats.errorCounts[res.entry.errorType]++;
      if (res.entry.pid != 0) {
          stats.errorCountsByPid[res.entry.pid]++;
      }
      if (res.entry.tid.has_value()) {
          stats.errorCountsByTid[*res.entry.tid]++;
      }
  }

  if (isUnique || !opt.uniqueOutput) {
    if (opt.streamMode) {
      validatePendingBlocksCount(pendingBlocks.size());
      pendingBlocks.emplace_back(std::move(res.entry));
    } else {
      if (opt.contextLines > 0 && !res.entry.stackFrames.empty()) {
          const auto& frame = res.entry.stackFrames[0];
          if (!frame.location.empty()) {
              auto colonPos = frame.location.find_last_of(':');
              if (colonPos != std::string::npos) {
                  std::string file = frame.location.substr(0, colonPos);
                  int lineNum = 0;
                  try {
                      lineNum = std::stoi(frame.location.substr(colonPos + 1));
                  } catch (...) {}
                  
                  if (lineNum > 0) {
                       res.entry.sourceContext = sourceLoader.loadContext(file, lineNum, opt.contextLines);
                  }
              }
          }
      }
      
      writer->writeEntry(res.entry);
    }
  }
}

