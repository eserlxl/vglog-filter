#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Keep an "alpha" branch synchronized with a base branch (e.g., main).
# Enhanced with safety features, dry-run support, and better error handling.
#
# Examples:
#   ./sync_alpha.sh                                   # ff-only merge origin/main -> alpha
#   ./sync_alpha.sh --strategy merge --merge-commit   # allow a merge commit if needed
#   ./sync_alpha.sh --strategy reset --yes            # HARD RESET alpha to origin/main (push with lease)
#   ./sync_alpha.sh --alpha alpha --base main --remote origin --checkout
#
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

# -------------------- appearance / logging --------------------
is_tty=0; [[ -t 1 ]] && is_tty=1
RED=$([[ $is_tty -eq 1 ]] && printf '\033[0;31m' || printf '')
# GRN=$([[ $is_tty -eq 1 ]] && printf '\033[0;32m' || printf '')
YEL=$([[ $is_tty -eq 1 ]] && printf '\033[1;33m' || printf '')
BLU=$([[ $is_tty -eq 1 ]] && printf '\033[0;34m' || printf '')
NC=$([[ $is_tty -eq 1 ]] && printf '\033[0m' || printf '')

die() { printf '%b[ERR]%b %s\n' "$RED" "$NC" "${1:-unknown error}" >&2; exit 1; }
info(){ printf '%b[INFO]%b %s\n' "$BLU" "$NC" "$*"; }
warn(){ printf '%b[WARN]%b %s\n' "$YEL" "$NC" "$*"; }

# -------------------- configuration --------------------
DRY_RUN=0
ASSUME_YES=0
ALLOW_DIRTY=0
SKIP_FETCH=0
CHECKOUT=0
STRATEGY="reset"          # merge | reset (default to reset for backward compatibility)
MERGE_COMMIT=0            # for strategy=merge: allow non-ff merge commit
REMOTE="origin"
ALPHA="alpha"
BASE_BRANCH=""            # default auto-detected main/master if empty
BOT_NAME="🤖"
BOT_EMAIL="lxldev.contact@gmail.com"
IDENTITY_SCOPE="local"    # local | global
APPLY_IDENTITY=1          # default to true for backward compatibility
FORCE=0                   # when pushing reset, use --force instead of --force-with-lease

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --strategy <merge|reset>   Sync method (default: reset)
  --merge-commit             For merge: allow a merge commit when ff-only isn't possible
  --alpha <name>             Target branch to update (default: alpha)
  --base <name>              Base branch name (default: auto: main or master on REMOTE)
  --remote <name>            Remote name (default: origin)
  --checkout                 If not on --alpha, switch to it (else fail)
  --allow-dirty              Don't require a clean working tree
  --skip-fetch               Skip 'git fetch'
  --dry-run                  Print actions only
  --yes, -y                  Assume yes for confirmations
  --apply-identity           Apply Git identity below (safe: scope=local by default)
  --bot-name <name>          Identity name (used with --apply-identity)
  --bot-email <email>        Identity email (used with --apply-identity)
  --identity-scope <local|global>  (default: local)
  --force                    With --strategy reset: push using --force (not --force-with-lease)
  -h, --help                 Show this help
EOF
}

confirm() {
  local prompt=$1
  if (( ASSUME_YES )); then return 0; fi
  if (( is_tty )); then
    read -r -p "$prompt [y/N] " ans
    [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
  else
    return 1
  fi
}

run() {
  if (( DRY_RUN )); then
    printf '%b[DRY]%b %s\n' "$YEL" "$NC" "$*"
  else
    "$@"
  fi
}

# -------------------- parse args --------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strategy) STRATEGY=${2:-}; shift 2;;
    --merge-commit) MERGE_COMMIT=1; shift;;
    --alpha) ALPHA=${2:-}; shift 2;;
    --base) BASE_BRANCH=${2:-}; shift 2;;
    --remote) REMOTE=${2:-}; shift 2;;
    --checkout) CHECKOUT=1; shift;;
    --allow-dirty) ALLOW_DIRTY=1; shift;;
    --skip-fetch) SKIP_FETCH=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    --yes|-y) ASSUME_YES=1; shift;;
    --apply-identity) APPLY_IDENTITY=1; shift;;
    --bot-name) BOT_NAME=${2:-}; shift 2;;
    --bot-email) BOT_EMAIL=${2:-}; shift 2;;
    --identity-scope) IDENTITY_SCOPE=${2:-}; shift 2;;
    --force) FORCE=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

[[ "$STRATEGY" == "merge" || "$STRATEGY" == "reset" ]] || die "Invalid --strategy: $STRATEGY"
[[ "$IDENTITY_SCOPE" == "local" || "$IDENTITY_SCOPE" == "global" ]] || die "Invalid --identity-scope"

