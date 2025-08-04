#!/bin/bash
set -e

# Check if we are on alpha branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "alpha" ]; then
    echo "Error: This script must be run on the alpha branch. Current branch: $current_branch"
    exit 1
fi

# Configure Git identity once (or put in ~/.gitconfig)
git config --global user.name "🤖"
git config user.email "lxldev.contact@gmail.com"

# Always make sure we have the latest branches
git fetch origin

# If it was a merge
git merge --abort 2>/dev/null || true

# If it was a rebase
git rebase --abort 2>/dev/null || true

# Switch to alpha
git checkout alpha

################ MERGE STARTS #######################
# Merge latest main into alpha before starting work
#git merge origin/main --no-edit

# Push the merge so alpha is always up-to-date with main
#git push origin alpha
################ MERGE ENDS #######################

################ RESET STARTS #######################
# Reset alpha to main (local only for now)
git reset --hard origin/main

# Force push to overwrite the remote alpha branch
git push origin alpha --force
################ RESET ENDS #######################

# If changes are made, commit and push
if ! git diff --quiet; then
    git add .
    git commit -m "Alpha branch auto-update"
    git push origin alpha
else
    echo "No changes to commit."
fi
