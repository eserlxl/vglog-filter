// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "options.h"
#include <iostream>

void usage(std::string_view prog) {
    // Initialize constants with explicit values to avoid uninitialized memory
    const int default_depth = DEFAULT_DEPTH;
    const std::string default_marker = DEFAULT_MARKER;
    
    // Ensure the stream is properly initialized and flushed before use
    std::cout.flush();
    
    // Initialize output with explicit string construction to avoid uninitialized memory
    std::string usage_text;
    usage_text.reserve(2048); // Pre-allocate to avoid reallocations
    
    usage_text = "Usage: ";
    usage_text += std::string(prog);
    usage_text += " [options] [valgrind_log]\n\n";
    usage_text += "Input\n";
    usage_text += "  valgrind_log            Path to Valgrind log file (default: stdin if omitted)\n";
    usage_text += "  -                       Read from stdin (explicit)\n\n";
    usage_text += "Options\n";
    usage_text += "  -k, --keep-debug-info   Keep everything; do not trim above last debug marker.\n";
    usage_text += "  -v, --verbose           Show completely raw blocks (no address / \"at:\" scrub).\n";
    usage_text += "  -d N, --depth N         Signature depth (default: ";
    usage_text += std::to_string(default_depth);
    usage_text += ", 0 = unlimited).\n";
    usage_text += "  -m S, --marker S        Marker string (default: \"";
    usage_text += default_marker;
    usage_text += "\").\n";
    usage_text += "  -s, --stream            Force stream processing mode (auto-detected for files >5MB).\n";
    usage_text += "  -p, --progress          Show progress for large files.\n";
    usage_text += "  -M, --memory            Monitor memory usage during processing.\n";
    usage_text += "  -V, --version           Show version information.\n";
    usage_text += "  -h, --help              Show this help.\n\n";
    usage_text += "Notes\n";
    usage_text += "  • In stream mode (including stdin), the tool outputs only the region after the *last*\n";
    usage_text += "    marker encountered (if any). If no marker is found, the entire input is processed.\n\n";
    usage_text += "Examples\n";
    usage_text += "  ";
    usage_text += std::string(prog);
    usage_text += " log.txt                    # Process file\n";
    usage_text += "  ";
    usage_text += std::string(prog);
    usage_text += " < log.txt                  # Process from stdin\n";
    usage_text += "  ";
    usage_text += std::string(prog);
    usage_text += " - < log.txt                # Explicit stdin\n";
    usage_text += "  valgrind ./prog 2>&1 | ";
    usage_text += std::string(prog);
    usage_text += "     # Direct pipe from valgrind\n";
    
    // Output the complete string at once to avoid multiple stream operations
    std::cout << usage_text;
}
