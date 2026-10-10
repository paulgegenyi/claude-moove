# Checks what the sending window says at each stage, from croc's own output: "Getting the folder ready" while croc
# fingerprints the files (nothing has left the laptop), "Waiting for the new laptop to type the code", and "Sending to
# the new laptop" with a percentage and speed only once croc reports the connection. Then, when croc is installed, sends
# a fake laptop's folder to another fake laptop through a private relay started on this PC (nothing goes over the
# internet) and checks it arrived. Touches only a throwaway folder in %TEMP%.
# Run from the repo: powershell -ExecutionPolicy Bypass -File tools\test-sending.ps1 [-Engine <path to claude-moove.ps1>]
param([string]$Engine = (Join-Path $PSScriptRoot '..\engine\claude-moove.ps1'))
$ErrorActionPreference = 'Stop'
$Engine = (Resolve-Path $Engine).Path
$script:failed = 0
function Check([string]$name, [scriptblock]$test) { $ok = $false; try { $ok = [bool](& $test) } catch {}; if ($ok) { "  ok    $name" } else { "  FAIL  $name"; $script:failed++ } }

"The status line, from croc's output..."
$lines = [IO.File]::ReadAllLines($Engine)
$a = [array]::FindIndex($lines, [Predicate[string]] { param($l) $l -like 'function Get-SendStatus*' })
$b = [array]::FindIndex($lines, $a, [Predicate[string]] { param($l) $l -eq '}' })
Invoke-Expression ($lines[$a..$b] -join "`n")
$hashing = "On the other computer, run:`n  croc one-two-three`nOr open:`n  https://getcroc.com/?code=one-two-three`nSending 0 files (1.4 kB)`n" +
  "Hashing C:\Users\...   0% |                    | ( 0 B/2.0 GB) [0s:0s]`rHashing C:\Users\...  54% |##########          | (1.1/2.0 GB, 2.7 GB/s) [0s:0s]"
$waiting = $hashing + "`rHashing C:\Users\...  96% |################### | (2.0/2.0 GB, 2.7 GB/s) [0s:0s]`nSending 4 files (1.9 GB)`nSending 8 files and 2 folders (1.9 GB)`n"
$connected = $waiting + "Sending (192.168.1.20->192.168.1.31)`n"
$sending = $connected + "claude-data.zip   0% |                    | ( 0 B/1.9 GB) [0s:0s]`rclaude-data.zip  44% |########            | (850/1900 MB, 12.4 MB/s) [1m8s:1m25s]"
Check 'nothing printed yet: waiting' { (Get-SendStatus '') -eq 'Waiting for the new laptop to type the code...' }
Check 'fingerprinting: getting the folder ready, with its percentage' { (Get-SendStatus $hashing) -eq 'Getting the folder ready...  54%' }
Check 'fingerprinted, nobody connected: waiting, not "sending 96%"' { (Get-SendStatus $waiting) -eq 'Waiting for the new laptop to type the code...' }
Check 'connected: sending' { (Get-SendStatus $connected) -eq 'Sending to the new laptop...' }
Check 'sending: the percentage and speed of the transfer itself' { (Get-SendStatus $sending) -eq 'Sending to the new laptop...  44%, 12.4 MB/s' }

$croc = (Get-Command croc -ErrorAction SilentlyContinue).Source
if (-not $croc) { $croc = @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter croc.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
if (-not $croc) { 'croc is not installed, so the real send was skipped.' }
else {
  "Sending a fake laptop's folder to another through a private relay on this PC..."
  $root = Join-Path $env:TEMP 'claude-moove-test-sending'; if (Test-Path $root) { Remove-Item $root -Recurse -Force }
  $utf8 = New-Object Text.UTF8Encoding($false)
  function W($p, $s) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllText($p, $s, $utf8) }
  function Prof($h) { @('-HomeDir', $h, '-AppDataDir', "$h\AppData\Roaming", '-DesktopDir', "$h\Desktop", '-DocumentsDir', "$h\Documents") }
  $acct = '11111111-1111-1111-1111-111111111111'; $org = '22222222-2222-2222-2222-222222222222'
  foreach ($side in 'old', 'new') { W "$root\$side\AppData\Roaming\Claude\config.json" "{`"lastKnownAccountUuid`":`"$acct`"}"; New-Item -ItemType Directory -Force "$root\$side\Desktop", "$root\$side\Documents" | Out-Null }
  W "$root\old\AppData\Roaming\Claude\claude-code-sessions\$acct\$org\local_aaa.json" '{"sessionId":"local_aaa","cliSessionId":"c-aaa","cwd":"C:\\cmv-test-nowhere\\a","title":"A chat"}'
  W "$root\old\.claude\projects\C--cmv-test-nowhere-a\c-aaa.jsonl" ('{"type":"user","sessionId":"c-aaa","cwd":"C:\\cmv-test-nowhere\\a"}' + "`n")
  $env:CROC_RELAY = '127.0.0.1:9109'; $env:CROC_PASS = 'pass123'
  $relay = Start-Process $croc -ArgumentList 'relay', '--host', '127.0.0.1', '--ports', '9109,9110,9111,9112,9113' -WindowStyle Hidden -PassThru
  try {
    Start-Sleep -Seconds 2
    $pack = Start-Process powershell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Engine`"", '-Mode', 'pack', '-Test', '-Yes', '-Json', '-Transfer', 'send', '-OutDir', "`"$root\out`"") +
      @(Prof "$root\old" | ForEach-Object { if ($_ -like '-*') { $_ } else { "`"$_`"" } })) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$root\pack.out" -RedirectStandardError "$root\pack.err"
    $code = ''; for ($i = 0; $i -lt 120 -and -not $code -and -not $pack.HasExited; $i++) { Start-Sleep -Milliseconds 500; $m = [regex]::Match("$(Get-Content -Raw "$root\pack.out" -ErrorAction SilentlyContinue)", 'MOOVE-CODE:(\S+)'); if ($m.Success) { $code = $m.Groups[1].Value } }
    Check 'the sending laptop shows a code' { [bool]$code }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode unpack -Test -Yes -Json -ReceiveCode $code @(Prof "$root\new") 2>&1
    $null = $pack.WaitForExit(60000)
    Check 'the new laptop received it and moved in' { @($out | Where-Object { "$_" -like 'MOOVE-JSON:{"ok":true*' }).Count -eq 1 -and (Test-Path "$root\new\.claude\projects\C--cmv-test-nowhere-a\c-aaa.jsonl") }
    Check 'the sending laptop says it was sent' { (Get-Content -Raw "$root\pack.out") -match 'MOOVE-JSON:\{"ok":true.*"sent":true' }
  } finally {
    if (-not $relay.HasExited) { Stop-Process -Id $relay.Id -Force }
    $env:CROC_RELAY = $null; $env:CROC_PASS = $null
  }
  if (-not $script:failed) { Remove-Item $root -Recurse -Force }
}
if ($script:failed) { "$($script:failed) check(s) failed."; exit 1 }
'All checks passed.'
