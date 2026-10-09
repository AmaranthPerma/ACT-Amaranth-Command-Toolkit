param([string]$GameDirectory = 'C:\Program Files (x86)\EA Games\Mercenaries 2 World in Flames')
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$root = $PSScriptRoot
$scripts = Join-Path $game 'scripts'
$patch = Join-Path $game 'data\vz-patch.wad'
$backup = Join-Path $game 'data\vz-patch.pre-ACT.wad'
$legacyBackup = Join-Path $game 'data\vz-patch.pre-ACT-UI.wad'
$candidate = Join-Path $game 'data\vz-patch.act-build.wad'
if (Get-Process -Name Mercenaries2 -ErrorAction SilentlyContinue) { throw 'Chiudi Mercenaries 2 prima di installare ACT.' }
foreach ($required in @((Join-Path $game 'Mercenaries2.exe'), $patch,
    (Join-Path $scripts 'OnLoad\1_Ess.lua'), (Join-Path $scripts 'OnLoad\2_EssNames.lua'),
    (Join-Path $scripts 'lua_bridge_DEV.asi'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Dipendenza mancante: $required" }
}
if (-not (Test-Path -LiteralPath $backup)) {
    if (Test-Path -LiteralPath $legacyBackup) {
        Copy-Item -LiteralPath $legacyBackup -Destination $backup
    } else {
        Copy-Item -LiteralPath $patch -Destination $backup
    }
}
& (Join-Path $root 'tools\Patch-ACTUI.ps1') -SourceWad $backup -OutputWad $candidate
if (-not (Test-Path -LiteralPath $candidate)) { throw 'La patch ACT UI non e stata creata.' }
Copy-Item -LiteralPath $candidate -Destination $patch -Force
Remove-Item -LiteralPath $candidate -Force

foreach ($folder in @('OnLoad', 'OnKey')) {
    $targetFolder = Join-Path $scripts $folder
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $root ('scripts\' + $folder)) -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetFolder $_.Name) -Force
    }
}
$companionFolder = Join-Path $game 'ACT-Controller'
New-Item -ItemType Directory -Path $companionFolder -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $root 'ACT-Controller') -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $companionFolder $_.Name) -Force
}

function Merge-LoaderConfig([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "lua_loader.ini mancante: $path" }
    $all = [System.Collections.Generic.List[string]]::new()
    $actNames = '^(?:3_ACTState|3_ACTLang|4_ACTVehicleCatalog|4_ACTTroops|5_ACTWar|6_ACTExtras|7_ACTCamera|8_ACTFlat|ACT)\.lua\s*='
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -notmatch $actNames) { $all.Add($line) }
    }
    $loadIndex = -1; $keyIndex = -1
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($all[$i] -match '^\s*\[OnLoad\]\s*$') { $loadIndex = $i }
        if ($all[$i] -match '^\s*\[OnKey\]\s*$') { $keyIndex = $i }
    }
    if ($loadIndex -lt 0 -or $keyIndex -lt 0) { throw "Sezioni OnLoad/OnKey mancanti: $path" }
    $loadLines = @('3_ACTState.lua=30', '3_ACTLang.lua=35',
        '4_ACTVehicleCatalog.lua=38', '4_ACTTroops.lua=40',
        '6_ACTExtras.lua=60', '8_ACTFlat.lua=80')
    $all.InsertRange($loadIndex + 1, [string[]]$loadLines)
    if ($keyIndex -gt $loadIndex) { $keyIndex += $loadLines.Count }
    $all.Insert($keyIndex + 1, 'ACT.lua=f4')
    [IO.File]::WriteAllLines($path, $all, [Text.UTF8Encoding]::new($false))
}
$config = Join-Path $scripts 'lua_loader.ini'
if (-not (Test-Path -LiteralPath ($config + '.pre-ACT'))) { Copy-Item -LiteralPath $config -Destination ($config + '.pre-ACT') }
Merge-LoaderConfig $config
# A normal 32-bit game can read a VirtualStore shadow of this configuration.
if ($game -match '^[A-Za-z]:\\') {
    $virtual = Join-Path $env:LOCALAPPDATA ('VirtualStore\' + $game.Substring(3) + '\scripts\lua_loader.ini')
    if (Test-Path -LiteralPath $virtual) {
        if (-not (Test-Path -LiteralPath ($virtual + '.pre-ACT'))) {
            Copy-Item -LiteralPath $virtual -Destination ($virtual + '.pre-ACT')
        }
        Merge-LoaderConfig $virtual
    }
}
Write-Host 'ACT installato. Apri il gioco con ACT-Controller\Avvia-Gioco-con-ACT.cmd.'
