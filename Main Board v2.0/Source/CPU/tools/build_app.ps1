<#
.SYNOPSIS
    Build script for a Zalt2 Application.

.PARAMETER Target
    build_bin  - compile C files listed in _src.lst and link against bios.lib
    all        - build_bin (default)
    clean      - remove build artefacts
#>
param(
    [ValidateSet('all', 'build_bin', 'clean')]
    [string]$Target = 'all',
    [string]$AppRoot = (Get-Location).Path,
    [string]$SysInclude = (Join-Path $PSScriptRoot '..\src'),
    [string]$OsLib = (Join-Path $PSScriptRoot '..\.build\osapi.lib')
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:PATH;C:\z88dk\bin"

$LibName    = 'bios'
$BinName    = 'app'
$ProjectRoot = (Resolve-Path $AppRoot).Path
$OutDir     = Join-Path $ProjectRoot '.build'
$AsmOut     = Join-Path $OutDir 'asm'
$ObjOut     = Join-Path $OutDir 'obj'
$DispatchHeader = Join-Path $OutDir 'ApiDispatch.h'

# ---------------------------------------------------------------------------

function Invoke-External {
    param([string[]]$CmdArgs)
    & $CmdArgs[0] $CmdArgs[1..($CmdArgs.Length - 1)]
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $($CmdArgs -join ' ')"
    }
}

function Build-Bin {
    Write-Host '[build_bin] Compiling and linking $($BinName) ...'
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AsmOut -Force | Out-Null
    New-Item -ItemType Directory -Path $ObjOut -Force | Out-Null
    # Remove any ApiDispatch.h that may have been left in source directories —
    # it must only live in .build\ to avoid shadowing the OS-generated header.
    Get-ChildItem -Path $ProjectRoot -Filter 'ApiDispatch.h' -Recurse -File |
        Where-Object { $_.FullName -ne $DispatchHeader } |
        Remove-Item -Force
    if (-not (Test-Path $DispatchHeader)) {
        New-Item -ItemType Directory -Path (Split-Path $DispatchHeader -Parent) -Force | Out-Null
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
        $asmLstPath = Join-Path $ProjectRoot '_asm.lst'
        if (Test-Path $asmLstPath) {
            foreach ($line in Get-Content $asmLstPath) {
                $line = $line.Trim()
                if (-not $line -or $line.StartsWith(';')) { continue }
                $src = Join-Path $ProjectRoot ($line -replace '/', '\')
                Copy-Item $src $AsmOut -Force
                (Split-Path $src -Leaf) | Add-Content $asmSrcLst
                $asmBase = [System.IO.Path]::GetFileNameWithoutExtension($line)
                ".build\asm\$asmBase.o" | Add-Content $asmObjLst
            }
        }

        $dispatchSrc = Join-Path $ProjectRoot 'dispatch.asm'
        if (Test-Path $dispatchSrc) {
            Copy-Item $dispatchSrc $AsmOut -Force
            'dispatch.asm' | Add-Content $asmSrcLst
            ".build\asm\dispatch.o" | Add-Content $asmObjLst
        }

        if (Test-Path $asmSrcLst) {
            Push-Location $AsmOut
            try {
                Invoke-External z80asm, '-m', '-s', "@$asmSrcLst"
            } finally {
                Pop-Location
            }
        }

        foreach ($line in Get-Content (Join-Path $ProjectRoot '_src.lst')) {
            $line = $line.Trim()
            if (-not $line -or $line.StartsWith(';')) { continue }
            $src  = $line -replace '/', '\'
            $base = [System.IO.Path]::GetFileNameWithoutExtension($src)
            $obj  = ".build\obj\$base.o"

            $iSys = Resolve-Path -Relative -Path $SysInclude
            Invoke-External zcc, '+z80', '-SO2', '-nostdlib', '--no-crt', '-compiler=sccz80',
                "-I$iSys", '-Isrc', '-I.build',
                '-c', $src, '-o', $obj
            $obj | Add-Content $localLst
        }

        # -reloc-info  : generate .reloc file with relocation records per section
        # -split-bin   : generate one .bin per section for page-granular loading
        $linkArgs = [System.Collections.Generic.List[string]]@('z80asm', '-b', '-split-bin', '-reloc-info', '-m', '-v')
        if (Test-Path $asmObjLst) { $linkArgs.Add('@.build\asm\_asm_obj_local.lst') }
        if (Test-Path $localLst)  { $linkArgs.Add('@.build\obj\_obj_local.lst') }
        if (Test-Path $OsLib) {
            # Verify the file is a valid z80asm library (magic: 'Z80LMF')
            $magic = [System.IO.File]::ReadAllBytes($OsLib) | Select-Object -First 6
            if (([System.Text.Encoding]::ASCII.GetString($magic)) -eq 'Z80LMF') {
                # Pass as -L<dir> -l<name> — z80asm does not accept .lib as a positional arg
                $relLibDir = Resolve-Path -Relative -Path (Split-Path $OsLib -Parent)
                $libName   = [System.IO.Path]::GetFileNameWithoutExtension($OsLib)
                $linkArgs.Add("-L$relLibDir")
                $linkArgs.Add("-l$libName")
            } else {
                Write-Warning "Skipping invalid or empty library: $OsLib"
            }
        }
        $linkArgs.Add("-o=.build\$BinName")
        Invoke-External $linkArgs.ToArray()
    } finally {
        Pop-Location
    }

    Write-Host '[build_bin] Done.'

    foreach ($binFile in Get-ChildItem -Path $OutDir -Filter "${BinName}_*.bin") {
        $disFile = Join-Path $OutDir ($binFile.BaseName + '.dis.asm')
        Write-Host "  Disassembling $($binFile.Name) ..."
        z88dk-dis -x "$OutDir\$BinName.map" -o 0 $binFile.FullName > $disFile
    }

    & "$PSScriptRoot\post_build_app.ps1" `
        -OutDir     $OutDir `
        -BinName    $BinName `
        -DispatchSrc (Join-Path $OutDir 'dispatch.asm') `
        -DispatchHeader $DispatchHeader
    if ($LASTEXITCODE -ne 0) { throw 'post_build_app failed.' }
}

function Invoke-Clean {
    Write-Host '[clean] Removing build artefacts ...'
    if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
    Write-Host '[clean] Done.'
}

# ---------------------------------------------------------------------------

try {
    switch ($Target) {
        'build_bin' { Build-Bin }
        'clean'     { Invoke-Clean }
        'all'       { Build-Bin }
    }
    Write-Host 'All done.'
} catch {
    Write-Host "Build failed: $_"
    exit 1
}
