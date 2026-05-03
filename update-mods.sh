#!/usr/bin/env bash
# Pulls the latest mods from https://github.com/DuffleOne/mcmods and syncs
# them into your Minecraft mods folder. Override the location by setting
# MINECRAFT_DIR (point it at the folder that contains mods/, e.g. a Prism
# instance's .minecraft).
set -euo pipefail
shopt -s nullglob

REPO_URL="https://github.com/DuffleOne/mcmods/archive/refs/heads/main.zip"

detect_mc_dir() {
  if [ -n "${MINECRAFT_DIR:-}" ]; then
    printf '%s\n' "$MINECRAFT_DIR"
    return
  fi
  case "$(uname -s)" in
    Darwin) printf '%s\n' "$HOME/Library/Application Support/minecraft" ;;
    Linux)  printf '%s\n' "$HOME/.minecraft" ;;
    *) echo "Unsupported OS: $(uname -s). Set MINECRAFT_DIR to override." >&2; exit 1 ;;
  esac
}

for cmd in curl unzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

MC_DIR="$(detect_mc_dir)"
MODS_DIR="$MC_DIR/mods"

if [ ! -d "$MC_DIR" ]; then
  echo "Minecraft directory not found: $MC_DIR" >&2
  echo "Set MINECRAFT_DIR to point at the folder containing mods/." >&2
  exit 1
fi

mkdir -p "$MODS_DIR"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading mod pack..."
curl -fsSL -o "$TMPDIR/mods.zip" "$REPO_URL"

echo "Extracting..."
unzip -q "$TMPDIR/mods.zip" -d "$TMPDIR"

EXTRACTED_MODS="$TMPDIR/mcmods-main/Minecraft/mods"
if [ ! -d "$EXTRACTED_MODS" ]; then
  echo "Couldn't find Minecraft/mods/ in the downloaded archive." >&2
  exit 1
fi

echo "Syncing mods to $MODS_DIR..."
cp -R "$EXTRACTED_MODS/." "$MODS_DIR/"

list_jars() {
  local dir="$1"
  ( cd "$dir" && for f in *.jar; do [ -f "$f" ] && printf '%s\n' "$f"; done ) | sort
}

remote_jars="$(list_jars "$EXTRACTED_MODS")"
local_jars="$(list_jars "$MODS_DIR")"
dangling="$(comm -23 <(printf '%s\n' "$local_jars") <(printf '%s\n' "$remote_jars"))"

if [ -n "$dangling" ]; then
  echo
  echo "These mods exist locally but not in the remote pack:"
  printf '%s\n' "$dangling" | sed 's/^/  - /'
  echo
  read -rp "Delete them? [y/N] " response
  case "$response" in
    [yY]|[yY][eE][sS])
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        rm -f "$MODS_DIR/$f"
        echo "  deleted $f"
      done <<< "$dangling"
      ;;
    *)
      echo "Left them in place."
      ;;
  esac
fi

echo "Done."
