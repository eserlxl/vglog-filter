// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "cli_parser.h"
#include "config_loader.h"
#include "file_utils.h"
#include "json_utils.h"
#include "log_processor.h"
#include "options.h"
#include "path_validation.h"

#include "signal_handler.h"

#include <cstdio>
#include <exception>
#include <fstream>
#include <getopt.h> // For optind
#include <iostream>
#include <regex>
#include <sstream>
#include <string>
#include <string_view>

#include "composite_log_writer.h"
#include "html_log_writer.h"
#include "store_log_writer.h"
#include "diff_engine.h"

namespace {

inline constexpr auto STDIN_SENTINEL = std::string_view{"-"};

void setup_input_source(Options& opt, int argc, char* argv[]) {
  // ... (unchanged)
  if (optind >= argc) {
    opt.useStdin = true;
    opt.filename = std::string{STDIN_SENTINEL};
  } else {
    // Basic sanitization
    const char* arg = argv[optind];
    if (arg && std::string_view(arg) == STDIN_SENTINEL) {
        opt.useStdin = true;
        opt.filename = std::string{STDIN_SENTINEL};
    } else if (arg) {
       opt.filename = path_validation::sanitize_path_for_file_access(arg);
    }
  }
}

// Helper to load into a writer
void load_into_writer(Options optCopy, const std::string& input, ILogWriter& writer) {
    optCopy.uniqueOutput = true; // Force unique for diff
    // Don't show progress for internal loading
    optCopy.showProgress = false; 
    
    // We cannot move the writer into LogProcessor because we passed a reference.
    // So we use a wrapper or generic LogProcessor that accepts raw pointer?
    // LogProcessor takes unique_ptr.
    // Hack: LogProcessor only TAKES ownership.
    // Solution: Create LogProcessor with a "ProxyWriter" that forwards to our reference?
    // Or just change LogProcessor to take generic reference? It owns it.
    // Actually LogProcessor(Options, unique_ptr) is explicit.
    
    // Better: StoreLogWriter is cheap to move? No, vector.
    // But we need the RESULT back.
    // So we need to keep the pointer.
    
    // Let's make a "ReferenceLogWriter" that holds T& and implements ILogWriter.
    class ReferenceLogWriter : public ILogWriter {
        ILogWriter& ref_;
    public:
        explicit ReferenceLogWriter(ILogWriter& ref) : ref_(ref) {}
        void writeEntry(const LogEntry& e) override { ref_.writeEntry(e); }
        void writeRaw(const std::string& s) override { ref_.writeRaw(s); }
        void writeStats(const LogStats& s) override { ref_.writeStats(s); }
        void setUseColor(bool b) override { ref_.setUseColor(b); }
        void writeStatsJson(const LogStats& s, const std::string& p) const override { ref_.writeStatsJson(s, p); }
        void flush() override { ref_.flush(); }
    };
    
    auto proxy = std::make_unique<ReferenceLogWriter>(writer);
    LogProcessor processor(optCopy, std::move(proxy));
    
    if (input == STDIN_SENTINEL) {
        processor.processStreamCFile(stdin);
    } else {
        auto stream = openInputFile(input);
        processor.processStream(*stream);
    }
}

void processDiff(const Options& opt) {
    StoreLogWriter baselineWriter;
    std::cout << "Loading baseline: " << opt.diffBaseline << "...\n";
    try {
        load_into_writer(opt, opt.diffBaseline, baselineWriter);
    } catch (const std::exception& e) {
        std::cerr << "Error loading baseline: " << e.what() << "\n";
        return;
    }

    StoreLogWriter targetWriter;
    std::string targetInput = opt.filename; // From positional
    if (opt.inputFiles.size() > 0) targetInput = opt.inputFiles[0];
    
    std::cout << "Loading target: " << targetInput << "...\n";
    try {
        load_into_writer(opt, targetInput, targetWriter);
    } catch (const std::exception& e) {
        std::cerr << "Error loading target: " << e.what() << "\n";
        return;
    }

    std::cout << "Comparing...\n";
    auto result = DiffEngine::compare(baselineWriter.getEntries(), targetWriter.getEntries());

    std::cout << "\n=== Diff Report ===\n";
    std::cout << "Baseline: " << baselineWriter.getEntries().size() << " errors\n";
    std::cout << "Target:   " << targetWriter.getEntries().size() << " errors\n";
    std::cout << "-------------------\n";
    
    if (!result.newErrors.empty()) {
        std::cout << "NEW ERRORS (" << result.newErrors.size() << "):\n";
        for (const auto& e : result.newErrors) {
            std::cout << "  [" << e.errorType << "] " << e.pid << "/" << (e.tid ? std::to_string(*e.tid) : "-") << "\n";
            // Print top frame?
            if (!e.stackTrace.empty()) std::cout << "    " << e.stackTrace[0] << "\n";
        }
    } else {
        std::cout << "No new errors.\n";
    }
    
    if (!result.fixedErrors.empty()) {
        std::cout << "\nFIXED ERRORS (" << result.fixedErrors.size() << "):\n";
        for (const auto& e : result.fixedErrors) {
             std::cout << "  [" << e.errorType << "]\n";
        }
    }
}

void processInputFiles(Options& opt) {
  if (opt.inputFiles.empty()) {
    opt.inputFiles.push_back(opt.filename.empty() ? std::string(STDIN_SENTINEL) : opt.filename);
  }

  // Setup Writer(s)
  auto writer = std::make_unique<CompositeLogWriter>();
  // improved: always add default writer unless user explicitly suppressed standard output?
  // Current logic implies standard output is always desired unless specific flags set.
  writer->add(std::make_unique<LogWriter>(opt));

  if (!opt.htmlReport.empty()) {
      writer->add(std::make_unique<HtmlLogWriter>(opt.htmlReport));
  }

  // Create processor once to maintain stats/deduplication state across files
  LogProcessor processor(opt, std::move(writer));

  if (opt.monitorMemory) {
    reportMemoryUsage("starting processing", "all_inputs");
  }

  for (const auto& file : opt.inputFiles) {
    opt.filename = file; // Update for error messages/logging

    if (opt.useStdin || file == STDIN_SENTINEL) {
        processor.processStreamCFile(stdin);
    } else {
        try {
            auto stream = openInputFile(file); // Support .gz transparently
            processor.processStream(*stream);
        } catch (const std::exception& e) {
            std::cerr << "Error processing file " << file << ": " << e.what() << "\n";
            // Continue with next file? Or abort? 
            // Systems tool: usually continue but report error.
        }
    }
  }

  if (opt.monitorMemory) {
    reportMemoryUsage("completed processing", "all_inputs");
  }

  if (opt.showProgress || opt.monitorMemory) {
    processor.printStats(stderr);
  }
  processor.saveStatsJson();
}

} // namespace

