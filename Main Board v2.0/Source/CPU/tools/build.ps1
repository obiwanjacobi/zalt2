<#
.SYNOPSIS
    Build script for the Zalt2 CPU firmware.

.PARAMETER Target
    build_lib  - assemble ASM files listed in _asm.lst into osapi.lib
    build_bin  - compile C files listed in _src.lst and link against osapi.lib
    all        - build_lib then build_bin (default)
    clean      - remove build artefacts
#>
param(
    [ValidateSet('all', 'build_lib', 'build_bin', 'clean')]
    [string]$Target = 'all'
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:PATH;C:\z88dk\bin"

$LibName    = 'osapi'
$BinName    = 'firmware'
$AsmName     = 'asm'

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$OutDir     = Join-Path $ProjectRoot '.build'
$AsmOut     = Join-Path $OutDir 'asm'
$ObjOut     = Join-Path $OutDir 'obj'
$DispatchHeader = Join-Path $ProjectRoot 'src' 'ApiDispatch.h'

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
    $localLst = Join-Path $AsmOut '_lib_local.lst'
    Remove-Item $localLst -ErrorAction SilentlyContinue

    foreach ($line in Get-Content (Join-Path $ProjectRoot '_lib.lst')) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith(';')) { continue }
        $src = Join-Path $ProjectRoot ($line -replace '/', '\')
        Copy-Item $src $AsmOut -Force
        (Split-Path $src -Leaf) | Add-Content $localLst
    }

    Push-Location $AsmOut
    try {
        if (Test-Path $localLst) {
            Invoke-External z80asm, "-x$OutDir\$LibName.lib", '-m', '-s', "@$localLst"
        } else {
            Write-Host '[build_lib] No sources in _lib.lst — skipping library creation.'
        }
    } finally {
        Pop-Location
    }
    Write-Host '[build_lib] Done.'
}

function Build-Bin {
    Write-Host '[build_bin] Compiling and linking $($BinName) ...'
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    if (Test-Path $AsmOut) { Remove-Item $AsmOut -Recurse -Force }
    New-Item -ItemType Directory -Path $AsmOut -Force | Out-Null
    Copy-Item -Path (Join-Path $ProjectRoot "$AsmName\*") -Destination $AsmOut -Recurse -Force
    New-Item -ItemType Directory -Path $ObjOut -Force | Out-Null
    if (-not (Test-Path $DispatchHeader)) {
        @(
            '/* AUTO-GENERATED bootstrap header. Updated by post_build.ps1. */',
            '#ifndef __API_DISPATCH_H__',
            '#define __API_DISPATCH_H__',
            '',
            '#endif /* __API_DISPATCH_H__ */'
        ) | Set-Content $DispatchHeader
    }
    Get-ChildItem -Path $OutDir -Filter "$BinName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    $localLst = Join-Path $ObjOut '_obj_local.lst'
    $asmObjLst = Join-Path $AsmOut '_asm_obj_local.lst'
    $asmSrcLst = Join-Path $AsmOut '_asm_src_local.lst'
    Remove-Item $localLst -ErrorAction SilentlyContinue
    Remove-Item $asmObjLst -ErrorAction SilentlyContinue
    Remove-Item $asmSrcLst -ErrorAction SilentlyContinue

    Push-Location $ProjectRoot
    try {
        foreach ($line in Get-Content (Join-Path $ProjectRoot '_asm.lst')) {
            $line = $line.Trim()
            if (-not $line -or $line.StartsWith(';')) { continue }
            $src = Join-Path $ProjectRoot ($line -replace '/', '\')
            Copy-Item $src $AsmOut -Force
            (Split-Path $src -Leaf) | Add-Content $asmSrcLst
            $asmBase = [System.IO.Path]::GetFileNameWithoutExtension($line)
            "$AsmOut\$asmBase.o" | Add-Content $asmObjLst
        }

        $generatedAsmSources = @(
            "$AsmName\dispatch.asm"
        )
        foreach ($generatedAsm in $generatedAsmSources) {
            $src = Join-Path $ProjectRoot $generatedAsm
            if (-not (Test-Path $src)) { continue }

            Copy-Item $src $AsmOut -Force
            (Split-Path $src -Leaf) | Add-Content $asmSrcLst
            $asmBase = [System.IO.Path]::GetFileNameWithoutExtension($generatedAsm)
            "$AsmOut\$asmBase.o" | Add-Content $asmObjLst
        }

        Push-Location $AsmOut
        try {
            Invoke-External z80asm, '-m', '-s', "@$asmSrcLst", "-I$ProjectRoot\asm"
        } finally {
            Pop-Location
        }

        foreach ($line in Get-Content (Join-Path $ProjectRoot '_src.lst')) {
            $line = $line.Trim()
            if (-not $line -or $line.StartsWith(';')) { continue }
            $src  = $line -replace '/', '\'
            $base = [System.IO.Path]::GetFileNameWithoutExtension($src)
            $obj  = "$ObjOut\$base.o"

            Invoke-External zcc, '+z80', '-SO2', '-nostdlib', '--no-crt', '-compiler=sccz80', '-c', $src, '-o', $obj '-I', (Join-Path $ProjectRoot 'src'), '-I', (Join-Path $ProjectRoot 'src\os')
            $obj | Add-Content $localLst
        }

        # -reloc-info  : generate .reloc file with relocation records per section
        # -split-bin   : generate one .bin per section for page-granular loading
        Invoke-External z80asm, '-b', '-split-bin', '-reloc-info', '-m', '-v',
            "@$asmObjLst", "@$localLst", "-o=$OutDir\$BinName"
    } finally {
        Pop-Location
    }

    Write-Host '[build_bin] Done.'

    foreach ($binFile in Get-ChildItem -Path $OutDir -Filter "${BinName}_*.bin") {
        $disFile = Join-Path $OutDir ($binFile.BaseName + '.dis.asm')
        Write-Host "  Disassembling $($binFile.Name) ..."
        z88dk-dis -x "$OutDir\$BinName.map" -o 0 $binFile.FullName > $disFile
    }

    & "$PSScriptRoot\post_build.ps1" `
        -OutDir     $OutDir `
        -BinName    $BinName `
        -DispatchSrc (Join-Path $ProjectRoot "$AsmName\dispatch.asm") `
        -DispatchHeader $DispatchHeader
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
