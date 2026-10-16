<#
.SYNOPSIS
Links every addon folder of this repo into the ESO AddOns folder via directory junctions.

.DESCRIPTION
An addon folder is a top-level folder <Name> containing <Name>.txt or <Name>.addon.
For each one, AddOns\<Name> becomes a junction to it, so the game sees the same flat
layout users get from a release zip. Junctions pointing elsewhere (e.g. after moving
the repo) are recreated; real folders are never touched. Safe to re-run any time.

Remove a junction with `cmd /c rmdir AddOns\<Name>` - in Windows PowerShell 5.1,
Remove-Item -Recurse on a junction deletes the files it points to (in this repo).

.PARAMETER AddOnsPath
The ESO AddOns folder. Default: the AddOns folder next to this repo.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\link-addons.ps1
#>
param(
    [string]$AddOnsPath = (Join-Path $PSScriptRoot '..\..\AddOns')
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
    throw "AddOns folder not found: $AddOnsPath (pass -AddOnsPath)"
}
$AddOnsPath = (Resolve-Path -LiteralPath $AddOnsPath).Path

$skipped = 0
foreach ($dir in Get-ChildItem -LiteralPath $repoRoot -Directory) {
    $name = $dir.Name
    $isAddon = (Test-Path -LiteralPath (Join-Path $dir.FullName "$name.txt")) -or
               (Test-Path -LiteralPath (Join-Path $dir.FullName "$name.addon"))
    if (-not $isAddon) { continue }

    $link = Join-Path $AddOnsPath $name
    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    $action = 'linked'
    if ($item) {
        if ($item.LinkType -notin 'Junction', 'SymbolicLink') {
            Write-Warning "$link is a real folder, left untouched - move it out of AddOns and re-run"
            $skipped++
            continue
        }
        $targets = @($item.Target) | ForEach-Object { $_.TrimEnd('\') }
        if ($targets -contains $dir.FullName.TrimEnd('\')) {
            "ok        $name"
            continue
        }
        # rmdir removes only the link; see the note above about Remove-Item
        cmd /c rmdir "$link"
        if ($LASTEXITCODE -ne 0) { throw "could not remove the old link $link" }
        $action = 'relinked'
    }
    New-Item -ItemType Junction -Path $link -Target $dir.FullName | Out-Null
    '{0,-9} {1} -> {2}' -f $action, $name, $dir.FullName
}

if ($skipped) { exit 1 }
