<#
.SYNOPSIS
    Post-build automation for z80 paged firmware:
    1. Check each section fits in a 4KB page.
    2. Pad each per-section .bin to exactly 4KB.
    3. Generate bios/dispatch.asm from the previous build's public symbols
       (the dispatch page jump table — included in the NEXT build).

.PARAMETER OutDir      Path to the build output directory (.build)
.PARAMETER BinName     Base name of the linked binary (e.g. 'firmware')
.PARAMETER DispatchSrc Destination for the generated dispatch.asm
.PARAMETER PageSize    MMU page size in bytes (default 4096)
.PARAMETER ExcludeSections  Sections to skip when padding (e.g. dispatch)
#>
param(
    [Parameter(Mandatory)][string]$OutDir,
    [Parameter(Mandatory)][string]$BinName,
    [Parameter(Mandatory)][string]$DispatchSrc,
    [Parameter(Mandatory)][string]$DispatchHeader,
    [int]$PageSize = 4096,
    [string[]]$ExcludeSections = @('dispatch', 'IGNORE')
)

$ErrorActionPreference = 'Stop'
$mapFile = Join-Path $OutDir "$BinName.map"
$manifestFile = Join-Path $OutDir "$BinName.manifest.json"

function Get-RelocOffsets {
    param([string]$RelocPath)

    if (-not (Test-Path $RelocPath)) {
        return @()
    }

    $bytes = [System.IO.File]::ReadAllBytes($RelocPath)
    if (($bytes.Length % 2) -ne 0) {
        throw "Reloc file has odd byte count: $RelocPath"
    }

    $offsets = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $bytes.Length; $i += 2) {
        $offsets.Add($bytes[$i] -bor ($bytes[$i + 1] -shl 8))
    }

    return @($offsets)
}

function Test-IsApiSymbol {
    param([string]$SymbolName)

    return $SymbolName -imatch '^_?Api_'
}

function Get-DispatchStubName {
    param([string]$SymbolName)

    $publicName = $SymbolName.TrimStart('_')
    if ($publicName -imatch '^Api_(.+)$') {
        return "ApiDispatch_$($Matches[1])"
    }

    return "ApiDispatch_$publicName"
}

if (-not (Test-Path $mapFile)) {
    Write-Error "Map file not found: $mapFile"
    exit 1
}

# -------------------------------------------------------------------------
# Parse map file
# Lines of interest:
#   __<Section>_size  = $XXXX ; const, public, def, ...   <- section sizes
#   _symbol           = $XXXX ; addr, public, ...          <- public symbols
# -------------------------------------------------------------------------

$sectionHeads  = @{}   # section name -> linked base address
$sectionSizes  = @{}   # section name -> size in bytes
$publicSymbols = [System.Collections.Generic.List[hashtable]]::new()

foreach ($line in Get-Content $mapFile) {
    $line = $line.Trim()
    if (-not $line) { continue }

    # Section base: __Sys_head = $001D ; const, public, def, ...
    if ($line -match '^__(.+)_head\s*=\s*\$([0-9A-Fa-f]+)\s*;.*\bdef\b') {
        $sectionHeads[$Matches[1]] = [Convert]::ToInt32($Matches[2], 16)
        continue
    }

    # Section size: __Sys_size = $013A ; const, public, def, ...
    if ($line -match '^__(.+)_size\s*=\s*\$([0-9A-Fa-f]+)\s*;.*\bdef\b') {
        $sectionSizes[$Matches[1]] = [Convert]::ToInt32($Matches[2], 16)
        continue
    }

    # Public address symbol: _name = $XXXX ; addr, public, , module, section, file:line
    if ($line -match '^(\S+)\s*=\s*\$([0-9A-Fa-f]+)\s*;\s*addr,\s*public,\s*,\s*\S*,\s*(\S+),') {
        $sym     = $Matches[1]
        $addr    = [Convert]::ToInt32($Matches[2], 16)
        $section = $Matches[3]

        # Skip z88dk internal symbols and local compiler labels
        if ($sym -match '^(__|l_)') { continue }

        $publicSymbols.Add(@{ Name = $sym; Addr = $addr; Section = $section })
    }
}

$dispatchSymbols = @(
    $publicSymbols |
    Where-Object { Test-IsApiSymbol -SymbolName $_.Name }
)

# -------------------------------------------------------------------------
# 1. Check section sizes
# -------------------------------------------------------------------------
Write-Host "`n[post_build] Section size check (page=$( '${0:X}' -f $PageSize ) bytes):"
$overflow = $false
foreach ($kvp in $sectionSizes.GetEnumerator()) {
    $name = $kvp.Key
    $size = $kvp.Value
    if ($ExcludeSections -contains $name) { continue }
    # Skip empty and z88dk internal pseudo-sections
    if ($size -eq 0) { continue }
    $status = if ($size -le $PageSize) { 'OK' } else { 'OVERFLOW'; $overflow = $true }
    Write-Host ("  {0,-24} {1,5} bytes / {2} bytes  [{3}]" -f $name, $size, $PageSize, $status)
}
if ($overflow) {
    Write-Error "One or more sections exceed the page size of $PageSize bytes."
    exit 1
}

