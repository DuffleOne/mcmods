# mcmods

The mods we run on the server. `Minecraft/mods/` is the canonical jar list; `Minecraft/config/` has the matching configs for anything that needs tuning.

## Updating your mods

Pick the script for your OS and run it. It'll grab the latest pack from this repo and copy the jars into your `.minecraft/mods` folder. If you've got mods locally that aren't in the pack any more (old jars from a previous version, stuff you added yourself), it'll list them and ask `[y/N]` before deleting; say no and they stay put.

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

## Custom launchers (Prism, MultiMC, Modrinth App, CurseForge, ATLauncher...)

By default the script writes to the vanilla launcher's mods folder:

- Windows: `%APPDATA%\.minecraft\mods`
- macOS: `~/Library/Application Support/minecraft/mods`
- Linux: `~/.minecraft/mods`

If you're on a custom launcher, the per-instance `.minecraft` lives somewhere else. Find that folder (usually called `.minecraft` or `minecraft` inside the instance dir), then point the script at it with `MINECRAFT_DIR`. The path should be the folder that *contains* `mods/`, not the `mods/` folder itself.

PowerShell:

```powershell
$env:MINECRAFT_DIR = "C:\Path\To\Your\Instance\.minecraft"
.\update-mods.bat
```

bash/zsh:

```bash
MINECRAFT_DIR="$HOME/path/to/instance/.minecraft" ./update-mods.sh
```

## Stuff to know

- The script overwrites jars with the same name, so any local edits to existing mod files will be lost. Configs in `Minecraft/config/` aren't touched at the moment; that's a separate thing.
- If something blows up, you can always nuke your local `mods/` folder and re-run the script for a clean state.
- If you've got a mod you want added or removed from the pack, ping me.
