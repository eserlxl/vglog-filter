#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Generate GPG key for CI use

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}GPG Key Generator for CI Use${RESET}"
echo "This script generates a GPG key suitable for CI environments."
echo ""

# Check if gpg is available
if ! command -v gpg >/dev/null 2>&1; then
    echo -e "${RED}Error: GPG is not installed${RESET}"
    exit 1
fi

# Create temporary GPG home directory
TEMP_GNUPG=$(mktemp -d)
export GNUPGHOME="$TEMP_GNUPG"

# Configure GPG to use batch mode and avoid interactive prompts
echo "batch" >> "$TEMP_GNUPG/gpg.conf"
echo "pinentry-mode loopback" >> "$TEMP_GNUPG/gpg.conf"

# Generate a random passphrase for the key
PASSPHRASE=$(openssl rand -base64 32)

# Create GPG batch file
cat > /tmp/gpg-batch << EOF
%echo Generating CI GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: vglog-filter CI Bot
Name-Email: ci@vglog-filter.local
Name-Comment: Automated CI signing key
Expire-Date: 2y
Passphrase: $PASSPHRASE
%commit
%echo Done
EOF

echo -e "${YELLOW}Generating GPG key...${RESET}"
gpg --batch --generate-key /tmp/gpg-batch

# Get the key ID
KEY_ID=$(gpg --list-secret-keys --keyid-format LONG ci@vglog-filter.local | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)

if [[ -z "$KEY_ID" ]]; then
    echo -e "${RED}Error: Failed to generate GPG key${RESET}"
    exit 1
fi

echo -e "${GREEN}GPG key generated successfully!${RESET}"
echo -e "${CYAN}Key ID:${RESET} $KEY_ID"
echo -e "${CYAN}Passphrase:${RESET} $PASSPHRASE"

# Export the private key
echo -e "${YELLOW}Exporting private key...${RESET}"
# Use batch mode with loopback pinentry to avoid interactive prompts
gpg --batch --pinentry-mode loopback --passphrase "$PASSPHRASE" --export-secret-key "$KEY_ID" | base64 -w 0 > /tmp/private-key.b64

# Check if export was successful
if [[ ! -s /tmp/private-key.b64 ]]; then
    echo -e "${RED}Error: Failed to export private key${RESET}"
    exit 1
fi

PRIVATE_KEY=$(cat /tmp/private-key.b64)

echo ""
echo -e "${GREEN}=== GPG Key Setup Complete ===${RESET}"
echo ""
echo -e "${CYAN}1. Add this secret to your GitHub repository:${RESET}"
echo "   Name: GPG_PRIVATE_KEY"
echo "   Value: $PRIVATE_KEY"
echo ""
echo -e "${CYAN}2. Add this public key to your repository:${RESET}"
echo "   Name: GPG_PUBLIC_KEY"
echo "   Value: $(gpg --armor --export "$KEY_ID")"
echo ""
echo -e "${CYAN}3. The workflow will automatically use this key for signing commits.${RESET}"
echo ""
echo -e "${YELLOW}Note: Keep the passphrase secure. The key will expire in 2 years.${RESET}"

# Cleanup
rm -f /tmp/gpg-batch /tmp/private-key.b64
rm -rf "$TEMP_GNUPG" 