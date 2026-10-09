$ErrorActionPreference = 'Stop'
$gameDirectory = Split-Path -Parent $PSScriptRoot
$game = Join-Path $gameDirectory 'Mercenaries2.exe'
$companion = Join-Path $PSScriptRoot 'ACT.Controller.Camera.exe'
if (-not (Test-Path -LiteralPath $game)) { throw "Gioco non trovato: $game" }
if (-not (Test-Path -LiteralPath $companion)) { throw "Companion non trovato: $companion" }

Start-Process -FilePath $companion -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
if (-not (Get-Process -Name Mercenaries2 -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $game -WorkingDirectory $gameDirectory
}
