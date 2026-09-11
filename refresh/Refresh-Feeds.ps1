<#
.SYNOPSIS
  Scans configured aviation news feeds and pages for items that mention tracked airports/projects,
  writes candidate items for analyst review, and updates the dashboard refresh status.

.DESCRIPTION
  This script does NOT create or modify project records automatically. It:
    1. Fetches each feed/page in refresh\feeds.json (RSS where available, homepage HTML otherwise).
    2. Matches item titles/descriptions against each project's airport, IATA code, city and name keywords.
    3. Writes matches that are not already cited in a project's sources to data\candidates.json.
    4. Records per-source status (HTTP code, items found, errors) and the scan timestamp in
       data\refresh_status.json / .js so the dashboard shows when the scan ran and what failed.
    5. Flags projects whose latest substantive update is older than the stale threshold.

  An analyst then reviews data\candidates.json, and if an item is a material development, edits
  data\projects_partN.json (add a history entry, source, and update dates) and runs
  refresh\Build-Data.ps1 to regenerate data\projects.js.

.PARAMETER StaleDays
  Days since latest_update after which a project is flagged stale (default 180).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File refresh\Refresh-Feeds.ps1
#>
param(
  [int]$StaleDays = 180,
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AviationMarketIntel/1.0 (+internal research tool)'
$utf8 = New-Object System.Text.UTF8Encoding $false

$feeds    = Get-Content (Join-Path $Root 'refresh/feeds.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$projects = Get-Content (Join-Path $Root 'data/projects.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Normalize-Url([string]$u) { if (-not $u) { return '' }; $u = $u.ToLower().Trim(); $u = $u -replace '\?.*$',''; $u = $u -replace '#.*$',''; $u = $u -replace '^https?://(www\.)?',''; return $u.TrimEnd('/') }
$existingUrls = @{}
foreach ($p in $projects) { foreach ($s in $p.sources) { $existingUrls[(Normalize-Url $s.url)] = $p.id } }

# Build keyword index per project (airport name words, IATA, city, distinctive name tokens)
$stop = @('international','airport','airports','new','terminal','terminals','expansion','the','and','of','phase','phases','programme','program','project','projects','master','plan','ppp','city','region','first','second','third','fourth','three','national','world','capacity','runway','runways','building','buildings','development','satellite','concourse','concourses','passenger','passengers','opening','operational','construction','modernisation','reconfiguration','commercial','future','including','incl','pier','piers','domestic','integration','extension','extensions','redevelopment','transformation','programme','anchor','multiple','regional','greenfield','bundle','bundles','pipeline','package','packages')
$index = @()
foreach ($p in $projects) {
  # strong keywords: city / airport-place names and IATA code (one hit is enough); weak: other name tokens (need two)
  $strong = New-Object System.Collections.Generic.HashSet[string]
  $weak = New-Object System.Collections.Generic.HashSet[string]
  # Cities with several airports: the city name alone is not distinctive, so it only counts as a weak keyword.
  $ambiguousCities = @('london','tokyo','dubai','shanghai','istanbul','paris','moscow','seoul','milan','rome','jakarta','taipei','osaka','beijing','delhi','mumbai','manila','tashkent','riyadh','jeddah','melbourne','sydney','bangkok')
  foreach ($w in ($p.airport -split '[^A-Za-z''\-]+')) { $w = $w.ToLower(); if ($w.Length -ge 5 -and $stop -notcontains $w -and $w -notmatch '^(region|multiple|programme|anchor|province|district|salman|abdulaziz)$') { if ($ambiguousCities -contains $w) { [void]$weak.Add($w) } else { [void]$strong.Add($w) } } }
  foreach ($w in ($p.city -split '[^A-Za-z''\-]+')) { $w = $w.ToLower(); if ($w.Length -ge 5 -and $stop -notcontains $w -and $w -notmatch '^(region|multiple|programme|anchor|province|district)$') { if ($ambiguousCities -contains $w) { [void]$weak.Add($w) } else { [void]$strong.Add($w) } } }
  # Royal-name airports (King Salman, King Abdulaziz, King Fahd): the second word is the distinctive one - keep it strong, drop 'king'.
  foreach ($w in @('salman','abdulaziz')) { if (($p.airport.ToLower()) -match $w) { [void]$strong.Add($w) } }
  foreach ($w in ($p.name -split '[^A-Za-z''\-]+')) { $w = $w.ToLower(); if ($w.Length -ge 5 -and $stop -notcontains $w -and -not $strong.Contains($w)) { [void]$weak.Add($w) } }
  if ($p.iata -and $p.iata -ne 'TBD' -and $p.iata.Length -eq 3) { [void]$strong.Add($p.iata.ToLower()) }
  $index += [pscustomobject]@{ id=$p.id; name=$p.name; country=$p.country; strong=@($strong); weak=@($weak) }
}

function Get-Items($feed) {
  $result = [ordered]@{ name=$feed.name; url=$feed.url; kind=$feed.kind; status=''; items=0; error='' }
  $items = @()
  try {
    $resp = Invoke-WebRequest -Uri $feed.url -UserAgent $UA -TimeoutSec 40 -UseBasicParsing
    $result.status = [string]$resp.StatusCode
    $body = $resp.Content
    if ($feed.kind -eq 'rss') {
      [xml]$xml = $body
      $nodes = $xml.SelectNodes('//item')
      if (-not $nodes -or $nodes.Count -eq 0) { $nodes = $xml.SelectNodes("//*[local-name()='entry']") }
      foreach ($n in $nodes) {
        $title = ($n.title | Out-String).Trim(); $link = ($n.link | Out-String).Trim()
        if ($link -match '^\s*$' -and $n.link.href) { $link = $n.link.href }
        $desc = (($n.description | Out-String) -replace '<[^>]+>',' ').Trim()
        $date = ($n.pubDate | Out-String).Trim(); if (-not $date) { $date = ($n.updated | Out-String).Trim() }
        $items += [pscustomobject]@{ title=$title; link=$link; description=$desc; date=$date; source=$feed.name }
      }
    } else {
      # HTML page: harvest anchor text + href as pseudo-items
      $rx = [regex]'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>'
      foreach ($m in $rx.Matches($body)) {
        $text = ($m.Groups[2].Value -replace '<[^>]+>','').Trim()
        if ($text.Length -ge 40) {
          $href = $m.Groups[1].Value; if ($href -notmatch '^https?://') { $href = ([uri]::new([uri]$feed.url, $href)).AbsoluteUri }
          $items += [pscustomobject]@{ title=$text; link=$href; description=''; date=''; source=$feed.name }
        }
      }
    }
    $result.items = $items.Count
  } catch {
    $result.status = 'ERROR'; $result.error = $_.Exception.Message
  }
  return @{ meta=[pscustomobject]$result; items=$items }
}

$scanStart = Get-Date
$feedResults = @(); $candidates = @()
foreach ($f in $feeds.feeds) {
  $r = Get-Items $f
  $feedResults += $r.meta
  foreach ($it in $r.items) {
    $text = ("$($it.title) $($it.description)").ToLower()
    if ($text -notmatch 'airport|terminal|runway|aviation|airfield|aerodrome|concourse') { continue }
    $hits = @()
    foreach ($ix in $index) {
      $s = 0; $w = 0
      foreach ($k in $ix.strong) { if ($text -match ('\b' + [regex]::Escape($k) + '\b')) { $s++ } }
      foreach ($k in $ix.weak)   { if ($text -match ('\b' + [regex]::Escape($k) + '\b')) { $w++ } }
      if ($s -ge 1 -or $w -ge 2) { $hits += $ix.id }
    }
    $already = $existingUrls.ContainsKey((Normalize-Url $it.link))
    if ($already) { continue }   # already cited by a record: not new
    if ($hits.Count -gt 0) {
      $candidates += [pscustomobject]@{ title=$it.title; link=$it.link; published=$it.date; source=$it.source; matched_projects=@($hits | Select-Object -Unique); note='Review: is this a material development (new stage, award, value, date) or a republished item?' }
    } elseif ($text -match 'new airport|new terminal|master plan|tender|contract award|expansion') {
      $candidates += [pscustomobject]@{ title=$it.title; link=$it.link; published=$it.date; source=$it.source; matched_projects=@(); note='Possible NEW project - not matched to any tracked record. Check scope and region before creating a record.' }
    }
  }
}

# Stale flags
$staleIds = @()
foreach ($p in $projects) {
  $lu = [string]$p.dates.latest_update
  # Year-only dates are treated as undated (precision too low to judge staleness); year-month uses day 1.
  if ($lu -match '^(\d{4})-(\d{2})(?:-(\d{2}))?') {
    $mo = [int]$Matches[2]
    $dy = 1; if ($Matches[3]) { $dy = [int]$Matches[3] }
    $d = New-Object DateTime ([int]$Matches[1]), $mo, $dy
    if (((Get-Date) - $d).Days -gt $StaleDays) { $staleIds += $p.id }
  }
}

# Merge candidates into persistent per-project "source signals" (unreviewed evidence attached to records).
# Verified fields of a record are never changed here; signals are shown in the dashboard for analyst confirmation.
$signalsPath = Join-Path $Root 'data/signals.json'
$signals = $null
if (Test-Path $signalsPath) { try { $signals = Get-Content $signalsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $signals = $null } }
$dismissed = @(); $projSignals = @{}; $unmatched = @()
if ($signals) {
  if ($signals.dismissed) { $dismissed = @($signals.dismissed) }
  if ($signals.projects) { foreach ($prop in $signals.projects.PSObject.Properties) { $projSignals[$prop.Name] = @($prop.Value) } }
  if ($signals.unmatched) { $unmatched = @($signals.unmatched) }
}
$knownLinks = @{}
foreach ($k in $projSignals.Keys) { foreach ($s in $projSignals[$k]) { $knownLinks[$s.link.ToLower()] = 1 } }
foreach ($u in $unmatched) { $knownLinks[$u.link.ToLower()] = 1 }
foreach ($dl in $dismissed) { $knownLinks[$dl.ToLower()] = 1 }
$newSignals = 0; $newUnmatched = 0; $touched = @()
$today = $scanStart.ToString('yyyy-MM-dd')
foreach ($c in $candidates) {
  $lk = $c.link.ToLower()
  if ($knownLinks.ContainsKey($lk)) { continue }
  $knownLinks[$lk] = 1
  $entry = [pscustomobject]@{ title=$c.title; link=$c.link; published=$c.published; source=$c.source; first_seen=$today }
  if ($c.matched_projects.Count -gt 0) {
    foreach ($projId in $c.matched_projects) {
      if (-not $projSignals.ContainsKey($projId)) { $projSignals[$projId] = @() }
      $projSignals[$projId] += $entry; $newSignals++; if ($touched -notcontains $projId) { $touched += $projId }
    }
  } else { $unmatched += $entry; $newUnmatched++ }
}
$sigOut = [ordered]@{ generated = $scanStart.ToString('yyyy-MM-ddTHH:mm:sszzz'); dismissed = $dismissed; projects = $projSignals; unmatched = $unmatched }
$sigJson = $sigOut | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($signalsPath, $sigJson, $utf8)
[IO.File]::WriteAllText((Join-Path $Root 'data/signals.js'), "window.AMI_SIGNALS = $sigJson;", $utf8)

$status = [ordered]@{
  last_scan = $scanStart.ToString('yyyy-MM-ddTHH:mm:sszzz')
  scan_mode = 'Automated feed scan (Refresh-Feeds.ps1) - candidates require analyst review'
  schedule  = if ($env:AMI_SCHEDULED -eq '1') { 'Daily (Windows Task Scheduler)' } else { 'Manual run' }
  feeds = $feedResults
  candidates_pending = $candidates.Count
  new_signals_this_run = $newSignals
  new_unmatched_this_run = $newUnmatched
  projects_with_new_signals = $touched
  stale_projects = $staleIds
  note = 'Scan time is when sources were checked. A project''s latest substantive update is the date of its most recent material development and changes only when an analyst records one.'
}
$statusJson = $status | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $Root 'data/refresh_status.json'), $statusJson, $utf8)
[IO.File]::WriteAllText((Join-Path $Root 'data/refresh_status.js'), "window.AMI_REFRESH = $statusJson;", $utf8)
$candJson = @{ generated=$scanStart.ToString('s'); candidates=$candidates } | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $Root 'data/candidates.json'), $candJson, $utf8)

# Append to scan log
$logLine = "$($scanStart.ToString('s'))`tfeeds=$($feedResults.Count)`tok=$(@($feedResults | Where-Object status -eq '200').Count)`tcandidates=$($candidates.Count)`tstale=$($staleIds.Count)"
Add-Content -Path (Join-Path $Root 'data/scan_log.tsv') -Value $logLine -Encoding UTF8

Write-Host "Scan complete: $($feedResults.Count) sources, $($candidates.Count) candidate items, $newSignals new signals on $($touched.Count) projects, $newUnmatched possible new projects, $($staleIds.Count) stale projects."
$feedResults | Format-Table name, status, items, error -AutoSize
