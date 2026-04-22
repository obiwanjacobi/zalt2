<#
.SYNOPSIS
    Build script for the Zalt2 CPU firmware.

.PARAMETER Target
    build_lib  - assemble ASM files listed in _asm.lst into bios.lib
    build_bin  - compile C files listed in _src.lst and link against bios.lib
    all        - build_lib then build_bin (default)
    clean      - remove build artefacts
#>
param(
    [ValidateSet('all', 'build_lib', 'build_bin', 'clean')]
    [string]$Target = 'all'
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:PATH;C:\z88dk\bin"

$LibName    = 'bios'
$BinName    = 'firmware'
$ProjectRoot = $PWD.Path
$OutDir     = Join-Path $ProjectRoot '.build'
$AsmOut     = Join-Path $OutDir 'asm'
$ObjOut     = Join-Path $OutDir 'obj'

# ---------------------------------------------------------------------------

function Invoke-External {
    param([string[]]$CmdArgs)
    & $CmdArgs[0] $CmdArgs[1..($CmdArgs.Length - 1)]
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $($CmdArgs -join ' ')"
    }
}

function Build-Lib {
    Write-Host '[build_lib] Assembling $LibName.lib ...'
    New-Item -ItemType Directory -Path $AsmOut -Force | Out-Null
    $localLst = Join-Path $AsmOut '_asm_local.lst'
    Remove-Item $localLst -ErrorAction SilentlyContinue

    foreach ($line in Get-Content (Join-Path $ProjectRoot '_asm.lst')) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith(';')) { continue }
        $src = Join-Path $ProjectRoot ($line -replace '/', '\')
        Copy-Item $src $AsmOut -Force
        (Split-Path $src -Leaf) | Add-Content $localLst
    }

    Push-Location $AsmOut
    try {
        Invoke-External z80asm, "-x$OutDir\$LibName.lib", '-m', '-s', "@$localLst"
    } finally {
        Pop-Location
    }
    Write-Host '[build_lib] Done.'
}

function Build-Bin {
    Write-Host '[build_bin] Compiling and linking $($BinName) ...'
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ObjOut -Force | Out-Null
    $localLst = Join-Path $ObjOut '_obj_local.lst'
    Remove-Item $localLst -ErrorAction SilentlyContinue

    foreach ($line in Get-Content (Join-Path $ProjectRoot '_src.lst')) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith(';')) { continue }
        $src  = Join-Path $ProjectRoot ($line -replace '/', '\')
        $base = [System.IO.Path]::GetFileNameWithoutExtension($src)
        $obj  = Join-Path $ObjOut "$base.o"

        Invoke-External zcc, '+z80', '-SO2', '-nostdlib', '--no-crt', -compiler=sccz80, '-c', $src, '-o', $obj
        $obj | Add-Content $localLst
    }

    # -reloc-info  : generate .reloc file with relocation records per section
    # -split-bin   : generate one .bin per section for page-granular loading
    #'-reloc-info', 
    Invoke-External z80asm, '-b', '-split-bin', '-m', '-v',
        "@$localLst", "-L$OutDir", "-l$LibName", "-o$OutDir\$BinName"

    Write-Host '[build_bin] Done.'

    foreach ($binFile in Get-ChildItem -Path $OutDir -Filter "${BinName}_*.bin") {
        $disFile = Join-Path $OutDir ($binFile.BaseName + '.dis.asm')
        Write-Host "  Disassembling $($binFile.Name) ..."
        z88dk-dis -x "$OutDir\$BinName.map" -o 0 $binFile.FullName > $disFile
    }

    & "$PSScriptRoot\post_build.ps1" `
        -OutDir     $OutDir `
        -BinName    $BinName `
        -DispatchSrc (Join-Path $ProjectRoot 'bios\dispatch.asm')
    if ($LASTEXITCODE -ne 0) { throw 'post_build failed.' }
}

function Invoke-Clean {
    Write-Host '[clean] Removing build artefacts ...'
    if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
    Write-Host '[clean] Done.'
}

# ---------------------------------------------------------------------------

try {
    switch ($Target) {
        'build_lib' { Build-Lib }
        'build_bin' { Build-Bin }
        'clean'     { Invoke-Clean }
        'all'       { Build-Lib; Build-Bin }
    }
    Write-Host 'All done.'
} catch {
    Write-Host "Build failed: $_"
    exit 1
}
