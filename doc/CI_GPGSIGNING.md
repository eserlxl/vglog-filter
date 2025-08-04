# GPG Signing in CI

This document explains how to set up GPG signing for the version-bump workflow in CI environments.

## Overview

The version-bump workflow can be configured to sign commits and tags with GPG keys, providing cryptographic verification of authorship and tamper-evident commits.

## Setup Options

### Option 1: Use a CI-Specific GPG Key (Recommended)

This approach creates a dedicated GPG key for CI use, separate from personal keys.

#### Step 1: Generate a CI GPG Key

Run the provided script to generate a GPG key:

```bash
./dev-bin/generate-ci-gpg-key.sh
```

This script will:
- Generate a 4096-bit RSA GPG key
- Set a random passphrase
- Export the private key in base64 format
- Display the public key

#### Step 2: Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following secrets:

   **GPG_PRIVATE_KEY**
   - Copy the base64-encoded private key from the script output
   - This is the secret that will be used to sign commits

   **GPG_PUBLIC_KEY** (optional)
   - Copy the public key from the script output
   - This can be added to the repository for verification

#### Step 3: Verify Setup

The workflow will automatically:
- Import the GPG key when `GPG_PRIVATE_KEY` is provided
- Configure git to use the key for signing
- Sign all commits and tags created by the workflow

### Option 2: Disable GPG Signing

If you prefer not to use GPG signing in CI:

1. Do not set the `GPG_PRIVATE_KEY` secret
2. The workflow will automatically disable GPG signing
3. Commits will be created without signatures

## Security Considerations

### Key Management
- **Key Expiration**: CI keys are set to expire after 2 years
- **Key Rotation**: Generate new keys before expiration
- **Access Control**: Only repository administrators should have access to GPG secrets

### Key Scope
- **Repository-Specific**: Each repository should have its own CI GPG key
- **Purpose-Limited**: CI keys should only be used for automated commits
- **Separate from Personal Keys**: Never use personal GPG keys in CI

## Verification

### Check Signed Commits
```bash
# Verify a commit signature
git verify-commit <commit-hash>

# View commit signature details
git log --show-signature <commit-hash>
```

### Check Signed Tags
```bash
# Verify a tag signature
git verify-tag <tag-name>

# View tag signature details
git tag -v <tag-name>
```

## Troubleshooting

### Common Issues

1. **"No GPG key found"**
   - Ensure `GPG_PRIVATE_KEY` secret is set correctly
   - Check that the key is properly base64-encoded

2. **"Bad passphrase"**
   - The script generates a random passphrase automatically
   - No manual passphrase entry is required

3. **"Key not found"**
   - Verify the key ID is correctly extracted
   - Check GPG key import logs in workflow output

### Debug Information

The workflow includes debug output to help troubleshoot GPG issues:
- GPG key import status
- Git configuration after setup
- Key ID verification

## Workflow Behavior

### With GPG Key
- Commits are signed with the CI GPG key
- Tags are signed with the CI GPG key
- All signatures are cryptographically verifiable

### Without GPG Key
- GPG signing is automatically disabled
- Commits and tags are created without signatures
- Workflow continues normally

## Best Practices

1. **Use CI-Specific Keys**: Never reuse personal GPG keys in CI
2. **Regular Key Rotation**: Generate new keys before expiration
3. **Monitor Signatures**: Verify signatures in your release process
4. **Documentation**: Keep this document updated with any changes
5. **Testing**: Test GPG setup in a development environment first

## Example Workflow Output

```
Setting up GPG key for commit signing...
gpg: key ABC123DEF456: "vglog-filter CI Bot <ci@vglog-filter.local>" not changed
gpg: key ABC123DEF456: secret key imported
GPG key configured: ABC123DEF456
DEBUG: Git config after setup:
user.signingkey=ABC123DEF456
commit.gpgsign=true
tag.gpgsign=true
``` 