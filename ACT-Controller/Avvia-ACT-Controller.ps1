$ErrorActionPreference = 'Stop'
$companion = Join-Path $PSScriptRoot 'ACT.Controller.Camera.exe'
if (-not (Test-Path -LiteralPath $companion)) {
    throw "Companion non trovato: $companion"
}
Start-Process -FilePath $companion -WindowStyle Hidden
Write-Host 'ACT Controller avviato. L2 + L3 invia F4 quando Mercenaries 2 e in primo piano.'
Write-Host 'Il companion si chiude quando il gioco viene chiuso.'
