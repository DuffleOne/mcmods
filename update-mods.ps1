# Pulls the latest mods from https://github.com/DuffleOne/mcmods and syncs
# them into your Minecraft mods folder. Override the location by setting
# $env:MINECRAFT_DIR (point it at the folder that contains mods\).
#
# Run from PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-mods.ps1
# Or just double-click update-mods.bat.

#requires -Version 5.0
$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/DuffleOne/mcmods/archive/refs/heads/main.zip'
$SelfUrl = 'https://raw.githubusercontent.com/DuffleOne/mcmods/main/update-mods.ps1'

function Invoke-SelfUpdate {
    if ($env:MCMODS_SKIP_SELF_UPDATE -eq '1') { return }

    $ScriptPath = $PSCommandPath
    if (-not $ScriptPath -or -not (Test-Path -LiteralPath $ScriptPath)) { return }

    $TmpScript = [System.IO.Path]::GetTempFileName()
    try {
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $SelfUrl -OutFile $TmpScript -UseBasicParsing
        } catch {
            return
        } finally {
            $ProgressPreference = 'Continue'
        }

        # Sanity check: should look like a PowerShell script, not an HTML error page.
        $FirstLine = Get-Content -LiteralPath $TmpScript -TotalCount 1
        if ($FirstLine -match '^\s*<') { return }

        $LocalHash  = (Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256).Hash
        $RemoteHash = (Get-FileHash -LiteralPath $TmpScript  -Algorithm SHA256).Hash

        if ($LocalHash -ne $RemoteHash) {
            Write-Host 'Updating script to latest version...'
            Move-Item -LiteralPath $TmpScript -Destination $ScriptPath -Force
            $env:MCMODS_SKIP_SELF_UPDATE = '1'
            & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
            exit $LASTEXITCODE
        }
    } finally {
        if (Test-Path -LiteralPath $TmpScript) {
            Remove-Item -LiteralPath $TmpScript -Force -ErrorAction SilentlyContinue
        }
    }
}

Invoke-SelfUpdate

function Get-MinecraftDir {
    if ($env:MINECRAFT_DIR) { return $env:MINECRAFT_DIR }
    return Join-Path $env:APPDATA '.minecraft'
}

$McDir = Get-MinecraftDir
$ModsDir = Join-Path $McDir 'mods'

if (-not (Test-Path -LiteralPath $McDir)) {
    Write-Host "Minecraft directory not found: $McDir" -ForegroundColor Red
    Write-Host "Set `$env:MINECRAFT_DIR to point at the folder containing mods\." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $ModsDir | Out-Null

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    $ZipPath = Join-Path $Tmp 'mods.zip'

    Write-Host 'Downloading mod pack...'
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath -UseBasicParsing
    $ProgressPreference = 'Continue'

    Write-Host 'Extracting...'
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $Tmp -Force

    $ExtractedMods = Join-Path $Tmp 'mcmods-main\Minecraft\mods'
    if (-not (Test-Path -LiteralPath $ExtractedMods)) {
        Write-Host "Couldn't find Minecraft\mods\ in the downloaded archive." -ForegroundColor Red
        exit 1
    }

    Write-Host "Syncing mods to $ModsDir..."
    Copy-Item -Path (Join-Path $ExtractedMods '*') -Destination $ModsDir -Recurse -Force

    $RemoteJars = @(Get-ChildItem -LiteralPath $ExtractedMods -Filter '*.jar' -File | Select-Object -ExpandProperty Name)
    $LocalJars  = @(Get-ChildItem -LiteralPath $ModsDir       -Filter '*.jar' -File | Select-Object -ExpandProperty Name)
    $Dangling   = @($LocalJars | Where-Object { $RemoteJars -notcontains $_ })

    if ($Dangling.Count -gt 0) {
        Write-Host ''
        Write-Host "Found mods locally that aren't in the remote pack."
        Write-Host "I'll ask about each one; default is to keep."
        Write-Host ''
        foreach ($f in $Dangling) {
            $Response = Read-Host "Delete $f? [y/N]"
            if ($Response -match '^(?i:y|yes)$') {
                Remove-Item -LiteralPath (Join-Path $ModsDir $f) -Force
                Write-Host '  deleted'
            } else {
                Write-Host '  kept'
            }
        }
    }

    Write-Host 'Done.'
}
finally {
    Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
