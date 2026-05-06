# Pulls the latest mods from https://github.com/DuffleOne/mcmods and syncs
# them into your Minecraft mods folder. The script always asks for the
# Minecraft pack location (the folder that contains mods\).
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

function Read-MinecraftDir {
    $Default = $env:MINECRAFT_DIR
    while ($true) {
        if ($Default) {
            $Prompt = "Path to your Minecraft pack (the folder containing mods\) [$Default]"
        } else {
            $Prompt = 'Path to your Minecraft pack (the folder containing mods\)'
        }
        $Input = Read-Host $Prompt
        if (-not $Input) { $Input = $Default }
        if (-not $Input) {
            Write-Host 'Path is required.' -ForegroundColor Red
            continue
        }
        # Expand environment variables like %APPDATA% and a leading ~.
        $Expanded = [System.Environment]::ExpandEnvironmentVariables($Input)
        if ($Expanded.StartsWith('~')) {
            $Expanded = Join-Path $HOME $Expanded.Substring(1).TrimStart('\','/')
        }
        if (-not (Test-Path -LiteralPath $Expanded -PathType Container)) {
            Write-Host "Not a directory: $Expanded" -ForegroundColor Red
            continue
        }
        return $Expanded
    }
}

$McDir = Read-MinecraftDir
$ModsDir = Join-Path $McDir 'mods'

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
