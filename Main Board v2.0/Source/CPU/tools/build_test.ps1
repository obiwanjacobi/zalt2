<#
.SYNOPSIS
    Builds the DeZog unit test binary for the Zalt2 CPU sources.

    Assembles every source listed in _test.lst into a single flat binary
    (.build/test/unittests.bin) plus the .lis/.map files DeZog needs to map
    addresses back to the sources.

.PARAMETER Clean
    Remove the unit test build output instead of building.

.PARAMETER Org
    Load address of the binary. Must match "loadObjs" in .vscode/launch.json.
#>
param(
    [switch]$Clean,
    [string]$Org = '0x8000'
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:PATH;C:\z88dk\bin"

$BinName     = 'unittests'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$OutDir      = Join-Path $ProjectRoot '.build\test'
$ListFile    = Join-Path $ProjectRoot '_test.lst'

if ($Clean) {
    if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
    Write-Host '[test] Cleaned.'
    return
}

$sources = @(
    Get-Content $ListFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith(';') } |
    ForEach-Object { $_ -replace '/', '\' }
)
if (-not $sources) { throw "No sources listed in $ListFile" }

foreach ($src in $sources) {
    if (-not (Test-Path (Join-Path $ProjectRoot $src))) {
        throw "Source not found: $src"
    }
}

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Write-Host "[test] Assembling $BinName.bin at $Org ..."
Push-Location $ProjectRoot
try {
    # -b/-r : link all modules into one binary at the given address
    # -l/-m : list and map files, both required by DeZog (z88dkv2)
    & z80asm -b "-r=$Org" -l -m -s '-I=asm' '-I=test\asm' `
        '-O=.build\test' "-o=$BinName.bin" @sources
    if ($LASTEXITCODE -ne 0) { throw "z80asm failed (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

$bin = Join-Path $OutDir "$BinName.bin"
Write-Host ("[test] Done: {0} ({1} bytes)" -f $bin, (Get-Item $bin).Length)
