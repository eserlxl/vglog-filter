#!/bin/bash
set -e
cd /tmp/test_simple
base_ref=$(git rev-list --max-parents=0 HEAD)
echo "Base ref: $base_ref"
commit_count=$(git rev-list --count "$base_ref"..HEAD)
echo "Commit count: $commit_count"
if [[ "$commit_count" -eq 0 ]]; then
  echo "No commits in range - should return 1"
  exit 1
else
  echo "Commits in range - should return 0"
  exit 0
fi
