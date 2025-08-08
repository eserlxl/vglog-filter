# CI GPG Setup for vglog-filter

This document explains how to set up GPG signing for the automated version bump workflow to comply with repository rules requiring verified signatures.

## Problem

The automated version bump workflow was failing because:
1. The repository has a rule requiring all commits to have verified signatures
2. The workflow was explicitly disabling GPG signing (`git config --local commit.gpgSign false`)
3. This caused push failures with error: "Commits must have verified signatures"

## Solution

The workflow has been updated to:
1. Generate and use a dedicated CI GPG key for signing commits
2. Import the GPG key from GitHub secrets
3. Configure Git to sign commits with the CI key
4. Remove the `--no-verify` flags that bypassed signing

## Setup Instructions

### 1. Generate CI GPG Key

Run the existing GPG key generator script from the project root:

```bash
./dev-bin/generate-ci-gpg-key.sh \
  --name "vglog-filter CI Bot" \
  --email "ci@vglog-filter.local" \
  --expire "2y" \
  --with-subkey \
  --revoke-cert \
  --print-secrets
```

This will:
- Generate a new GPG key pair specifically for CI
- Create the key in `./ci-gpg-out/` directory (default)
- Print the secrets for easy copying to GitHub

### 2. Add GitHub Secrets

Go to your repository settings: https://github.com/[username]/[repository]/settings/secrets/actions

Add these secrets:

**GPG_PRIVATE_KEY**
- Copy the entire contents of `ci-gpg-out/secret.asc`

**GPG_PASSPHRASE**
- Copy the contents of `ci-gpg-out/passphrase.txt`

### 3. Optional: Add Public Key as Variable

For reference, you can also add the public key as a repository variable:

**GPG_PUBLIC_KEY**
- Copy the entire contents of `ci-gpg-out/public.asc`

## Key Details

- **Key Name**: vglog-filter CI Bot
- **Email**: ci@vglog-filter.local
- **Algorithm**: Ed25519 (with signing subkey)
- **Expiration**: 2 years
- **Usage**: Signing commits and tags only

## Security Notes

- The generated keys are stored in `./ci-gpg-out/` (added to `.gitignore`)
- Never commit the private key or passphrase to version control
- The key is specifically for CI use and should not be used for personal signing
- A revocation certificate is generated for emergency key revocation

## Workflow Changes

The following changes were made to `.github/workflows/version-bump.yml`:

1. **Removed GPG signing disable**: Removed `git config --local commit.gpgSign false`
2. **Added GPG setup step**: New step to import and configure the CI GPG key
3. **Removed --no-verify flags**: Commits now go through proper signing process
4. **Added error handling**: Workflow fails early if GPG secrets are missing

## Verification

After setup, the workflow will:
1. Import the GPG key from secrets
2. Configure Git to use the key for signing
3. Sign all commits automatically
4. Push signed commits that comply with repository rules

The commits will show as "Verified" in GitHub's commit history.

## Troubleshooting

If the workflow fails with GPG-related errors:

1. **Check secrets**: Ensure `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` are set correctly
2. **Verify key format**: The private key should be the complete ASCII-armored GPG key
3. **Check passphrase**: Ensure the passphrase matches the one used during key generation
4. **Regenerate if needed**: Run the generate script again to create a new key pair

## Alternative Options

The `generate-ci-gpg-key.sh` script supports many options:

```bash
# Custom output directory
./dev-bin/generate-ci-gpg-key.sh --out-dir /tmp/my-keys

# Custom key details
./dev-bin/generate-ci-gpg-key.sh \
  --name "My CI Bot" \
  --email "ci@myproject.com" \
  --comment "Custom comment"

# Different algorithm
./dev-bin/generate-ci-gpg-key.sh --algo rsa4096

# No base64 copies
./dev-bin/generate-ci-gpg-key.sh --no-b64

# See all options
./dev-bin/generate-ci-gpg-key.sh --help
```

The script is already well-designed for CI use with proper security practices and comprehensive documentation.
