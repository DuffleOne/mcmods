#!/usr/bin/env bash
# Pulls the latest mods from https://github.com/DuffleOne/mcmods and syncs
# them into your Minecraft mods folder. The script always asks for the
# Minecraft pack location (the folder that contains mods/, e.g. a Prism
# instance's .minecraft).
set -euo pipefail
shopt -s nullglob

REPO_URL="https://github.com/DuffleOne/mcmods/archive/refs/heads/main.zip"
SELF_URL="https://raw.githubusercontent.com/DuffleOne/mcmods/main/update-mods.sh"

self_update() {
  [ "${MCMODS_SKIP_SELF_UPDATE:-}" = "1" ] && return 0
  command -v curl >/dev/null 2>&1 || return 0

  local script_dir script_path tmp_script
  script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || return 0
  script_path="$script_dir/$(basename "$0")"
  [ -f "$script_path" ] || return 0
  [ -w "$script_path" ] || return 0

  tmp_script="$(mktemp)"
  if ! curl -fsSL -o "$tmp_script" "$SELF_URL"; then
    rm -f "$tmp_script"
    return 0
  fi

  # Sanity check: the download should look like a bash script.
  if ! head -n 1 "$tmp_script" | grep -q '^#!'; then
    rm -f "$tmp_script"
    return 0
  fi

  if ! cmp -s "$script_path" "$tmp_script"; then
    echo "Updating script to latest version..."
    mv "$tmp_script" "$script_path"
    chmod +x "$script_path"
    export MCMODS_SKIP_SELF_UPDATE=1
    exec "$script_path" "$@"
  fi
  rm -f "$tmp_script"
}

self_update "$@"

prompt_mc_dir() {
  local default input expanded prompt
  default="${MINECRAFT_DIR:-}"
  while :; do
    if [ -n "$default" ]; then
      prompt="Path to your Minecraft pack (the folder containing mods/) [$default]: "
    else
      prompt="Path to your Minecraft pack (the folder containing mods/): "
    fi
    read -rp "$prompt" input < /dev/tty
    if [ -z "$input" ]; then
      input="$default"
    fi
    # Expand a leading ~ to $HOME.
    case "$input" in
      "~"|"~/"*) expanded="$HOME${input#\~}" ;;
      *) expanded="$input" ;;
    esac
    if [ -z "$expanded" ]; then
      echo "Path is required." >&2
      continue
    fi
    if [ ! -d "$expanded" ]; then
      echo "Not a directory: $expanded" >&2
      continue
    fi
    printf '%s\n' "$expanded"
    return
  done
}

for cmd in curl unzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

MC_DIR="$(prompt_mc_dir)"
MODS_DIR="$MC_DIR/mods"

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
  echo "Found mods locally that aren't in the remote pack."
  echo "I'll ask about each one; default is to keep."
  echo
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    read -rp "Delete $f? [y/N] " response < /dev/tty
    case "$response" in
      [yY]|[yY][eE][sS])
        rm -f "$MODS_DIR/$f"
        echo "  deleted"
        ;;
      *)
        echo "  kept"
        ;;
    esac
  done <<< "$dangling"
fi

echo "Done."
