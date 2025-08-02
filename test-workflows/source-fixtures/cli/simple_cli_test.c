// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter test suite and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help message\n");
            return 0;
        }
        if (strcmp(argv[i], "--version") == 0) {
            printf("Version 9.3.0\n");
            return 0;
        }
        if (strcmp(argv[i], "--verbose") == 0) {
            printf("Verbose mode\n");
            return 0;
        }
    }
    return 1;
}
