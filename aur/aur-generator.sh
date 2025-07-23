#!/bin/bash
# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
set -euo pipefail

# --- Config / Constants ---
readonly PKGNAME="vglog-filter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT
COLOR=1
ASCII_ARMOR=0
# VALID_MODES is used for validation in the usage function and mode checking
VALID_MODES=(local aur aur-git clean test)

# --- Functions ---
require() {
    local t
    for t in "$@"; do
        command -v "$t" >/dev/null || { err "Missing $t"; exit 1; }
    done
}

# Prompt helper function that auto-skips when CI is set
prompt() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="${3:-}"
    if [[ ${CI:-0} == 1 ]]; then
        if [[ -n "$default_value" ]]; then
            eval "$var_name=\"$default_value\""
            log "[CI] Auto-selected '$default_value' for: $prompt_text"
            return 0
        else
            log "[CI] Skipping prompt: $prompt_text"
            return 1
        fi
    fi
    read -rp "$prompt_text" "$var_name"
}

# Color helper function
color_echo() {
    local color_code="$1"
    shift
    local msg="$*"
    if (( COLOR )); then
        printf '\e[%sm%s\e[0m\n' "$color_code" "$msg"
    else
        printf '%s\n' "$msg"
    fi
}

log() { color_echo "1;32" "$*"; }
warn() { color_echo "1;33" "$*" >&2; }
err() { color_echo "1;31" "$*" >&2; }

update_checksums() {
    updpkgsums
    log "[update_checksums] Ran updpkgsums (b2sums updated)."
}
generate_srcinfo() {
    if command -v makepkg >/dev/null 2>&1; then
        makepkg --printsrcinfo > .SRCINFO
        log "[generate_srcinfo] Updated .SRCINFO with makepkg --printsrcinfo."
    elif command -v mksrcinfo >/dev/null 2>&1; then
        mksrcinfo
        log "[generate_srcinfo] Updated .SRCINFO with mksrcinfo (deprecated, please update your tools)."
    else
        warn "Warning: Could not update .SRCINFO (makepkg --printsrcinfo/mksrcinfo not found)."
    fi
}
install_pkg() {
    local mode="$1"
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[$mode] --dry-run: Skipping makepkg -si. All required steps completed successfully."
    else
        if [[ "$mode" == "aur" ]]; then
                    if [[ "${AUTO:-}" == "y" ]]; then
            run_makepkg=n
        else
            prompt "Do you want to run makepkg -si now? [y/N] " run_makepkg n
        fi
            if [[ "$run_makepkg" =~ ^[Yy]$ ]]; then
                makepkg -si
            fi
        else
            makepkg -si
        fi
    fi
}

function usage() {
    log "Usage: $0 [--no-color|-n] [--ascii-armor|-a] [local|aur|aur-git|clean|test] [--dry-run|-d]"
    echo
    log "Modes:"
    log "  local     Build and install the package from a local tarball (for testing)."
    log "  aur       Prepare a release tarball, sign it with GPG, and update PKGBUILD for AUR upload."
    log "  aur-git   Generate a PKGBUILD for the -git (VCS) AUR package and optionally install it (no tarball/signing)."
    log "  clean     Remove all generated files and directories"
    log "  test      Run all modes in dry-run mode to check for errors and report results"
    echo
    log "Options:"
    log "  --no-color, -n   Disable colored output (also supported via NO_COLOR env variable)"
    log "  --ascii-armor, -a Use ASCII-armored signatures (.asc) instead of binary (.sig) for GPG signing"
    log "  --dry-run, -d    Run all steps except the final makepkg -si (for CI/testing)"
    echo
    log "Notes:"
    log "- Requires PKGBUILD.0 as the template for PKGBUILD generation."
    log "- For 'aur' mode, a GPG secret key is required for signing the tarball."
    log "- For 'aur' and 'local' modes, the script will attempt to update checksums and .SRCINFO."
    log "- For 'aur-git' mode, checksums are set to 'SKIP' (required for VCS packages)."
    log "- To skip the GPG key selection menu in 'aur' mode, set GPG_KEY_ID to your key's ID:"
    log "    GPG_KEY_ID=ABCDEF ./aur-generator.sh aur"
    log "- To disable colored output, set NO_COLOR=1 or use --no-color/-n."
    log "- To use ASCII-armored signatures (.asc), use --ascii-armor/-a (some AUR helpers prefer this format)."
    log "- To test the script without running makepkg -si, add --dry-run or -d as the second argument."
    log "- If GitHub CLI (gh) is installed, the script can automatically upload missing release assets."
    log "- To skip the automatic upload prompt in 'aur' mode, set AUTO=y:"
    log "    AUTO=y ./aur-generator.sh aur"
    log "- To skip interactive prompts in 'aur' mode (for CI), set CI=1:"
    log "    CI=1 ./aur-generator.sh aur"
    log "- The 'test' mode runs all other modes in dry-run mode to verify they work correctly."
    exit 1
}

