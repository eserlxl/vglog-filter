// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "cli_parser.h"
#include "file_utils.h"
#include "parsers/suppression_parser.h"

#include <charconv>
#include <cstdio>
#include <getopt.h>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace cli {

namespace {

inline constexpr int maxDepth = 1000;
// VERSION_STRING moved to options.h
inline constexpr int maxMarkerLength = 1024;
inline constexpr size_t errorMsgBufferSize = 64;

enum {
  OPT_ROTATE_SIZE = 1000,
  OPT_ROTATE_BACKUPS,
  OPT_STRICT,
  OPT_DETAILED_JSON,
  OPT_EXCLUDE_STACK,
  OPT_MAX_ERRORS,
  OPT_INCLUDE_TYPE,
  OPT_INCLUDE_FUNCTION,
  OPT_EXCLUDE_FUNCTION,
  OPT_DETAILED_STATS,
  OPT_JSON_ARRAY,
  OPT_EXCLUDE_PID,
  OPT_INCLUDE_PID,
  OPT_INCLUDE_THREAD,
  OPT_AFTER,
  OPT_BEFORE,
  OPT_STATS_JSON,
  OPT_INCLUDE_STACK,
  OPT_CONFIG,
  OPT_COLOR,
  OPT_UNIQUE,
  OPT_CONTEXT,
  OPT_DUMP_CONFIG,
  OPT_INCLUDE_SOURCE,
  OPT_STATS_FORMAT,
  OPT_EXCLUDE_TYPE_RX,
  OPT_INCLUDE_TYPE_RX,
  OPT_EXCLUDE_FUNCTION_RX,
  OPT_INCLUDE_FUNCTION_RX,
  OPT_GITHUB_ACTIONS,    // Iteration 1
  OPT_EXCLUDE_TYPE_FILE, // Iteration 2
  OPT_INCLUDE_TYPE_FILE,
  OPT_EXCLUDE_FUNC_FILE,
  OPT_INCLUDE_FUNC_FILE,
  OPT_SANITIZER,
  OPT_HTML_REPORT, // Iteration 1
  OPT_DIFF, // Iteration 2
  OPT_SUPPRESSIONS // Iteration 2
};



// getopt_long table
// NOLINTNEXTLINE(modernize-avoid-c-arrays)
constinit option LONG_OPTS[] = {
    {"keep-debug-info", no_argument, nullptr, 'k'},
    {"verbose", no_argument, nullptr, 'v'},
    {"json", no_argument, nullptr, 'j'},
    {"output", required_argument, nullptr, 'o'},
    {"depth", required_argument, nullptr, 'd'},
    {"marker", required_argument, nullptr, 'm'},
    {"stream", no_argument, nullptr, 's'},
    {"progress", no_argument, nullptr, 'p'},
    {"memory", no_argument, nullptr, 'M'},
    {"version", no_argument, nullptr, 'V'},
    {"help", no_argument, nullptr, 'h'},
    {"exclude-type", required_argument, nullptr, 'e'},
    {"rotate-size-mb", required_argument, nullptr, OPT_ROTATE_SIZE},
    {"rotate-backups", required_argument, nullptr, OPT_ROTATE_BACKUPS},
    {"strict", no_argument, nullptr, OPT_STRICT},
    {"detailed-json", no_argument, nullptr, OPT_DETAILED_JSON},
    {"exclude-stack", required_argument, nullptr, OPT_EXCLUDE_STACK},
    {"max-errors", required_argument, nullptr, OPT_MAX_ERRORS},
    {"include-type", required_argument, nullptr, OPT_INCLUDE_TYPE},
    {"include-function", required_argument, nullptr, OPT_INCLUDE_FUNCTION},
    {"exclude-function", required_argument, nullptr, OPT_EXCLUDE_FUNCTION},
    {"detailed-stats", no_argument, nullptr, OPT_DETAILED_STATS},
    {"json-array", no_argument, nullptr, OPT_JSON_ARRAY},
    {"exclude-pid", required_argument, nullptr, OPT_EXCLUDE_PID},
    {"include-pid", required_argument, nullptr, OPT_INCLUDE_PID},
    {"include-thread", required_argument, nullptr, OPT_INCLUDE_THREAD},
    {"after", required_argument, nullptr, OPT_AFTER},
    {"before", required_argument, nullptr, OPT_BEFORE},
    {"stats-json", required_argument, nullptr, OPT_STATS_JSON},
    {"include-stack", required_argument, nullptr, OPT_INCLUDE_STACK},
    {"config", required_argument, nullptr, OPT_CONFIG},
    {"color", optional_argument, nullptr, OPT_COLOR},
    {"unique", no_argument, nullptr, OPT_UNIQUE},
    {"context", required_argument, nullptr, OPT_CONTEXT},
    {"dump-config", required_argument, nullptr, OPT_DUMP_CONFIG},
    {"include-source", required_argument, nullptr, OPT_INCLUDE_SOURCE},
    {"stats-format", required_argument, nullptr, OPT_STATS_FORMAT},
    {"exclude-type-rx", required_argument, nullptr, OPT_EXCLUDE_TYPE_RX},
    {"include-type-rx", required_argument, nullptr, OPT_INCLUDE_TYPE_RX},
    {"exclude-function-rx", required_argument, nullptr, OPT_EXCLUDE_FUNCTION_RX},
    {"include-function-rx", required_argument, nullptr, OPT_INCLUDE_FUNCTION_RX},
    {"github-actions", no_argument, nullptr, OPT_GITHUB_ACTIONS},             // Iteration 1
    {"exclude-type-file", required_argument, nullptr, OPT_EXCLUDE_TYPE_FILE}, // Iteration 2
    {"include-type-file", required_argument, nullptr, OPT_INCLUDE_TYPE_FILE},
    {"exclude-function-file", required_argument, nullptr, OPT_EXCLUDE_FUNC_FILE},
    {"include-function-file", required_argument, nullptr, OPT_INCLUDE_FUNC_FILE},
    {"sanitizer", required_argument, nullptr, OPT_SANITIZER},
    {"html-report", required_argument, nullptr, OPT_HTML_REPORT}, // Iteration 1
    {"diff", required_argument, nullptr, OPT_DIFF}, // Iteration 2
    {"suppressions", required_argument, nullptr, OPT_SUPPRESSIONS}, // Iteration 2
    {nullptr, 0, nullptr, 0}};


inline constexpr auto SHORT_OPTS = std::string_view{"kvjo:d:m:spMVhe:"};

[[nodiscard]] std::string make_range_error(std::string_view what, int lo, int hi) {
  std::string msg;
  msg.reserve(errorMsgBufferSize);
  msg.append(what)
      .append(" out of valid range [")
      .append(std::to_string(lo))
      .append("..")
      .append(std::to_string(hi))
      .append("]")
      .append(std::to_string(hi))
      .append("]");
  return msg;
}

[[nodiscard]] int parse_nonneg_int(std::string_view sv, int max_value) {
  if (sv.empty())
    throw std::runtime_error("Value cannot be empty");
  int value = 0;
  const auto* first = sv.data();
  const auto* last = sv.data() + sv.size();
  auto ec = std::from_chars(first, last, value).ec;
  if (ec != std::errc{} || first == last) {
    throw std::runtime_error("Invalid integer: '" + std::string(sv) + "'");
  }
  if (value < 0 || value > max_value) {
    throw std::out_of_range(make_range_error("Integer", 0, max_value));
  }
  return value;
}

[[nodiscard]] std::string parse_marker(std::string_view sv) {
  if (sv.empty())
    throw std::runtime_error("Marker string cannot be empty");
  if (sv.size() > static_cast<size_t>(maxMarkerLength)) {
    throw std::runtime_error("Marker string too long (max " + std::to_string(maxMarkerLength) +
                             " characters)");
  }
  if (sv.find('\0') != std::string_view::npos) {
    throw std::runtime_error("Marker string contains null bytes");
  }
  return std::string{sv};
}

} // namespace

