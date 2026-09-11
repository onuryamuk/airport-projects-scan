<#
.SYNOPSIS  Rebuilds data\projects.json / projects.js / sources.js from the editable part files.
.EXAMPLE   powershell -ExecutionPolicy Bypass -File refresh\Build-Data.ps1
#>
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$all = @()
foreach ($f in (Get-ChildItem (Join-Path $Root 'data') -Filter 'projects_part*.json' | Sort-Object Name)) {
  $part = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  $all += $part
  Write-Host "$($f.Name): $($part.Count) records"
}
# Integrity checks
$ids = $all | ForEach-Object { $_.id }
$dups = $ids | Group-Object | Where-Object Count -gt 1
if ($dups) { throw "Duplicate ids: $($dups.Name -join ', ')" }
$nosrc = $all | Where-Object { -not $_.sources -or $_.sources.Count -eq 0 }
if ($nosrc) { throw "Records without sources: $($nosrc.id -join ', ')" }
$today = (Get-Date).ToString('yyyy-MM-dd')
foreach ($r in $all) {
  if (-not $r.PSObject.Properties['first_identified']) { $r | Add-Member -NotePropertyName first_identified -NotePropertyValue $today }
  if (-not $r.PSObject.Properties['last_verified'])    { $r | Add-Member -NotePropertyName last_verified    -NotePropertyValue $today }
  $s = $r.score; $t = $s.fit + $s.timing + $s.access + $s.scale + $s.evidence
  if ($t -gt 20) { throw "Score over 20 for $($r.id)" }
}
$json = $all | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText((Join-Path $Root 'data/projects.json'), $json, $utf8)
[IO.File]::WriteAllText((Join-Path $Root 'data/projects.js'), "window.AMI_PROJECTS = $json;", $utf8)
$src = Get-Content (Join-Path $Root 'data/sources.json') -Raw -Encoding UTF8
[IO.File]::WriteAllText((Join-Path $Root 'data/sources.js'), "window.AMI_SOURCES = $src;", $utf8)
Write-Host "Built $($all.Count) records -> data\projects.js"
