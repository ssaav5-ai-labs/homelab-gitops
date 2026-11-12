#!/bin/sh
# git-sync exechook: mirror the freshly synced hermes-skills tree into the
# stable /skills emptyDir so Hermes never holds a resolved path to a worktree
# that git-sync later deletes. Runs with the synced worktree as its cwd.
set -eu
rm -rf /skills/*
cp -a hermes-skills/. /skills/