std::optional<Options> parseArgs(int argc, char* argv[]) {
  if (argc < 1 || argv == nullptr) {
    throw std::runtime_error("Invalid command line arguments");
  }

  Options opt{};
  // Reset getopt state for safety in case of reuse
  optind = 1;

  for (;;) {
    const int c = ::getopt_long(argc, argv, SHORT_OPTS.data(), LONG_OPTS, nullptr);
    if (c == -1)
      break;

    switch (c) {
      case 'k':
        opt.trim = false;
        break;
      case 'v':
        opt.scrubRaw = false;
        break;
      case 'j':
        opt.jsonOutput = true;
        break;
      case 'o':
        opt.outputFile = optarg ? std::string{optarg} : std::string{};
        break;
      case 'd':
        opt.depth =
            parse_nonneg_int(optarg ? std::string_view{optarg} : std::string_view{}, maxDepth);
        break;
      case 'm':
        opt.markers.push_back(parse_marker(optarg ? std::string_view{optarg} : std::string_view{}));
        break;
      case 's':
        opt.streamMode = true;
        break;
      case 'p':
        opt.showProgress = true;
        break;
      case 'M':
        opt.monitorMemory = true;
        break;
      case 'V':
        // Just set the flag, let main handle distinct exit
        opt.version = true;
        return opt; // Return opt to let main handle it, or exit here? 
        // Design: Main handles it to use standard exit codes.
        // But parseArgs returns optional. If we return nullopt, main usually shows help/error.
        // Better: return opt with version=true.
      case 'h':
        usage(argv[0]);
        return std::nullopt;
      case 'e':
        if (optarg && *optarg) {
          opt.filter.excludeTypes.emplace_back(optarg);
        }
        break;

      case OPT_DETAILED_JSON:
        opt.detailedJson = true;
        opt.jsonOutput = true;
        break;
      case OPT_DETAILED_STATS:
        opt.detailedStats = true;
        break;
      case OPT_EXCLUDE_STACK:
        if (optarg && *optarg) {
          opt.filter.excludeStackPatterns.emplace_back(optarg);
        }
        break;
      case OPT_MAX_ERRORS:
        opt.filter.maxErrors = static_cast<size_t>(
            parse_nonneg_int(optarg ? std::string_view{optarg} : std::string_view{},
                             std::numeric_limits<int>::max()));
        break;
      case OPT_INCLUDE_TYPE:
        if (optarg && *optarg) {
          opt.filter.includeTypes.emplace_back(optarg);
        }
        break;
      case OPT_INCLUDE_FUNCTION:
        if (optarg && *optarg) {
          opt.filter.includeFunctions.emplace_back(optarg);
        }
        break;
      case OPT_EXCLUDE_FUNCTION:
        if (optarg && *optarg) {
          opt.filter.excludeFunctions.emplace_back(optarg);
        }
        break;
      case OPT_JSON_ARRAY:
        opt.jsonArray = true;
        opt.jsonOutput = true;
        break;
      case OPT_EXCLUDE_PID:
        if (optarg && *optarg) {
          opt.filter.excludePids.push_back(
              parse_nonneg_int(optarg, std::numeric_limits<int>::max()));
        }
        break;
      case OPT_INCLUDE_PID:
        if (optarg && *optarg) {
          opt.filter.includePids.push_back(
              parse_nonneg_int(optarg, std::numeric_limits<int>::max()));
        }
        break;
      case OPT_INCLUDE_THREAD:
        if (optarg && *optarg) {
          opt.filter.includeThreads.push_back(
              parse_nonneg_int(optarg, std::numeric_limits<int>::max()));
        }
        break;
      case OPT_AFTER:
        if (optarg && *optarg)
          opt.timeAfter = optarg;
        break;
      case OPT_BEFORE:
        if (optarg && *optarg)
          opt.timeBefore = optarg;
        break;
      case OPT_STATS_JSON:
        if (optarg && *optarg)
          opt.statsFile = optarg;
        break;
      case OPT_INCLUDE_STACK:
        if (optarg && *optarg)
          opt.filter.includeStackPatterns.emplace_back(optarg);
        break;
      case OPT_CONFIG:
        if (optarg && *optarg)
          opt.configFile = optarg;
        break;
      case OPT_COLOR:
        if (optarg && *optarg) {
            std::string_view val = optarg;
            if (val == "always") opt.colorMode = ColorMode::Always;
            else if (val == "never") opt.colorMode = ColorMode::Never;
            else if (val == "auto") opt.colorMode = ColorMode::Auto;
            else throw std::runtime_error("Invalid color mode: " + std::string(val));
        } else {
            opt.colorMode = ColorMode::Always;
        }
        opt.color = (opt.colorMode == ColorMode::Always); // Sync for compat
        break;
      case OPT_UNIQUE:
        opt.uniqueOutput = true;
        break;
      case OPT_CONTEXT:
        if (optarg && *optarg) {
          opt.contextLines = parse_nonneg_int(optarg, 100);
        }
        break;
      case OPT_DUMP_CONFIG:
        if (optarg && *optarg) {
          opt.dumpConfig = optarg;
        }
        break;
      case OPT_INCLUDE_SOURCE:
        if (optarg && *optarg) {
          opt.filter.includeSourcePaths.emplace_back(optarg);
        }
        break;
      case OPT_STATS_FORMAT:
        if (optarg && *optarg) {
          std::string_view val = optarg;
          if (val == "json") {
            opt.statsFormat = Options::StatsFormat::json;
          } else if (val == "text") {
            opt.statsFormat = Options::StatsFormat::text;
          } else {
            throw std::runtime_error("Invalid stats-format: must be 'text' or 'json'");
          }
        }
        break;
      case OPT_EXCLUDE_TYPE_RX:
        if (optarg && *optarg)
          opt.filter.excludeTypesRegex.emplace_back(optarg);
        break;
      case OPT_INCLUDE_TYPE_RX:
        if (optarg && *optarg)
          opt.filter.includeTypesRegex.emplace_back(optarg);
        break;
      case OPT_EXCLUDE_FUNCTION_RX:
        if (optarg && *optarg)
          opt.filter.excludeFunctionsRegex.emplace_back(optarg);
        break;
      case OPT_INCLUDE_FUNCTION_RX:
        if (optarg && *optarg)
          opt.filter.includeFunctionsRegex.emplace_back(optarg);
        break;
      case OPT_GITHUB_ACTIONS:
        opt.githubActions = true;
        break;
      case OPT_EXCLUDE_TYPE_FILE:
        if (optarg && *optarg) {
          auto lines = readFileLines(optarg);
          std::cerr << "DEBUG: Read " << lines.size() << " lines from " << optarg << "\n";
          opt.filter.excludeTypes.insert(opt.filter.excludeTypes.end(), lines.begin(), lines.end());
        }
        break;
      case OPT_INCLUDE_TYPE_FILE:
        if (optarg && *optarg) {
          auto lines = readFileLines(optarg);
          opt.filter.includeTypes.insert(opt.filter.includeTypes.end(), lines.begin(), lines.end());
        }
        break;
      case OPT_EXCLUDE_FUNC_FILE:
        if (optarg && *optarg) {
          auto lines = readFileLines(optarg);
          opt.filter.excludeFunctions.insert(opt.filter.excludeFunctions.end(), lines.begin(),
                                             lines.end());
        }
        break;
      case OPT_INCLUDE_FUNC_FILE:
        if (optarg && *optarg) {
          auto lines = readFileLines(optarg);
          opt.filter.includeFunctions.insert(opt.filter.includeFunctions.end(), lines.begin(),
                                             lines.end());
          opt.filter.includeFunctions.insert(opt.filter.includeFunctions.end(), lines.begin(),
                                             lines.end());
        }
        break;
      case OPT_SANITIZER:
        if (optarg && *optarg) {
          std::string_view s = optarg;
          if (s == "auto") opt.sanitizerType = SanitizerType::Auto;
          else if (s == "valgrind") opt.sanitizerType = SanitizerType::Valgrind;
          else if (s == "asan") opt.sanitizerType = SanitizerType::Asan;
          else throw std::runtime_error("Invalid sanitizer type: " + std::string(s));
        }
        break;
      case OPT_HTML_REPORT:
        if (optarg && *optarg) {
             opt.htmlReport = optarg;
        }
        break;
      case OPT_DIFF:
        if (optarg && *optarg) {
             opt.diffBaseline = optarg;
        }
        break;
      case OPT_SUPPRESSIONS:
        if (optarg && *optarg) {
             SuppressionParser::parseFile(optarg, opt.filter);
        }
        break;
      default:

        usage(argv[0]);
        throw std::runtime_error("Invalid option. Use -h for help.");
    }
  }

  if (opt.markers.empty()) {
    opt.markers.push_back(std::string(DEFAULT_MARKER));
  }

  return opt;
}

} // namespace cli