void dump_config_to_file(const Options& opt, const std::string& path) {
  std::string json = "{\n";
  json += "  \"depth\": " + std::to_string(opt.depth) + ",\n";
  json += "  \"trim\": " + std::string(opt.trim ? "true" : "false") + ",\n";
  json += "  \"scrubRaw\": " + std::string(opt.scrubRaw ? "true" : "false") + ",\n";
  json += "  \"lines\": " + std::to_string(opt.contextLines) + ",\n";
  json += "  \"unique\": " + std::string(opt.uniqueOutput ? "true" : "false") + ",\n";
  json += "  \"jsonArray\": " + std::string(opt.jsonArray ? "true" : "false") + ",\n";
  json += "  \"maxErrors\": " + std::to_string(opt.filter.maxErrors) + ",\n";

  auto vec_to_json = [](const std::vector<std::string>& v) {
    std::string s = "[";
    for (size_t i = 0; i < v.size(); ++i) {
      if (i > 0)
        s += ",";
      s += "\"" + json_utils::escape_string(v[i]) + "\"";
    }
    s += "]";
    return s;
  };

  json += "  \"filter\": {\n";
  json += "    \"excludeTypes\": " + vec_to_json(opt.filter.excludeTypes) + ",\n";
  json += "    \"includeSourcePaths\": " + vec_to_json(opt.filter.includeSourcePaths) + "\n";
  json += "  }\n";
  json += "}\n";

  FileHandle fh(path.c_str(), "w");
  if (fh.get()) {
    std::fwrite(json.data(), 1, json.size(), fh.get());
  } else {
    throw std::runtime_error("Failed to open dump file: " + path);
  }
}

#include "exit_codes.h"

int main(int argc, char* argv[]) {
  // Favor performance and avoid libstdc++ locale initialization paths flagged by MSan
  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);

  signalHandler::install();

  try {
    if (auto parsed = cli::parseArgs(argc, argv)) {
      auto& opt = *parsed;
      
      // Iteration 1: Version check
      if (opt.version) {
          std::fprintf(stdout, "vglog-filter version %s\n", VERSION_STRING);
          return exit_codes::SUCCESS;
      }

      ConfigLoader::load(opt);
      // Collect positional args
      for (int i = optind; i < argc; ++i) {
        if (argv[i])
          opt.inputFiles.emplace_back(argv[i]);
      }
      setup_input_source(opt, argc, argv); // Still needed for defaults (stdin) logic

      if (!opt.dumpConfig.empty()) {
        dump_config_to_file(opt, opt.dumpConfig);
        return exit_codes::SUCCESS;
      }

      opt.validate();

      if (!opt.diffBaseline.empty()) {
          processDiff(opt);
          return exit_codes::SUCCESS;
      }

      processInputFiles(opt);
    } else {
      // Help printed (parseArgs checks help and returns nullopt); normal exit.
      return exit_codes::SUCCESS;
    }
  } catch (const std::exception& e) {
    std::fprintf(stderr, "Error: %s\n", e.what());
    // Try to guess error type? For now GENERIC_ERROR.
    // Ideally we catch strict mode errors specifically.
    return exit_codes::GENERIC_ERROR;
  }

  return exit_codes::SUCCESS;
}