# -------------------------------------------------------------------------
# 2. Pad per-section .bin files to PageSize
# -------------------------------------------------------------------------
Write-Host "`n[post_build] Padding section binaries to $PageSize bytes:"
$pad = [byte]0xFF
$binPattern = Join-Path $OutDir "${BinName}_*.bin"
foreach ($binFile in Get-ChildItem -Path $binPattern -ErrorAction SilentlyContinue) {
    $secName = $binFile.BaseName -replace "^${BinName}_", ''
    if ($ExcludeSections -contains $secName) { continue }

    $bytes = [System.IO.File]::ReadAllBytes($binFile.FullName)
    $current = $bytes.Length
    if ($current -gt $PageSize) {
        Write-Error "  $($binFile.Name): $current bytes exceeds page size — cannot pad."
        exit 1
    }
    if ($current -lt $PageSize) {
        $padded = New-Object byte[] $PageSize
        [Array]::Copy($bytes, $padded, $current)
        for ($i = $current; $i -lt $PageSize; $i++) { $padded[$i] = $pad }
        [System.IO.File]::WriteAllBytes($binFile.FullName, $padded)
        Write-Host ("  {0,-40} {1,5} -> {2} bytes (padded {3})" -f $binFile.Name, $current, $PageSize, ($PageSize - $current))
    } else {
        Write-Host ("  {0,-40} {1} bytes (exact)" -f $binFile.Name, $current)
    }
}

# -------------------------------------------------------------------------
# 3. Generate dispatch.asm
# Produces a SECTION dispatch with one PUBLIC JP stub per public symbol.
# The dispatch section is mapped to a fixed page so all cross-section CALLs
# target stable addresses. The OS patches the JP targets when loading modules.
# -------------------------------------------------------------------------
Write-Host "`n[post_build] Generating dispatch table: $DispatchSrc"

$grouped = $dispatchSymbols | Group-Object { $_.Section }

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine("; AUTO-GENERATED by tools/post_build.ps1 — DO NOT EDIT")
$null = $sb.AppendLine("; Rebuild once after any change to public symbols.")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("SECTION dispatch")
$null = $sb.AppendLine("")

foreach ($group in ($grouped | Sort-Object Name)) {
    $secName = $group.Name
    $syms    = $group.Group | Sort-Object { $_.Name }

    $null = $sb.AppendLine("; --- Section: $secName ---")
    foreach ($sym in $syms) {
        $null = $sb.AppendLine("EXTERN $($sym.Name)")
    }
    $null = $sb.AppendLine("")
    foreach ($sym in $syms) {
        $stub = Get-DispatchStubName -SymbolName $sym.Name
        $cStub = "_$stub"
        $null = $sb.AppendLine("PUBLIC $stub")
        $null = $sb.AppendLine("PUBLIC $cStub")
        $null = $sb.AppendLine("${stub}:")
        $null = $sb.AppendLine("${cStub}: JP $($sym.Name)")
    }
    $null = $sb.AppendLine("")
}

