// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "options.h"
#include <sstream>

void usage(std::string_view prog) {
    std::cout << "Usage: " << prog << " [options] [valgrind_log]\n\n"
       << "Input\n"
       << "  valgrind_log            Path to Valgrind log file (default: stdin if omitted)\n"
       << "  -                       Read from stdin (explicit)\n\n"
       << "Options\n"
       << "  -k, --keep-debug-info   Keep everything; do not trim above last debug marker.\n"
       << "  -v, --verbose           Show completely raw blocks (no address / \"at:\" scrub).\n"
       << "  -d N, --depth N         Signature depth (default: " << DEFAULT_DEPTH << ", 0 = unlimited).\n"
       << "  -m S, --marker S        Marker string (default: \"" << DEFAULT_MARKER << "\").\n"
       << "  -s, --stream            Force stream processing mode (auto-detected for files >5MB).\n"
       << "  -p, --progress          Show progress for large files.\n"
       << "  -M, --memory            Monitor memory usage during processing.\n"
       << "  -V, --version           Show version information.\n"
       << "  -h, --help              Show this help.\n\n"
       << "Notes\n"
       << "  • In stream mode (including stdin), the tool outputs only the region after the *last*\n"
       << "    marker encountered (if any). If no marker is found, the entire input is processed.\n\n"
       << "Examples\n"
       << "  " << prog << " log.txt                 # Process file\n"
       << "  " << prog << " < log.txt               # Process from stdin\n"
       << "  " << prog << " - < log.txt             # Explicit stdin\n"
       << "  valgrind ./prog 2>&1 | " << prog << "     # Direct pipe from valgrind\n";
}
