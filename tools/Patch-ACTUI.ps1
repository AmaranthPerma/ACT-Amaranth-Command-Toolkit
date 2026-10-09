param(
    [Parameter(Mandatory=$true)][string]$SourceWad,
    [Parameter(Mandatory=$true)][string]$OutputWad
)
$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'gfx_tool.exe'
$tagPath = Join-Path $PSScriptRoot 'act_action.tag'
if (-not (Test-Path -LiteralPath $tool)) { throw 'gfx_tool.exe non trovato.' }
if (-not (Test-Path -LiteralPath $tagPath)) { throw 'act_action.tag non trovato.' }
$source = (Resolve-Path -LiteralPath $SourceWad).Path
$target = [IO.Path]::GetFullPath($OutputWad)
if ($source -eq $target) { throw 'Sorgente e destinazione devono essere diversi.' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('ACT-UI-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$extracted = Join-Path $temporary 'ess_ui.gfx'
$patched = Join-Path $temporary 'ess_ui_act.gfx'
try {
    & $tool extract --wad $source --name ess_ui --out $extracted
    if ($LASTEXITCODE -ne 0) { throw 'Impossibile estrarre ess_ui dal patch Ess.' }
    [byte[]]$movie = [IO.File]::ReadAllBytes($extracted)
    [byte[]]$tag = [IO.File]::ReadAllBytes($tagPath)
    if ($movie.Length -lt 32 -or [Text.Encoding]::ASCII.GetString($movie, 0, 3) -ne 'GFX') {
        throw 'Il filmato Ess estratto non e un GFX non compresso.'
    }
    if ([Text.Encoding]::ASCII.GetString($movie).Contains('ACTInit')) {
        throw 'ACT UI e gia presente nel patch. Ripristina il backup Ess prima di rigenerarlo.'
    }
    $bits = $movie[8] -shr 3
    $offset = 8 + [int][Math]::Ceiling((5 + 4 * $bits) / 8) + 4
    $firstFrame = -1
    while ($offset + 2 -le $movie.Length) {
        $header = [BitConverter]::ToUInt16($movie, $offset)
        $kind = $header -shr 6
        $size = $header -band 63
        $offset += 2
        $headerLength = 2
        if ($size -eq 63) {
            if ($offset + 4 -gt $movie.Length) { throw 'Tag GFX troncato.' }
            $size = [BitConverter]::ToUInt32($movie, $offset)
            $offset += 4
            $headerLength = 6
        }
        if ($kind -eq 1) { $firstFrame = $offset - $headerLength; break }
        if ($kind -eq 0 -or $offset + $size -gt $movie.Length) { throw 'Primo frame GFX non trovato.' }
        $offset += $size
    }
    if ($firstFrame -lt 0) { throw 'Primo frame GFX non trovato.' }
    $buffer = New-Object byte[] ($movie.Length + $tag.Length)
    [Array]::Copy($movie, 0, $buffer, 0, $firstFrame)
    [Array]::Copy($tag, 0, $buffer, $firstFrame, $tag.Length)
    [Array]::Copy($movie, $firstFrame, $buffer, $firstFrame + $tag.Length, $movie.Length - $firstFrame)
    [Array]::Copy([BitConverter]::GetBytes([uint32]$buffer.Length), 0, $buffer, 4, 4)
    [IO.File]::WriteAllBytes($patched, $buffer)
    & $tool build --wad $source --name ess_ui --movie $patched --out $target --merge $source
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $target)) { throw 'Creazione patch ACT fallita.' }
    Write-Host "Patch ACT UI creata: $target"
} finally {
    foreach ($file in @($extracted, $patched)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    }
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
