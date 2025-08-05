#!/usr/bin/env bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Generate a GPG key for CI (commit signing) with safe defaults.
# - Defaults to Ed25519 (recommended) and sign-only usage.
# - Exports armored public/secret keys and (optionally) single-line base64.
# - Writes outputs to a directory (default: ./ci-gpg-out) with mode 700.
# - By default, DOES NOT print secrets to stdout; use --print-secrets if you must.

set -Eeuo pipefail

# ---------- appearance & helpers ----------
is_tty=0; [[ -t 1 ]] && is_tty=1
c_red=$'\033[0;31m'; c_grn=$'\033[0;32m'; c_ylw=$'\033[1;33m'; c_cyn=$'\033[0;36m'; c_rst=$'\033[0m'
colorize() { if (( is_tty )); then printf '%s' "${1}"; fi; }
say()  { colorize "${c_cyn}";  printf '[*] %s\n' "$*"; colorize "${c_rst}"; }
ok()   { colorize "${c_grn}";  printf '[✓] %s\n' "$*"; colorize "${c_rst}"; }
warn() { colorize "${c_ylw}";  printf '[!] %s\n' "$*"; colorize "${c_rst}"; }
die()  { colorize "${c_red}";  printf '[✗] %s\n' "$*"; colorize "${c_rst}"; exit 1; }

# ---------- defaults ----------
NAME="vglog-filter CI Bot"
EMAIL="ci@vglog-filter.local"
COMMENT="Automated CI signing key"
EXPIRE="2y"
ALGO="ed25519"     # ed25519 | rsa4096
OUT_DIR="./ci-gpg-out"
PRINT_SECRETS=0
WRITE_B64=1        # also produce single-line base64 exports
PASSPHRASE=""      # generated if empty
UMASK_SET=077

# ---------- usage ----------
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --name STR           Real name (default: "$NAME")
  --email STR          Email (default: "$EMAIL")
  --comment STR        Comment (default: "$COMMENT")
  --expire STR         Expire date (default: "$EXPIRE", e.g. 1y, 0 for never)
  --algo ALG           Key algorithm: ed25519 | rsa4096 (default: $ALGO)
  --out-dir PATH       Output directory (default: $OUT_DIR)
  --no-b64             Do not create base64 single-line copies
  --print-secrets      Also print secret key & passphrase to stdout (NOT default)
  --passphrase STR     Use provided passphrase (otherwise a random one is created)
  -h, --help           Show this help

Outputs (in --out-dir):
  public.asc           ASCII-armored public key
  secret.asc           ASCII-armored private key (protected with passphrase)
  passphrase.txt       Passphrase (mode 600)
  public.asc.b64       Base64 (single-line) of public.asc      [optional]
  secret.asc.b64       Base64 (single-line) of secret.asc      [optional]

Recommended CI usage:
  - Put secret.asc (or secret.asc.b64) into GitHub Secret GPG_PRIVATE_KEY
  - Put public.asc (or public.asc.b64) into GitHub Variable/Secret GPG_PUBLIC_KEY
  - Put passphrase.txt into GitHub Secret GPG_PASSPHRASE
EOF
}

# ---------- parse args ----------
while (( $# )); do
  case "$1" in
    --name)        NAME=${2:?}; shift 2;;
    --email)       EMAIL=${2:?}; shift 2;;
    --comment)     COMMENT=${2:?}; shift 2;;
    --expire)      EXPIRE=${2:?}; shift 2;;
    --algo)        ALGO=${2:?}; shift 2;;
    --out-dir)     OUT_DIR=${2:?}; shift 2;;
    --no-b64)      WRITE_B64=0; shift;;
    --print-secrets) PRINT_SECRETS=1; shift;;
    --passphrase)  PASSPHRASE=${2:?}; shift 2;;
    -h|--help)     usage; exit 0;;
    --) shift; break;;
    *) die "Unknown option: $1 (use --help)";;
  esac
done

