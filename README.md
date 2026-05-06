# mcmods

The mods we run on the server. `Minecraft/mods/` is the canonical jar list; `Minecraft/config/` has the matching configs for anything that needs tuning.

## Updating your mods

Pick the script for your OS and run it. It'll ask where your Minecraft pack lives (the folder that contains `mods/`), then grab the latest pack from this repo and copy the jars into that `mods/` folder. If you've got mods locally that aren't in the pack any more (old jars from a previous version, stuff you added yourself), it'll list them and ask `[y/N]` before deleting; say no and they stay put.

No git needed; the script just downloads a zip.

### Windows

Easiest path: grab `update-mods.bat` from this repo, drop it anywhere, double-click. A console pops up, does the thing, waits for you to press a key.

If you'd rather run it from PowerShell yourself:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\update-mods.ps1
```

The ExecutionPolicy bit is needed because Windows blocks unsigned scripts by default; `Bypass` only applies to that one run.

### macOS / Linux

Grab `update-mods.sh`, then in a terminal:

```bash
chmod +x update-mods.sh
./update-mods.sh
```

The `chmod` is a one-off; after that you can just run `./update-mods.sh`.

## What path to give it

The script always asks where your Minecraft pack lives. Pass the folder that *contains* `mods/`, not the `mods/` folder itself.

Common locations:

- Vanilla launcher, Windows: `%APPDATA%\.minecraft`
- Vanilla launcher, macOS: `~/Library/Application Support/minecraft`
- Vanilla launcher, Linux: `~/.minecraft`
- Custom launchers (Prism, MultiMC, Modrinth App, CurseForge, ATLauncher...): the per-instance `.minecraft` (or `minecraft`) folder inside the instance directory.

If you set `MINECRAFT_DIR` (bash/zsh) or `$env:MINECRAFT_DIR` (PowerShell), the prompt offers it as the default so you can just press Enter.

```bash
export MINECRAFT_DIR="$HOME/path/to/instance/.minecraft"
./update-mods.sh
```

```powershell
$env:MINECRAFT_DIR = "C:\Path\To\Your\Instance\.minecraft"
.\update-mods.bat
```

## Stuff to know

- The script self-updates from this repo before doing anything else, so you'll always run the latest. Set `MCMODS_SKIP_SELF_UPDATE=1` if you want to pin the version you've got.
- The script overwrites jars with the same name, so any local edits to existing mod files will be lost. Configs in `Minecraft/config/` aren't touched at the moment; that's a separate thing.
- If something blows up, you can always nuke your local `mods/` folder and re-run the script for a clean state.
- If you've got a mod you want added or removed from the pack, ping me.
