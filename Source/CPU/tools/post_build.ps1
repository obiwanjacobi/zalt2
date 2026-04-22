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
    [int]$PageSize = 4096,
    [string[]]$ExcludeSections = @('dispatch', 'IGNORE')
)

$ErrorActionPreference = 'Stop'
$mapFile = Join-Path $OutDir "$BinName.map"

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

$sectionSizes  = @{}   # section name -> size in bytes
$publicSymbols = [System.Collections.Generic.List[hashtable]]::new()

foreach ($line in Get-Content $mapFile) {
    $line = $line.Trim()
    if (-not $line) { continue }

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

$grouped = $publicSymbols | Group-Object { $_.Section }

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
        $stub = "dispatch$($sym.Name)"   # e.g. dispatch_Stream_Read
        $null = $sb.AppendLine("PUBLIC $stub")
        $null = $sb.AppendLine("${stub}: JP $($sym.Name)")
    }
    $null = $sb.AppendLine("")
}

$destDir = Split-Path $DispatchSrc -Parent
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
[System.IO.File]::WriteAllText($DispatchSrc, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "  Written: $DispatchSrc ($($publicSymbols.Count) stubs)"

Write-Host "`n[post_build] Done."
