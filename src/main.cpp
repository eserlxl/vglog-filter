// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "cli_parser.h"
#include "file_utils.h"
#include "log_processor.h"
#include "options.h"
#include "path_validation.h"

#include <cstdio>
#include <exception>
#include <getopt.h> // For optind
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

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
    opt.streamMode = opt.useStdin ? true : is_large_file(opt.filename);
    if (opt.streamMode && !opt.useStdin) {
      std::fputs("Info: Large file detected, using stream processing mode\n", stderr);
    }
  }
}

void process_input(const Options& opt) {
  if (opt.monitorMemory) {
    report_memory_usage("starting processing", opt.filename);
  }

  LogProcessor processor(opt);

  if (opt.streamMode) {
    if (opt.useStdin) {
      processor.processStreamCFile(stdin);
    } else {
      process_file_stream(opt.filename, opt);
    }
  } else {
    const std::vector<std::string> lines = read_file_lines(opt.filename);
    if (lines.empty() && !opt.filename.empty() && opt.filename != STDIN_SENTINEL) {
      std::fprintf(stderr, "Warning: Input file '%s' is empty\n", opt.filename.c_str());
      return;
    }
    processor.processLines(lines);
  }

  if (opt.monitorMemory) {
    report_memory_usage("completed processing", opt.filename);
  }

  if (opt.showProgress || opt.monitorMemory) {
    processor.printStats(stderr);
  }
}

} // namespace

int main(int argc, char* argv[]) {
  // Favor performance and avoid libstdc++ locale initialization paths flagged by MSan
  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);

  try {
    if (auto parsed = cli::parseArgs(argc, argv)) {
      auto& opt = *parsed;
      setup_input_source(opt, argc, argv);
      opt.validate();
      process_input(opt);
    } else {
      // Help/version printed; normal exit.
      return 0;
    }
  } catch (const std::exception& e) {
    std::fprintf(stderr, "Error: %s\n", e.what());
    return 1;
  }

  return 0;
}
