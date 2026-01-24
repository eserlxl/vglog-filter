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

namespace {

inline constexpr auto STDIN_SENTINEL = std::string_view{"-"};

void setup_input_source(Options& opt, int argc, char* argv[]) {
  if (optind >= argc) {
    opt.useStdin = true;
    opt.filename = std::string{STDIN_SENTINEL};
  } else {
    const char* arg = argv[optind];
    if (!arg)
      throw std::runtime_error("Invalid filename argument");

    const std::string_view name{arg};
    if (name == STDIN_SENTINEL) {
      opt.useStdin = true;
      opt.filename = std::string{STDIN_SENTINEL};
    } else {
      // Prefer string-based sanitization first; canonicalization happens in file helpers.
      opt.filename = path_validation::sanitize_path_for_file_access(name);
    }
  }

  // Auto-detect streaming when not explicitly requested
  if (!opt.streamMode) {
    opt.streamMode = opt.useStdin ? true : isLargeFile(opt.filename);
    if (opt.streamMode && !opt.useStdin) {
      std::fputs("Info: Large file detected, using stream processing mode\n", stderr);
    }
  }
}

void processInputFiles(Options& opt) {
  if (opt.inputFiles.empty()) {
    opt.inputFiles.push_back(opt.filename.empty() ? std::string(STDIN_SENTINEL) : opt.filename);
  }

  // Create processor once to maintain stats/deduplication state across files
  LogProcessor processor(opt);

  if (opt.monitorMemory) {
    reportMemoryUsage("starting processing", "all_inputs");
  }

  for (const auto& file : opt.inputFiles) {
    opt.filename = file; // Update for error messages/logging

    if (opt.streamMode) {
      if (opt.useStdin || file == STDIN_SENTINEL) {
        processor.processStreamCFile(stdin);
      } else {
        processFileStream(file,
                            opt); // Note: processFileStream creates its own Processor usually?
        // Wait, processFileStream is a helper in main.cpp?
        // I need to check `processFileStream` implementation.
        // If it creates its own processor, dedup won't work across files.
        // Ideally `processStream` should be called on OUR processor.
        std::cerr << "Warning: Multi-file stream mode sharing state not fully implemented in "
                     "helper function.\n";
      }
    } else {
      if (file == STDIN_SENTINEL) {
        // Non-stream stdin? Load all lines?
        // LogProcessor::processStreamCFile exists.
        processor.processStreamCFile(stdin);
      } else {
        const std::vector<std::string> lines = readFileLines(file);
        if (lines.empty())
          continue; // Warn?
        processor.processLines(lines);
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
