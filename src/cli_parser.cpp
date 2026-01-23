// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "cli_parser.h"

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

inline constexpr int MAX_DEPTH = 1000;
inline constexpr auto VERSION_STRING = "10.5.0";
inline constexpr int MAX_MARKER_LENGTH = 1024;
inline constexpr size_t ERROR_MSG_BUFFER_SIZE = 64;

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
  OPT_INCLUDE_THREAD
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
    {nullptr, 0, nullptr, 0}};

inline constexpr auto SHORT_OPTS = std::string_view{"kvjo:d:m:spMVhe:"};

[[nodiscard]] std::string make_range_error(std::string_view what, int lo, int hi) {
  std::string msg;
  msg.reserve(ERROR_MSG_BUFFER_SIZE);
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
  if (sv.size() > static_cast<size_t>(MAX_MARKER_LENGTH)) {
    throw std::runtime_error("Marker string too long (max " + std::to_string(MAX_MARKER_LENGTH) +
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
            parse_nonneg_int(optarg ? std::string_view{optarg} : std::string_view{}, MAX_DEPTH);
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
        std::fprintf(stdout, "vglog-filter version %s\n", VERSION_STRING);
        return std::nullopt;
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
