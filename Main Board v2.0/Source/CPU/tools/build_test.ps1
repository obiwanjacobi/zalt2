<#
.SYNOPSIS
    Builds DeZog unit test binaries for the Zalt2 CPU sources.

    Each target is a subfolder of test/asm/ that contains a <target>.lst file
    listing the sources to assemble. Output goes to test/.build/<target>/.

.PARAMETER Clean
    Remove build output for the selected target(s) instead of building.

.PARAMETER Target
    Name of a single target to build (e.g. 'lib' or 'os').
    Omit to build all discovered targets.

.PARAMETER Org
    Load address of the binary. Must match "loadObjs" in .vscode/launch.json.
#>
param(
    [switch]$Clean,
    [string]$Target = '',
    [string]$Org = '0x8000'
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:PATH;C:\z88dk\bin"

$BinName     = 'unittests'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$TestAsmDir  = Join-Path $ProjectRoot 'test\asm'
$BuildRoot   = Join-Path $ProjectRoot 'test\asm\.build'

# Discover targets: test/asm/<name>/ dirs that have a matching <name>.lst
$allTargets = Get-ChildItem -Path $TestAsmDir -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).lst") } |
    Select-Object -ExpandProperty Name

$targets = if ($Target -and $Target -ne 'all') { @($Target) } else { $allTargets }

if (-not $targets) {
    Write-Warning 'No targets found. Add a <name>.lst inside test/asm/<name>/.'
    return
}

if ($Clean) {
    foreach ($t in $targets) {
        $outDir = Join-Path $BuildRoot $t
        if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
        Write-Host "[test/$t] Cleaned."
    }
    return
}

foreach ($t in $targets) {
    $outDir   = Join-Path $BuildRoot $t
    $listFile = Join-Path $TestAsmDir "$t\$t.lst"

    if (-not (Test-Path $listFile)) { throw "List file not found: $listFile" }

    $sources = @(
        Get-Content $listFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith(';') } |
        ForEach-Object { $_ -replace '/', '\' }
    )
    if (-not $sources) { throw "No sources listed in $listFile" }

    foreach ($src in $sources) {
        if (-not (Test-Path (Join-Path $ProjectRoot $src))) {
            throw "Source not found: $src"
        }
    }

    if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    Write-Host "[test/$t] Assembling $BinName.bin at $Org ..."
    Push-Location $ProjectRoot
    try {
        $relOut = [IO.Path]::GetRelativePath($ProjectRoot, $outDir)
        # -b/-r : link all modules into one binary at the given address
        # -l/-m : list and map files, both required by DeZog (z88dkv2)
        & z80asm -b "-r=$Org" -l -m -s '-I=asm' '-I=test\asm' "-I=test\asm\$t" `
            "-O=$relOut" "-o=$BinName.bin" @sources
        if ($LASTEXITCODE -ne 0) { throw "z80asm failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }

    $bin = Join-Path $outDir "$BinName.bin"
    Write-Host ("[test/$t] Done: {0} ({1} bytes)" -f $bin, (Get-Item $bin).Length)
}
