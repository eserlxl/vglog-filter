#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Test GPG setup for CI workflow

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}Testing GPG Setup for CI Workflow${RESET}"
echo ""

# Check if GPG is available
if ! command -v gpg >/dev/null 2>&1; then
    echo -e "${RED}❌ GPG is not installed${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ GPG is available${RESET}"

# Check if we have a GPG key to test with
if [[ -z "${GPG_PRIVATE_KEY:-}" ]]; then
    echo -e "${YELLOW}⚠️  No GPG_PRIVATE_KEY environment variable set${RESET}"
    echo "This test will simulate the workflow without GPG signing"
    echo ""
    
    # Test git configuration without GPG
    git config --local commit.gpgsign false
    git config --local tag.gpgsign false
    
    echo -e "${GREEN}✅ Git configured for unsigned commits${RESET}"
    
    # Test commit creation
    echo "test" > ./gpg-test.txt
    git add ./gpg-test.txt
    git commit -m "test: Unsigned commit test" || {
        echo -e "${RED}❌ Commit creation failed${RESET}"
        exit 1
    }
    
    # Clean up
    git reset --hard HEAD~1
    rm -f ./gpg-test.txt
    
    echo -e "${GREEN}✅ Unsigned commit test passed${RESET}"
    echo ""
    echo -e "${YELLOW}To test with GPG signing, set the GPG_PRIVATE_KEY environment variable${RESET}"
    echo "Example: GPG_PRIVATE_KEY=\$(cat /path/to/private-key.b64) ./dev-bin/test-gpg-setup.sh"
    
else
    echo -e "${GREEN}✅ GPG_PRIVATE_KEY environment variable is set${RESET}"
    echo ""
    
    # Configure GPG to use batch mode and avoid interactive prompts
    echo "batch" >> ~/.gnupg/gpg.conf 2>/dev/null || true
    echo "pinentry-mode loopback" >> ~/.gnupg/gpg.conf 2>/dev/null || true
    
    echo -e "${CYAN}Importing GPG key...${RESET}"
    
    # Import the GPG key
    echo "$GPG_PRIVATE_KEY" | base64 -d | gpg --batch --import
    
    # Configure git to use the imported key
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    if [[ -n "$GPG_KEY_ID" ]]; then
        git config --local user.signingkey "$GPG_KEY_ID"
        git config --local commit.gpgsign true
        git config --local tag.gpgsign true
        echo -e "${GREEN}✅ GPG key configured: $GPG_KEY_ID${RESET}"
    else
        echo -e "${RED}❌ No GPG key found after import${RESET}"
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}Testing GPG signing...${RESET}"
    
    # Test commit creation with signing
    echo "test" > ./gpg-test.txt
    git add ./gpg-test.txt
    git commit -m "test: GPG signed commit test" || {
        echo -e "${RED}❌ GPG signed commit creation failed${RESET}"
        exit 1
    }
    
    # Verify the commit signature
    if git verify-commit HEAD 2>/dev/null; then
        echo -e "${GREEN}✅ GPG signed commit verification passed${RESET}"
    else
        echo -e "${RED}❌ GPG signed commit verification failed${RESET}"
        exit 1
    fi
    
    # Test tag creation with signing
    git tag -s "test-gpg-tag" -m "Test GPG signed tag" || {
        echo -e "${RED}❌ GPG signed tag creation failed${RESET}"
        exit 1
    }
    
    # Verify the tag signature
    if git verify-tag "test-gpg-tag" 2>/dev/null; then
        echo -e "${GREEN}✅ GPG signed tag verification passed${RESET}"
    else
        echo -e "${RED}❌ GPG signed tag verification failed${RESET}"
        exit 1
    fi
    
    # Clean up
    git tag -d "test-gpg-tag" 2>/dev/null || true
    git reset --hard HEAD~1
    rm -f ./gpg-test.txt
    
    echo ""
    echo -e "${GREEN}✅ All GPG signing tests passed!${RESET}"
    echo ""
    echo -e "${CYAN}GPG Configuration Summary:${RESET}"
    echo "- Key ID: $GPG_KEY_ID"
    echo "- Commit signing: $(git config --get commit.gpgsign)"
    echo "- Tag signing: $(git config --get tag.gpgsign)"
    echo "- User signing key: $(git config --get user.signingkey)"
fi

echo ""
echo -e "${GREEN}🎉 GPG setup test completed successfully!${RESET}" 