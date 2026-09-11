# Minimal static file server for previewing the dashboard locally (no dependencies).
# Usage: powershell -ExecutionPolicy Bypass -File refresh\Serve-Local.ps1 [-Port 8765]
param([int]$Port = 8765, [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$mime = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.md'='text/plain; charset=utf-8'; '.svg'='image/svg+xml'; '.png'='image/png'; '.ico'='image/x-icon' }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root at http://localhost:$Port/  (Ctrl+C to stop)"
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $rel = [uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
      if ($rel -eq '') { $rel = 'index.html' }
      $path = Join-Path $Root $rel
      $ctx.Response.Headers['Cache-Control'] = 'no-store'
      if ($rel -eq 'api/refresh' -and $ctx.Request.HttpMethod -eq 'POST') {
        # Manual refresh from the dashboard: run the feed scan and return its status JSON.
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Manual refresh requested"
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'refresh\Refresh-Feeds.ps1') -Root $Root 2>&1 | Out-String
        $statusJson = Get-Content (Join-Path $Root 'data\refresh_status.json') -Raw -Encoding UTF8
        $payload = "{`"ok`":true,`"status`":$statusJson,`"log`":$(($out | ConvertTo-Json))}"
        $b = [Text.Encoding]::UTF8.GetBytes($payload)
        $ctx.Response.ContentType = 'application/json; charset=utf-8'; $ctx.Response.StatusCode = 200; $ctx.Response.ContentLength64 = $b.Length
        $ctx.Response.OutputStream.Write($b, 0, $b.Length)
      } elseif ($rel -eq 'api/dismiss' -and $ctx.Request.HttpMethod -eq 'POST') {
        # Dismiss a source signal (marks the link reviewed; it will not be re-attached by later scans).
        $reader = New-Object IO.StreamReader($ctx.Request.InputStream, $ctx.Request.ContentEncoding)
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        $sigPath = Join-Path $Root 'data\signals.json'
        $sig = Get-Content $sigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $link = [string]$body.link
        $dis = @(); if ($sig.dismissed) { $dis = @($sig.dismissed) }; if ($dis -notcontains $link) { $dis += $link }
        $projs = [ordered]@{}
        foreach ($prop in $sig.projects.PSObject.Properties) { $projs[$prop.Name] = @($prop.Value | Where-Object { $_.link -ne $link }) }
        $un = @(); if ($sig.unmatched) { $un = @($sig.unmatched | Where-Object { $_.link -ne $link }) }
        $sigOut = [ordered]@{ generated = $sig.generated; dismissed = $dis; projects = $projs; unmatched = $un }
        $sigJson = $sigOut | ConvertTo-Json -Depth 6
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [IO.File]::WriteAllText($sigPath, $sigJson, $utf8)
        [IO.File]::WriteAllText((Join-Path $Root 'data\signals.js'), "window.AMI_SIGNALS = $sigJson;", $utf8)
        $b = [Text.Encoding]::UTF8.GetBytes('{"ok":true}')
        $ctx.Response.ContentType = 'application/json; charset=utf-8'; $ctx.Response.StatusCode = 200; $ctx.Response.ContentLength64 = $b.Length
        $ctx.Response.OutputStream.Write($b, 0, $b.Length)
      } elseif ((Test-Path $path -PathType Leaf) -and ([IO.Path]::GetFullPath($path)).StartsWith([IO.Path]::GetFullPath($Root))) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $ext = [IO.Path]::GetExtension($path).ToLower()
        $ctx.Response.ContentType = if ($mime[$ext]) { $mime[$ext] } else { 'application/octet-stream' }
        $ctx.Response.StatusCode = 200
        $ctx.Response.ContentLength64 = $bytes.Length
        if ($ctx.Request.HttpMethod -ne 'HEAD') { $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length) }
      } else {
        $b = [Text.Encoding]::UTF8.GetBytes('Not found')
        $ctx.Response.StatusCode = 404; $ctx.Response.ContentLength64 = $b.Length
        if ($ctx.Request.HttpMethod -ne 'HEAD') { $ctx.Response.OutputStream.Write($b, 0, $b.Length) }
      }
    } catch { Write-Host "Request error: $($_.Exception.Message)" }
    try { $ctx.Response.Close() } catch {}
  }
} finally { $listener.Stop() }
