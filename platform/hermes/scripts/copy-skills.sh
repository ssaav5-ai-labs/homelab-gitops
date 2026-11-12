#!/bin/sh
# git-sync exechook: mirror the freshly synced hermes-skills tree into the
# stable /skills emptyDir so Hermes never holds a resolved path to a worktree
# that git-sync later deletes. Runs with the synced worktree as its cwd.
set -eu

# Drop skill dirs that no longer exist upstream.
for d in /skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  [ -d "hermes-skills/$name" ] || rm -rf "$d"
done

# Copy each skill dir with plain -R (not -a/-p), so we don't try to chown or
# set timestamps on the root-owned /skills destination.
count=0
for d in hermes-skills/*/; do
  [ -d "$d" ] || continue
  cp -R "$d" /skills/
  count=$((count + 1))
done

echo "copied $count skills"