# --- Main Logic ---
# Colorized log helpers (disable color if NO_COLOR is set or --no-color/-n is passed)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-color|-n)
            COLOR=0
            shift
            ;;
        --ascii-armor|-a)
            ASCII_ARMOR=1
            shift
            ;;
        *)
            break
            ;;
    esac
done
if [[ -n "${NO_COLOR:-}" ]]; then
    COLOR=0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
fi

MODE="$1"
DRY_RUN=0
if [[ $# -eq 2 ]]; then
    case "$2" in
        --dry-run|-d)
            DRY_RUN=1
            ;;
        *)
            err "Unknown second argument: $2"
            usage
            ;;
    esac
fi

# Validate mode against VALID_MODES array
valid_mode=false
for valid_mode_name in "${VALID_MODES[@]}"; do
    if [[ "$MODE" == "$valid_mode_name" ]]; then
        valid_mode=true
        break
    fi
done

if [[ "$valid_mode" == "false" ]]; then
    err "Unknown mode: $MODE"
    usage
fi

log "Running in $MODE mode"
case "$MODE" in
    local)
        log "[local] Build and install from local tarball."
        require makepkg updpkgsums curl
        ;;
    aur)
        log "[aur] Prepare for AUR upload: creates tarball, GPG signature, and PKGBUILD for release."
        require makepkg updpkgsums curl gpg
        # Check for optional GitHub CLI
        if ! command -v gh >/dev/null 2>&1; then
            warn "[aur] Note: GitHub CLI (gh) not found. Automatic asset upload will not be available."
        fi
        ;;
    aur-git)
        log "[aur-git] Prepare PKGBUILD for VCS (git) package. No tarball is created."
        require makepkg
        ;;
    clean)
        log "[clean] Remove generated files and directories."
        # Clean mode does not require PKGVER or PKGBUILD0
        OUTDIR="$SCRIPT_DIR"
        PKGBUILD="$SCRIPT_DIR/PKGBUILD"
        SRCINFO="$SCRIPT_DIR/.SRCINFO"
        shopt -s nullglob
        # Create separate arrays for tarballs and signatures to avoid duplicate glob expansion
        TARBALLS=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz)
        SIGNATURES=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz.sig)
        ASC_SIGNATURES=("$SCRIPT_DIR/${PKGNAME}-"*.tar.gz.asc)
        # Combine arrays for removal
        files=("${TARBALLS[@]}" "${SIGNATURES[@]}" "${ASC_SIGNATURES[@]}")
        echo "Cleaning AUR directory..."
        if (( ${#files[@]} )); then
            rm -f -- "${files[@]}"
        fi
        rm -f "$PKGBUILD" "$SRCINFO"
        rm -rf "$SCRIPT_DIR/src" "$SCRIPT_DIR/pkg"
        rm -f "$SCRIPT_DIR"/*.pkg.tar.*
        shopt -u nullglob
        log "Clean complete."
        exit 0
        ;;
    test)
        log "[test] Running all modes in dry-run mode to check for errors."
        TEST_ERRORS=0
        
        # Test each mode
        for test_mode in local aur aur-git; do
            log "--- Testing $test_mode mode ---"
            
            # Always run clean before each test
            log "[test] Running clean before $test_mode test..."
            if ! bash "$SCRIPT_DIR/aur-generator.sh" clean > /dev/null 2>&1; then
                warn "[test] Warning: Clean failed for $test_mode test, but continuing..."
            fi
            
            # Create a temporary directory for this test
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"
            
            # Set up test environment
            export DRY_RUN=1
            export CI=1  # Skip prompts
            
            # For aur mode, set a dummy GPG key to avoid prompts
            if [[ "$test_mode" == "aur" ]]; then
                export GPG_KEY_ID="TEST_KEY_FOR_DRY_RUN"
            fi
            
            # Run the test mode
            if bash "$SCRIPT_DIR/aur-generator.sh" "$test_mode" --dry-run > "$TEMP_DIR/test_output.log" 2>&1; then
                log "[test] ✓ $test_mode mode passed"
            else
                err "[test] ✗ $test_mode mode failed"
                TEST_ERRORS=$((TEST_ERRORS + 1))
                # Show the error output
                if [[ -f "$TEMP_DIR/test_output.log" ]]; then
                    warn "Error output for $test_mode:"
                    cat "$TEMP_DIR/test_output.log" >&2
                fi
            fi
            
            # Clean up
            cd "$SCRIPT_DIR"
            rm -rf "$TEMP_DIR"
        done
        
        # Report results
        if [[ $TEST_ERRORS -eq 0 ]]; then
            log "[test] ✓ All test modes passed successfully!"
        else
            err "[test] ✗ $TEST_ERRORS test mode(s) failed"
            exit 1
        fi
        exit 0
        ;;
esac

# Only define PKGVER and PKGVER-dependent variables for non-clean modes
PKGBUILD0="$SCRIPT_DIR/PKGBUILD.0"
readonly PKGBUILD0
if [[ ! -f "$PKGBUILD0" ]]; then
    err "Error: $PKGBUILD0 not found. Please create it from your original PKGBUILD."
    exit 1
fi
# Extract pkgver from PKGBUILD.0 without sourcing
# NOTE: PKGBUILD.0 is always a static template with a simple pkgver=... assignment.
# Dynamic or function-based pkgver is not supported or needed for this workflow.
PKGVER=$(awk -F= '/^[[:space:]]*pkgver[[:space:]]*=/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$PKGBUILD0" | tr -d "\"'")
if [[ -z "$PKGVER" ]]; then
    err "Error: Could not extract pkgver from $PKGBUILD0"
    exit 1
fi
readonly PKGVER
TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
readonly TARBALL
OUTDIR="$SCRIPT_DIR"
readonly OUTDIR
PKGBUILD="$SCRIPT_DIR/PKGBUILD"
SRCINFO="$SCRIPT_DIR/.SRCINFO"

# Only create the tarball for aur and local modes
if [[ "$MODE" == "aur" || "$MODE" == "local" ]]; then
    cd "$PROJECT_ROOT"
    # Determine the git reference to use for archiving
    # Try to use the tag that matches pkgver first, fall back to HEAD if tag doesn't exist
    GIT_REF="HEAD"
    if git -C "$PROJECT_ROOT" rev-parse "v${PKGVER}" >/dev/null 2>&1; then
        GIT_REF="v${PKGVER}"
        log "[$MODE] Using tag v${PKGVER} for archiving"
    elif git -C "$PROJECT_ROOT" rev-parse "${PKGVER}" >/dev/null 2>&1; then
        GIT_REF="${PKGVER}"
        log "[$MODE] Using tag ${PKGVER} for archiving"
    else
        warn "[$MODE] Warning: No tag found for version ${PKGVER}, using HEAD (this may cause checksum mismatches)"
    fi
    
    # Use git archive to create the release tarball, including only tracked files
    # This avoids hand-maintaining exclude lists by respecting .gitignore
    git -C "$PROJECT_ROOT" archive --format=tar --prefix="${PKGNAME}-${PKGVER}/" "$GIT_REF" | \
        gzip -n > "$OUTDIR/$TARBALL"
    log "Created $OUTDIR/$TARBALL using $GIT_REF"

    # Create GPG signature for aur mode only
    if [[ "$MODE" == "aur" ]]; then
        # Check for GPG secret key before signing
        if ! gpg --list-secret-keys --with-colons | grep -q '^sec:'; then
            err "Error: No GPG secret key found. Please generate or import a GPG key before signing."
            exit 1
        fi
        
        # Set signature file extension based on ASCII_ARMOR setting
        if [[ $ASCII_ARMOR -eq 1 ]]; then
            SIGNATURE_EXT=".asc"
            GPG_ARMOR_OPT="--armor"
            log "[aur] Using ASCII-armored signatures (.asc)"
        else
            SIGNATURE_EXT=".sig"
            GPG_ARMOR_OPT=""
            log "[aur] Using binary signatures (.sig)"
        fi
        
        # GPG key selection logic
        GPG_KEY=""
        if [[ -n "${GPG_KEY_ID:-}" ]]; then
            if [[ "${GPG_KEY_ID}" == "TEST_KEY_FOR_DRY_RUN" ]]; then
                # In test mode, skip GPG signing
                log "[aur] Test mode: Skipping GPG signing"
                GPG_KEY=""
            else
                GPG_KEY="$GPG_KEY_ID"
            fi
        else
            # List available secret keys and prompt user
            mapfile -t KEYS < <(gpg --list-secret-keys --with-colons | awk -F: '/^sec/ {print $5}')
            if [[ ${#KEYS[@]} -eq 0 ]]; then
                err "No GPG secret keys found."
                exit 1
            fi
            warn "Available GPG secret keys:" >&2
            for i in "${!KEYS[@]}"; do
                USER=$(gpg --list-secret-keys "${KEYS[$i]}" | grep uid | head -n1 | sed 's/.*] //')
                warn "$((i+1)). ${KEYS[$i]} ($USER)" >&2
            done
            prompt "Select a key [1-${#KEYS[@]}]: " choice 1
            if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#KEYS[@]} )); then
                err "Invalid selection."
                exit 1
            fi
            GPG_KEY="${KEYS[$((choice-1))]}"
        fi
        if [[ -n "$GPG_KEY" ]]; then
            gpg --detach-sign $GPG_ARMOR_OPT -u "$GPG_KEY" --output "$OUTDIR/$TARBALL$SIGNATURE_EXT" "$OUTDIR/$TARBALL"
            log "[aur] Created GPG signature: $OUTDIR/$TARBALL$SIGNATURE_EXT"
        elif [[ "${GPG_KEY_ID:-}" == "TEST_KEY_FOR_DRY_RUN" ]]; then
            # In test mode, create a dummy signature file
            touch "$OUTDIR/$TARBALL$SIGNATURE_EXT"
            log "[aur] Test mode: Created dummy signature file: $OUTDIR/$TARBALL$SIGNATURE_EXT"
        else
            gpg --detach-sign $GPG_ARMOR_OPT --output "$OUTDIR/$TARBALL$SIGNATURE_EXT" "$OUTDIR/$TARBALL"
            log "[aur] Created GPG signature: $OUTDIR/$TARBALL$SIGNATURE_EXT"
        fi
    fi
fi

cd "$SCRIPT_DIR"

if [[ "$MODE" == "local" || "$MODE" == "aur" ]]; then
    cp -f "$PKGBUILD0" "$PKGBUILD"
    log "[$MODE] PKGBUILD.0 copied to PKGBUILD."
    if [[ "$MODE" == "aur" ]]; then
        # Fix: Try correct link first, fallback to old 'v' link if needed
        sed -E -i "s|^([[:space:]]*source=\([^)]*\))([[:space:]]*#.*)?$|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}\")\2|" "$PKGBUILD"
        log "[aur] Updated source line in PKGBUILD (no 'v' before version)."
        # Check if the tarball exists on GitHub before running updpkgsums
        TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/${PKGVER}/${TARBALL}"
        if ! curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
            warn "[aur] WARNING: Release asset not found at $TARBALL_URL. Trying fallback with 'v' prefix."
            sed -i "s|source=(\".*\")|source=(\"https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}\")|" "$PKGBUILD"
            TARBALL_URL="https://github.com/eserlxl/${PKGNAME}/releases/download/v${PKGVER}/${TARBALL}"
            if ! curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
                # Asset not found - offer to upload automatically if gh CLI is available
                if command -v gh >/dev/null 2>&1; then
                    warn "[aur] Release asset not found. GitHub CLI (gh) detected."
                                    if [[ "${AUTO:-}" == "y" ]]; then
                    upload_choice="y"
                else
                    prompt "Do you want to upload the tarball and signature to GitHub releases automatically? [y/N] " upload_choice n
                fi
                    if [[ "$upload_choice" =~ ^[Yy]$ ]]; then
                        # Set signature file extension based on ASCII_ARMOR setting
                        if [[ $ASCII_ARMOR -eq 1 ]]; then
                            SIGNATURE_EXT=".asc"
                        else
                            SIGNATURE_EXT=".sig"
                        fi
                        
                        log "[aur] Uploading ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to GitHub release ${PKGVER}..."
                        # Upload tarball
                        if gh release upload "${PKGVER}" "$OUTDIR/$TARBALL" --repo "eserlxl/${PKGNAME}"; then
                            log "[aur] Successfully uploaded ${TARBALL}"
                        else
                            err "[aur] Failed to upload ${TARBALL}"
                            exit 1
                        fi
                        # Upload signature
                        if gh release upload "${PKGVER}" "$OUTDIR/$TARBALL$SIGNATURE_EXT" --repo "eserlxl/${PKGNAME}"; then
                            log "[aur] Successfully uploaded ${TARBALL}${SIGNATURE_EXT}"
                        else
                            err "[aur] Failed to upload ${TARBALL}${SIGNATURE_EXT}"
                            exit 1
                        fi
                        # Verify the upload was successful
                        sleep 2  # Give GitHub a moment to process
                        if curl --head --silent --fail "$TARBALL_URL" > /dev/null; then
                            log "[aur] Asset upload verified successfully."
                        else
                            warn "[aur] Asset upload may not be immediately available. Continuing anyway..."
                        fi
                    else
                        err "[aur] Release asset not found and automatic upload declined. Aborting."
                        echo "After uploading the tarball manually, run: makepkg -g >> PKGBUILD to update checksums."
                        exit 1
                    fi
                else
                    err "[aur] ERROR: Release asset not found at either location. GitHub CLI (gh) not available for automatic upload."
                    echo "Please install GitHub CLI (gh) or manually upload ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to the GitHub release page."
                    echo "After uploading the tarball, run: makepkg -g >> PKGBUILD to update checksums."
                    exit 1
                fi
            fi
        fi
        update_checksums
        generate_srcinfo
        log "[aur] Preparation complete."
        if command -v gh >/dev/null 2>&1; then
            echo "Assets have been automatically uploaded to GitHub release ${PKGVER}."
        else
            # Set signature file extension based on ASCII_ARMOR setting
            if [[ $ASCII_ARMOR -eq 1 ]]; then
                SIGNATURE_EXT=".asc"
            else
                SIGNATURE_EXT=".sig"
            fi
            echo "Now push the git tag and upload ${TARBALL} and ${TARBALL}${SIGNATURE_EXT} to the GitHub release page."
        fi
        echo "Then, copy the generated PKGBUILD and .SRCINFO to your local AUR git repository, commit, and push to update the AUR package."
        install_pkg "aur"
        exit 0
    else
        update_checksums
        generate_srcinfo
        install_pkg "$MODE"
        exit 0
    fi
elif [[ "$MODE" == "aur-git" ]]; then
    # Generate PKGBUILD.git from PKGBUILD.0
    cp -f "$PKGBUILD0" "$SCRIPT_DIR/PKGBUILD.git"
    sed -i 's/^pkgname=.*/pkgname=vglog-filter-git/' "$SCRIPT_DIR/PKGBUILD.git"
    sed -E -i 's|^source=\(.*\)|source=("git+https://github.com/eserlxl/vglog-filter.git#branch=main")|' "$SCRIPT_DIR/PKGBUILD.git"
    # Remove any b2sums or sha256sums lines
    sed -i '/^b2sums=/d' "$SCRIPT_DIR/PKGBUILD.git"
    sed -i '/^sha256sums=/d' "$SCRIPT_DIR/PKGBUILD.git"
    # Insert sha256sums=('SKIP') after the source= line using awk -v
    awk -v sums="sha256sums=('SKIP')" '/^source=/ { print; print sums; next } { print }' "$SCRIPT_DIR/PKGBUILD.git" > "$SCRIPT_DIR/PKGBUILD.git.tmp" && mv "$SCRIPT_DIR/PKGBUILD.git.tmp" "$SCRIPT_DIR/PKGBUILD.git"
    # shellcheck disable=SC2016
    # We want to replace the literal text '${pkgname}-${pkgver}' in the PKGBUILD template, not expand shell variables.
    sed -i 's|\${pkgname}-\${pkgver}|\${pkgname%-git}|g; s|\$pkgname-\$pkgver|\${pkgname%-git}|g' "$SCRIPT_DIR/PKGBUILD.git"
    # Remove the global replacements for ${pkgname}-${pkgver} and $pkgname-$pkgver to avoid affecting comments
    # Insert pkgver() as before if missing
    if ! grep -q '^pkgver()' "$SCRIPT_DIR/PKGBUILD.git"; then
        awk -v pkgver_func='pkgver() {
  cd "$srcdir/${pkgname%-git}"
  git describe --long --tags 2>/dev/null | sed "s/^v//;s/-/./g" || \
  printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}' '
            /^source=/ {
                print;
                print pkgver_func;
                next
            }
            { print }
        ' "$SCRIPT_DIR/PKGBUILD.git" > "$SCRIPT_DIR/PKGBUILD.git.tmp" && mv "$SCRIPT_DIR/PKGBUILD.git.tmp" "$SCRIPT_DIR/PKGBUILD.git"
    fi
    PKGBUILD_TEMPLATE="$SCRIPT_DIR/PKGBUILD.git"
    cp -f "$PKGBUILD_TEMPLATE" "$PKGBUILD"
    log "[aur-git] PKGBUILD.git generated and copied to PKGBUILD."
    # Set validpgpkeys if missing
    if ! grep -q '^validpgpkeys=' "$PKGBUILD"; then
        echo "validpgpkeys=('F677BC1E3BD7246E')" >> "$PKGBUILD"
    fi
    # Check for required tools
    require makepkg
    # Do NOT run updpkgsums for VCS (git) packages, as checksums must be SKIP
    # and updpkgsums would overwrite them with real sums, breaking the PKGBUILD.
    generate_srcinfo
    install_pkg "aur-git"
    exit 0
else
    usage
fi