// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter test suite and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#ifndef INTERNAL_HEADER_HH
#define INTERNAL_HEADER_HH

// Function prototype that could be removed to test API breaking detection
int process_data(const char* input, int length);

// Another function that could be removed
void cleanup_resources(void);

// This function will be removed to test API breaking detection

#endif // INTERNAL_HEADER_HH 