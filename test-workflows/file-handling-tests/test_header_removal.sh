#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test header prototype removal detection in semantic-version-analyzer
# This test verifies that removing a prototype in ../source-fixtures/test_header.h triggers api_breaking=true

set -Eeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source test helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../test_helper.sh"

echo "=== Testing Header Prototype Removal ==="

# Create temporary test environment
temp_dir=$(create_temp_test_env "header-removal")
cd "$temp_dir"

# Create a test header file with a prototype
mkdir -p include
cat > include/test_header.h << 'EOF'
// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter test suite and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.
//
// Test fixture for API breaking change detection

#ifndef TEST_HEADER_H
#define TEST_HEADER_H

// Test function prototype
int test_function(int param1, const char* param2);

#endif // TEST_HEADER_H
EOF

# Add and commit the header
git add include/test_header.h
git commit -m "Add test header with prototype"

# Remove the prototype
cat > include/test_header.h << 'EOF'
// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter test suite and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.
//
// Test fixture for API breaking change detection

#ifndef TEST_HEADER_H
#define TEST_HEADER_H

// Test function prototype removed

#endif // TEST_HEADER_H
EOF

# Commit the removal
git add include/test_header.h
git commit -m "Remove function prototype"

# Get the commit hashes
first_commit=$(git rev-parse HEAD~1)
second_commit=$(git rev-parse HEAD)

# Run semantic version analyzer from the original project directory
result=$("$PROJECT_ROOT/dev-bin/semantic-version-analyzer" --machine --repo-root "$temp_dir" --base "$first_commit" --target "$second_commit" 2>&1 || true)

# Extract suggestion
suggestion=$(echo "$result" | grep "SUGGESTION=" | cut -d'=' -f2 || echo "unknown")

echo "Version bump suggestion: $suggestion"

# Verify that removing a prototype triggers major version bump
if [[ "$suggestion" = "major" ]]; then
    echo "✅ PASS: Removing prototype correctly triggers major version bump"
    exit_code=0
else
    echo "❌ FAIL: Removing prototype should trigger major version bump, got: $suggestion"
    exit_code=1
fi

# Clean up
cleanup_temp_test_env "$temp_dir"

exit $exit_code 