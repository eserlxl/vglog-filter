// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "options.h"
#include <cstdio>
#include <stdexcept>

void usage(std::string_view prog) {
  // Using stdio to avoid libstdc++ locale initialization that MSan flags
  std::fprintf(stdout, "Usage: %.*s [options] [valgrind_log]\n\n", static_cast<int>(prog.size()),
               prog.data());

  std::fputs("Input\n", stdout);
  std::fputs("  valgrind_log            Path to Valgrind log file (default: stdin if omitted)\n",
             stdout);
  std::fputs("  -                       Read from stdin (explicit)\n\n", stdout);

  std::fputs("Options\n", stdout);
  std::fputs("  -k, --keep-debug-info   Keep everything; do not trim above last debug marker.\n",
             stdout);
  std::fputs("  -v, --verbose           Show completely raw blocks (no address / \"at:\" scrub).\n",
             stdout);
  std::fputs("  -j, --json              Output JSON format.\n", stdout);
  std::fputs("  --detailed-json         Output detailed JSON with structured fields.\n", stdout);
  std::fprintf(stdout, "  -d N, --depth N         Signature depth (default: %d, 0 = unlimited).\n",
               DEFAULT_DEPTH);
  std::fprintf(stdout, "  -m S, --marker S        Marker string (default: \"%.*s\").\n",
               static_cast<int>(DEFAULT_MARKER.size()), DEFAULT_MARKER.data());
  std::fputs("  --max-errors N          Limit the number of error blocks output (default: 0 = "
             "unlimited).\n",
             stdout);
  std::fputs("  --include-type S        Include only errors with types containing S (can occur "
             "multiple times).\n",
             stdout);
  std::fputs("  --include-function S    Include only errors with stack frames containing S (can "
             "occur multiple times).\n",
             stdout);
  std::fputs("  --exclude-function S    Exclude errors with stack frames containing S (can occur "
             "multiple times).\n",
             stdout);
  std::fputs(
      "  -s, --stream            Force stream processing mode (auto-detected for files >5MB).\n",
      stdout);
  std::fputs("  -p, --progress          Show progress for large files.\n", stdout);
  std::fputs("  -M, --memory            Monitor memory usage during processing.\n", stdout);
  std::fputs("  -V, --version           Show version information.\n", stdout);
  std::fputs("  -h, --help              Show this help.\n\n", stdout);

  std::fputs("Notes\n", stdout);
  std::fputs(
      "  • In stream mode (including stdin), the tool outputs only the region after the *last*\n",
      stdout);
  std::fputs(
      "    marker encountered (if any). If no marker is found, the entire input is processed.\n\n",
      stdout);

  std::fputs("Examples\n", stdout);
  std::fprintf(stdout, "  %.*s log.txt                 # Process file\n",
               static_cast<int>(prog.size()), prog.data());
  std::fprintf(stdout, "  %.*s < log.txt               # Process from stdin\n",
               static_cast<int>(prog.size()), prog.data());
  std::fprintf(stdout, "  %.*s - < log.txt             # Explicit stdin\n",
               static_cast<int>(prog.size()), prog.data());
  std::fprintf(stdout, "  valgrind ./prog 2>&1 | %.*s     # Direct pipe from valgrind\n",
               static_cast<int>(prog.size()), prog.data());
}

void Options::validate() const {
  if (rotateBackups > 0 && outputFile.empty()) {
    throw std::runtime_error("Rotation requires output file (-o/--output)");
  }
  if (rotateSizeMb > 0 && outputFile.empty()) {
    throw std::runtime_error("Rotation size requires output file (-o/--output)");
  }
}