$destDir = Split-Path $DispatchSrc -Parent
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
[System.IO.File]::WriteAllText($DispatchSrc, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host "  Written: $DispatchSrc ($($dispatchSymbols.Count) stubs)"

Write-Host "[post_build] Generating dispatch C header: $DispatchHeader"

$headerSb = [System.Text.StringBuilder]::new()
$headerGuard = '__API_DISPATCH_H__'
$null = $headerSb.AppendLine('/* AUTO-GENERATED by tools/post_build.ps1 - DO NOT EDIT */')
$null = $headerSb.AppendLine('/* Include this before API headers to redirect C calls through dispatch stubs. */')
$null = $headerSb.AppendLine("")
$null = $headerSb.AppendLine("#ifndef $headerGuard")
$null = $headerSb.AppendLine("#define $headerGuard")
$null = $headerSb.AppendLine("")
foreach ($sym in ($dispatchSymbols | Sort-Object Name)) {
    $sourceName = $sym.Name.TrimStart('_')
    $targetName = Get-DispatchStubName -SymbolName $sym.Name
    $null = $headerSb.AppendLine("#define $sourceName $targetName")
}
$null = $headerSb.AppendLine("")
$null = $headerSb.AppendLine("#endif /* $headerGuard */")

$headerDir = Split-Path $DispatchHeader -Parent
if (-not (Test-Path $headerDir)) { New-Item -ItemType Directory -Path $headerDir | Out-Null }
[System.IO.File]::WriteAllText($DispatchHeader, $headerSb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host "  Written: $DispatchHeader ($($dispatchSymbols.Count) redirects)"

# -------------------------------------------------------------------------
# 4. Generate manifest JSON
# The runtime package needs binaries and reloc payloads, plus enough metadata
# for the loader to place sections and patch exported entry points.
# -------------------------------------------------------------------------
Write-Host "`n[post_build] Generating section manifest: $manifestFile"

$manifestSections = [System.Collections.Generic.List[object]]::new()
$manifestLoadPages = [System.Collections.Generic.List[object]]::new()
$manifestDispatchPatches = [System.Collections.Generic.List[object]]::new()
$sectionPageMap = @{}
$dispatchStubSize = 3
$dispatchStubIndex = 0
foreach ($sectionName in ($sectionSizes.Keys | Sort-Object)) {
    if ($ExcludeSections -contains $sectionName) { continue }

    $size = $sectionSizes[$sectionName]
    if ($size -eq 0) { continue }

    $binFile = "${BinName}_${sectionName}.bin"
    $relocFile = "${BinName}_${sectionName}.reloc"
    $binPath = Join-Path $OutDir $binFile
    $relocPath = Join-Path $OutDir $relocFile
    $linkedBase = if ($sectionHeads.ContainsKey($sectionName)) { $sectionHeads[$sectionName] } else { 0 }
    $relocOffsets = @(Get-RelocOffsets -RelocPath $relocPath)
    $exports = @(
        $publicSymbols |
        Where-Object { $_.Section -eq $sectionName } |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                name = $_.Name
                linkedAddress = $_.Addr
                offset = $_.Addr - $linkedBase
                apiExport = (Test-IsApiSymbol -SymbolName $_.Name)
            }
        }
    )

    $pageIndex = $manifestLoadPages.Count
    $pageType = if ($sectionName -eq 'dispatch' -or $sectionName -like 'dispatch_*') {
        'dispatch'
    } elseif ($sectionName -like 'code_*' -or $sectionName -eq 'sys') {
        'code'
    } elseif ($sectionName -like 'data_*' -or $sectionName -like 'rodata_*' -or $sectionName -like 'bss_*') {
        'data'
    } else {
        'fixed'
    }
    $pageFlags = @('read')
    if ($pageType -in @('code', 'dispatch', 'fixed')) { $pageFlags += 'execute' }
    if ($pageType -eq 'data') { $pageFlags += 'write' }
    if ($pageType -eq 'code') { $pageFlags += 'relocatable' }

    $sectionPageMap[$sectionName] = $pageIndex

    $manifestLoadPages.Add([ordered]@{
        index = $pageIndex
        name = "page_${pageIndex}_${sectionName}"
        sourceSection = $sectionName
        type = $pageType
        flags = $pageFlags
        linkedPageBase = $linkedBase
        pageSize = $PageSize
        usedBytes = $size
        image = [ordered]@{
            file = $binFile
            size = if (Test-Path $binPath) { (Get-Item $binPath).Length } else { 0 }
        }
        reloc = [ordered]@{
            file = $relocFile
            size = if (Test-Path $relocPath) { (Get-Item $relocPath).Length } else { 0 }
            count = $relocOffsets.Count
            offsets = $relocOffsets
        }
        logicalSections = @(
            [ordered]@{
                name = $sectionName
                pageOffset = 0
                size = $size
            }
        )
    })

    $manifestSections.Add([ordered]@{
        name = $sectionName
        linkedBase = $linkedBase
        size = $size
        pageSize = $PageSize
        loadPageIndex = $pageIndex
        pageOffset = 0
        bin = [ordered]@{
            file = $binFile
            size = if (Test-Path $binPath) { (Get-Item $binPath).Length } else { 0 }
        }
        reloc = [ordered]@{
            file = $relocFile
            size = if (Test-Path $relocPath) { (Get-Item $relocPath).Length } else { 0 }
            count = $relocOffsets.Count
            offsets = $relocOffsets
        }
        exports = $exports
    })
}

foreach ($sectionName in ($sectionSizes.Keys | Sort-Object)) {
    if ($ExcludeSections -contains $sectionName) { continue }

    $size = $sectionSizes[$sectionName]
    if ($size -eq 0) { continue }

    $exports = @(
        $dispatchSymbols |
        Where-Object { $_.Section -eq $sectionName } |
        Sort-Object Name
    )

    foreach ($sym in $exports) {
        $targetPageIndex = $sectionPageMap[$sectionName]
        $targetPage = $manifestLoadPages[$targetPageIndex]
        $targetOffset = $sym.Addr - $targetPage.linkedPageBase

        $manifestDispatchPatches.Add([ordered]@{
            stubName = Get-DispatchStubName -SymbolName $sym.Name
            stubOffset = $dispatchStubIndex * $dispatchStubSize
            targetSymbol = $sym.Name
            targetSection = $sectionName
            targetLoadPageIndex = $targetPageIndex
            targetOffset = $targetOffset
        })

        $dispatchStubIndex++
    }
}

$manifest = [ordered]@{
    format = 'zalt-section-manifest-v2'
    program = $BinName
    pageSize = $PageSize
    mapFile = [System.IO.Path]::GetFileName($mapFile)
    dispatchSource = [System.IO.Path]::GetFileName($DispatchSrc)
    dispatch = [ordered]@{
        stubSize = $dispatchStubSize
        patches = $manifestDispatchPatches
    }
    loadPages = $manifestLoadPages
    sections = $manifestSections
}

$manifestJson = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($manifestFile, $manifestJson, [System.Text.Encoding]::UTF8)
Write-Host "  Written: $manifestFile ($($manifestSections.Count) sections)"

Write-Host "`n[post_build] Done."