# ---------- preflight ----------
umask "$UMASK_SET"
command -v gpg >/dev/null 2>&1 || die "gpg is not installed"
if [[ -z "${PASSPHRASE}" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    PASSPHRASE="$(openssl rand -base64 32)"
  else
    # Fallback: read from /dev/urandom, base64
    PASSPHRASE="$(head -c 32 /dev/urandom | base64)"
  fi
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR" || true

# temp workdir for isolated GNUPGHOME
TMP_ROOT="$(mktemp -d)"
cleanup() {
  local ec=$?
  # Kill any gpg-agent in this GNUPGHOME
  if [[ -n "${GNUPGHOME:-}" && -d "$GNUPGHOME" ]]; then
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_ROOT"
  exit "$ec"
}
trap cleanup EXIT INT TERM

export GNUPGHOME="$TMP_ROOT/gnupg"
mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"

# Enable loopback pinentry for non-interactive export
printf 'allow-loopback-pinentry\nmax-cache-ttl 1\n' > "$GNUPGHOME/gpg-agent.conf"
printf 'batch\npinentry-mode loopback\n' > "$GNUPGHOME/gpg.conf"

# ---------- build batch file ----------
BATCH="$(mktemp "$TMP_ROOT/gpg-batch.XXXX")"
case "$ALGO" in
  ed25519)
    cat >"$BATCH" <<EOF
%echo Generating CI GPG key
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Name-Real: ${NAME}
Name-Email: ${EMAIL}
Name-Comment: ${COMMENT}
Expire-Date: ${EXPIRE}
Passphrase: ${PASSPHRASE}
%commit
%echo Done
EOF
    ;;
  rsa4096)
    cat >"$BATCH" <<EOF
%echo Generating CI GPG key
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: ${NAME}
Name-Email: ${EMAIL}
Name-Comment: ${COMMENT}
Expire-Date: ${EXPIRE}
Passphrase: ${PASSPHRASE}
%commit
%echo Done
EOF
    ;;
  *)
    die "Unsupported --algo '$ALGO'. Use ed25519 or rsa4096."
    ;;
esac

say "Generating GPG key ($ALGO, expires ${EXPIRE})…"
gpg --batch --generate-key "$BATCH"

# ---------- identify key (fingerprint & keyid) ----------
FPR="$(gpg --batch --with-colons --list-secret-keys "$EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[[ -n "$FPR" ]] || die "Failed to locate generated key fingerprint"
KEYID="${FPR:(-16)}"

ok "Key generated"
say "Key ID (long): $KEYID"
say "Fingerprint    : $FPR"

# ---------- exports ----------
PUB_ASC="$OUT_DIR/public.asc"
SEC_ASC="$OUT_DIR/secret.asc"
PASS_TXT="$OUT_DIR/passphrase.txt"

say "Exporting armored public/secret keys…"
gpg --armor --export "$FPR" > "$PUB_ASC"
gpg --batch --pinentry-mode loopback --passphrase "$PASSPHRASE" --armor --export-secret-keys "$FPR" > "$SEC_ASC"

[[ -s "$PUB_ASC" && -s "$SEC_ASC" ]] || die "Export failed"

printf '%s\n' "$PASSPHRASE" > "$PASS_TXT"
chmod 600 "$PASS_TXT" || true

to_oneline_b64() {
  if base64 --help 2>&1 | grep -qE -- '(-w|--wrap)'; then
    base64 -w 0
  else
    base64 | tr -d '\n'
  fi
}

if (( WRITE_B64 )); then
  say "Creating single-line base64 copies…"
  <"$PUB_ASC" to_oneline_b64 > "$OUT_DIR/public.asc.b64"
  <"$SEC_ASC" to_oneline_b64 > "$OUT_DIR/secret.asc.b64"
fi

# ---------- summary ----------
ok "GPG Key Setup Complete"
cat <<EOF
Outputs written to: $OUT_DIR

  - Public key  : $(realpath "$PUB_ASC")
  - Private key : $(realpath "$SEC_ASC")
  - Passphrase  : $(realpath "$PASS_TXT")
$( (( WRITE_B64 )) && printf '  - Public (b64): %s\n' "$(realpath "$OUT_DIR/public.asc.b64")" )
$( (( WRITE_B64 )) && printf '  - Secret (b64): %s\n' "$(realpath "$OUT_DIR/secret.asc.b64")" )

GitHub setup (recommended):
  • Secrets:
      GPG_PRIVATE_KEY  -> contents of secret.asc   (or secret.asc.b64)
      GPG_PASSPHRASE   -> contents of passphrase.txt
  • Variable/Secret:
      GPG_PUBLIC_KEY   -> contents of public.asc   (or public.asc.b64)

Local Git signing (optional):
  git config --global gpg.program gpg
  git config --global commit.gpgsign true
  git config --global user.signingkey $KEYID
EOF

if (( PRINT_SECRETS )); then
  warn "Printing secrets to stdout because --print-secrets was used."
  printf '\n-----8<----- GPG PRIVATE KEY (secret.asc) -----8<-----\n'
  cat "$SEC_ASC"
  printf '\n-----8<----- GPG PUBLIC KEY (public.asc)  -----8<-----\n'
  cat "$PUB_ASC"
  printf '\n-----8<----- PASSPHRASE --------------------8<-----\n%s\n' "$PASSPHRASE"
else
  warn "Secrets NOT printed. Use --print-secrets if you explicitly want them on stdout."
fi 