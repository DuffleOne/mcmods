#!/usr/bin/env bash
set -euo pipefail

REPO="/home/amp/.ampdata/instances/NeoMike01/Minecraft"
cd "$REPO"

# Pull remote changes first so we don't push on top of a stale base.
# --autostash handles any in-progress local edits across the rebase.
git pull --rebase --autostash origin main

# Only commit if there are changes
if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -m "Auto-commit: $(date -Iseconds)"
    git push origin main
fi
