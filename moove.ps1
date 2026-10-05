# Claude Moove launcher. Paste this one line into PowerShell:
#
#   irm https://raw.githubusercontent.com/paulgegenyi/claude-moove/main/moove.ps1 | iex
#
# It downloads the latest Claude Moove into %LOCALAPPDATA%\Claude Moove and opens its menu (pack up this laptop,
# or move in on this one). Nothing is installed and no browser download is involved, so Windows shows no warning.
# Run from a cloned copy (powershell -ExecutionPolicy Bypass -File moove.ps1), it uses that copy instead.
& {
  $ErrorActionPreference = 'Stop'
  $here = if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'engine\claude-moove.ps1'))) { $PSScriptRoot } else { $null }
  if (-not $here) {
    $here = Join-Path $env:LOCALAPPDATA 'Claude Moove'
    Write-Host ''
    Write-Host '  Getting the latest Claude Moove...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $zip = Join-Path $env:TEMP 'claude-moove-latest.zip'
    $tmp = Join-Path $env:TEMP ('claude-moove-' + [guid]::NewGuid().ToString('N'))
    Invoke-WebRequest 'https://github.com/paulgegenyi/claude-moove/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    if (Test-Path -LiteralPath $here) { Remove-Item -LiteralPath $here -Recurse -Force }
    Move-Item -LiteralPath (Join-Path $tmp 'claude-moove-main') $here
    Remove-Item -LiteralPath $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  $engineArgs = if ($args.Count) { $args } else { @('-Mode', 'menu') }
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'engine\claude-moove.ps1') @engineArgs
} @args
