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

namespace {

inline constexpr auto STDIN_SENTINEL = std::string_view{"-"};

void setup_input_source(Options& opt, int argc, char* argv[]) {
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