# -------------------- sanity checks --------------------
command -v git >/dev/null 2>&1 || die "git not found"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a Git repository"

current_branch=$(git branch --show-current || echo "")
if [[ "$current_branch" != "$ALPHA" ]]; then
  if (( CHECKOUT )); then
    info "Switching to branch '$ALPHA' (current: '$current_branch')"
    run git checkout "$ALPHA"
    current_branch="$ALPHA"
  else
    die "Must run on '$ALPHA' or pass --checkout (current: '$current_branch')"
  fi
fi

# Require clean tree unless allowed
if (( ! ALLOW_DIRTY )); then
  if ! git diff-index --quiet HEAD --; then
    die "Working tree is dirty. Commit/stash or pass --allow-dirty."
  fi
fi

# Determine base branch if not given (prefer main, else master)
detect_base() {
  if git show-ref --verify --quiet "refs/remotes/$REMOTE/main"; then
    echo "main"
  elif git show-ref --verify --quiet "refs/remotes/$REMOTE/master"; then
    echo "master"
  else
    echo "main"
  fi
}
if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH=$(detect_base)
  info "Auto-detected base branch: $BASE_BRANCH"
fi

# -------------------- identity management --------------------
if (( APPLY_IDENTITY )); then
  [[ -n "$BOT_NAME"  ]] || die "--apply-identity requires --bot-name"
  [[ -n "$BOT_EMAIL" ]] || die "--apply-identity requires --bot-email"
  if [[ "$IDENTITY_SCOPE" == "global" ]]; then
    info "Setting global Git identity: $BOT_NAME <$BOT_EMAIL>"
    run git config --global user.name "$BOT_NAME"
    run git config user.email "$BOT_EMAIL"
  else
    info "Setting local Git identity: $BOT_NAME <$BOT_EMAIL>"
    run git config user.name "$BOT_NAME"
    run git config user.email "$BOT_EMAIL"
  fi
fi

# -------------------- sync logic --------------------
if (( ! SKIP_FETCH )); then
  info "Fetching from $REMOTE"
  run git fetch "$REMOTE" --prune
fi

# If a merge/rebase is in progress, offer to abort
if [[ -e "$(git rev-parse --git-dir)/MERGE_HEAD" ]]; then
  warn "Merge in progress detected."
  if confirm "Abort merge?"; then run git merge --abort; else die "Resolve the merge first."; fi
fi
if [[ -d "$(git rev-parse --git-dir)/rebase-apply" || -d "$(git rev-parse --git-dir)/rebase-merge" ]]; then
  warn "Rebase in progress detected."
  if confirm "Abort rebase?"; then run git rebase --abort; else die "Resolve the rebase first."; fi
fi

case "$STRATEGY" in
  merge)
    info "Merging $REMOTE/$BASE_BRANCH into $ALPHA"
    if (( MERGE_COMMIT )); then
      # Allow a merge commit when needed; prefer ff when possible
      run git merge --ff "$REMOTE/$BASE_BRANCH" --no-edit
    else
      # Fast-forward only; fail if divergent
      if run git merge --ff-only "$REMOTE/$BASE_BRANCH"; then
        info "Fast-forwarded $ALPHA to $REMOTE/$BASE_BRANCH"
      else
        die "Non fast-forward merge required. Re-run with --merge-commit if intended."
      fi
    fi
    # Push only if there are changes (avoid no-op push noise)
    if ! git diff --quiet "$REMOTE/$ALPHA"...HEAD; then
      info "Pushing $ALPHA to $REMOTE"
      run git push "$REMOTE" "$ALPHA"
    else
      info "No changes to push."
    fi
    ;;

  reset)
    warn "You are about to HARD RESET '$ALPHA' to '$REMOTE/$BASE_BRANCH' and push."
    warn "This rewrites remote history for '$ALPHA'."
    if ! confirm "Proceed?"; then die "Aborted by user."; fi

    info "Hard resetting $ALPHA to $REMOTE/$BASE_BRANCH"
    run git reset --hard "$REMOTE/$BASE_BRANCH"

    # Push safely with lease by default
    if (( FORCE )); then
      info "Force pushing (no lease) $ALPHA -> $REMOTE"
      run git push "$REMOTE" "$ALPHA" --force
    else
      info "Force pushing with lease $ALPHA -> $REMOTE"
      run git push "$REMOTE" "$ALPHA" --force-with-lease
    fi
    ;;
esac

# Legacy behavior: commit and push any local changes
if ! git diff --quiet; then
    info "Committing local changes"
    run git add .
    run git commit -m "Alpha branch auto-update"
    run git push "$REMOTE" "$ALPHA"
else
    info "No local changes to commit."
fi

info "Done."
