# Packs a fake old laptop and unpacks it into a fake new one, both holding damaged (zero-filled) Code tab session files,
# then checks what landed: a session damaged here comes back from the old laptop, the old laptop's damaged one stays behind,
# this PC's own damaged one is left alone, and a damaged archive list is rebuilt. Touches only a throwaway folder in %TEMP%.
# Run from the repo: powershell -ExecutionPolicy Bypass -File tools\test-damaged-sessions.ps1 [-Engine <path to claude-moove.ps1>]
param([string]$Engine = (Join-Path $PSScriptRoot '..\engine\claude-moove.ps1'))
$ErrorActionPreference = 'Stop'
$Engine = (Resolve-Path $Engine).Path
$root = Join-Path $env:TEMP 'claude-moove-test-damaged'; if (Test-Path $root) { Remove-Item $root -Recurse -Force }
$utf8 = New-Object Text.UTF8Encoding($false)
$script:failed = 0
function W($p, $s) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllText($p, $s, $utf8) }
function Z($p, $n) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllBytes($p, (New-Object byte[] $n)) }
function Prof($side) { $h = "$root\$side"; @('-HomeDir', $h, '-AppDataDir', "$h\AppData\Roaming", '-DesktopDir', "$h\Desktop", '-DocumentsDir', "$h\Documents") }
function State($p) { if (-not (Test-Path -LiteralPath $p)) { return 'missing' }; try { $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json; if ($j) { 'readable' } else { 'empty' } } catch { 'damaged' } }
function Check([string]$name, [string]$got, [string]$want) { if ($got -eq $want) { "  ok    $name" } else { "  FAIL  $name (got $got, want $want)"; $script:failed++ } }
$acct = '11111111-1111-1111-1111-111111111111'; $org = '22222222-2222-2222-2222-222222222222'
foreach ($side in 'old', 'new') {
  W "$root\$side\AppData\Roaming\Claude\config.json" "{`"lastKnownAccountUuid`":`"$acct`"}"
  New-Item -ItemType Directory -Force "$root\$side\Desktop", "$root\$side\Documents" | Out-Null
}
$so = "$root\old\AppData\Roaming\Claude\claude-code-sessions\$acct\$org"
$sn = "$root\new\AppData\Roaming\Claude\claude-code-sessions\$acct\$org"
# old laptop: a good session, a damaged one, an archive list
W "$so\local_aaa.json" '{"sessionId":"local_aaa","cliSessionId":"c-aaa","cwd":"C:\\cmv-test-nowhere\\old","title":"Good chat"}'
Z "$so\local_zzz.json" 512
W "$so\archived-sessions.idx" '{"v":1,"archived":["local_aaa"]}'
W "$root\old\.claude\projects\C--cmv-test-nowhere-old\c-aaa.jsonl" ('{"type":"user","sessionId":"c-aaa","cwd":"C:\\cmv-test-nowhere\\old"}' + "`n")
# new laptop: the same session damaged, a damaged one of its own, a damaged archive list
Z "$sn\local_aaa.json" 300
Z "$sn\local_yyy.json" 9815
Z "$sn\archived-sessions.idx" 40

$packOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode pack -Test -Yes -Json -OutDir "$root\out" @(Prof 'old') 2>&1
$packed = Get-ChildItem "$root\out" -Directory | Select-Object -First 1
if (-not $packed) { 'PACK FAILED'; $packOut; exit 1 }
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode unpack -Test -Yes -Json -From $packed.FullName @(Prof 'new') 2>&1
if (-not @($out | Where-Object { "$_" -like 'MOOVE-JSON:{"ok":true*' }).Count) { 'UNPACK FAILED:'; $out | Select-Object -Last 15; exit 1 }
Check 'a session damaged here but good on the old laptop comes back' (State "$sn\local_aaa.json") 'readable'
Check "the old laptop's damaged session stays behind" (State "$sn\local_zzz.json") 'missing'
Check "this PC's own damaged session is left alone" (State "$sn\local_yyy.json") 'damaged'
$idx = State "$sn\archived-sessions.idx"; $ids = try { ([IO.File]::ReadAllText("$sn\archived-sessions.idx") | ConvertFrom-Json).archived -join ',' } catch { '' }
Check 'a damaged archive list is rebuilt with the archived session' "$idx $ids" 'readable local_aaa'
if ($script:failed) { "$($script:failed) check(s) failed."; exit 1 }
'All checks passed.'
Remove-Item $root -Recurse -Force
