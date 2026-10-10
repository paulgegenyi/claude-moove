# Moves in on a fake laptop that already has a packed folder on its Desktop, without saying which folder to use,
# and checks that Claude Moove asks before using it: Q quits without changing anything, R asks for a code instead,
# and Enter uses the folder. Touches only a throwaway folder in %TEMP%.
# Run from the repo: powershell -ExecutionPolicy Bypass -File tools\test-found-folder.ps1 [-Engine <path to claude-moove.ps1>]
param([string]$Engine = (Join-Path $PSScriptRoot '..\engine\claude-moove.ps1'))
$ErrorActionPreference = 'Stop'
$Engine = (Resolve-Path $Engine).Path
$root = Join-Path $env:TEMP 'claude-moove-test-found'; if (Test-Path $root) { Remove-Item $root -Recurse -Force }
$utf8 = New-Object Text.UTF8Encoding($false)
$script:failed = 0
function W($p, $s) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllText($p, $s, $utf8) }
function Prof($h) { @('-HomeDir', $h, '-AppDataDir', "$h\AppData\Roaming", '-DesktopDir', "$h\Desktop", '-DocumentsDir', "$h\Documents") }
function Check([string]$name, [scriptblock]$test) { $ok = $false; try { $ok = [bool](& $test) } catch {}; if ($ok) { "  ok    $name" } else { "  FAIL  $name"; $script:failed++ } }
$acct = '11111111-1111-1111-1111-111111111111'; $org = '22222222-2222-2222-2222-222222222222'
foreach ($side in 'old', 'new') { W "$root\$side\AppData\Roaming\Claude\config.json" "{`"lastKnownAccountUuid`":`"$acct`"}"; New-Item -ItemType Directory -Force "$root\$side\Desktop", "$root\$side\Documents" | Out-Null }
W "$root\old\AppData\Roaming\Claude\claude-code-sessions\$acct\$org\local_aaa.json" '{"sessionId":"local_aaa","cliSessionId":"c-aaa","cwd":"C:\\cmv-test-nowhere\\a","title":"A chat"}'
W "$root\old\.claude\projects\C--cmv-test-nowhere-a\c-aaa.jsonl" ('{"type":"user","sessionId":"c-aaa","cwd":"C:\\cmv-test-nowhere\\a"}' + "`n")
$chat = "$root\new\.claude\projects\C--cmv-test-nowhere-a\c-aaa.jsonl"

"Packing a fake old laptop straight onto the new laptop's Desktop..."
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode pack -Test -Yes -Json -OutDir "$root\new\Desktop" @(Prof "$root\old") 2>&1
Check 'the packed folder is on the new laptop' { @(Get-ChildItem "$root\new\Desktop" -Directory -Filter 'Claude Moove*').Count -eq 1 }

"Moving in without naming a folder..."
$out = ('Q' | & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode unpack -Test @(Prof "$root\new") 2>&1 | Out-String)
Check 'it says what it found and where, before using it' { $out -match 'I found a packed Claude Moove folder on your Desktop\.' -and $out -match 'From \S+, packed \d{4}-\d\d-\d\d' -and $out -match 'R +receive one over the internet' }
Check 'Q quits and nothing changes' { $out -match 'Nothing was changed' -and -not (Test-Path $chat) -and $out -notmatch 'Unpacking' }
$out = (@('R', '') | & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode unpack -Test @(Prof "$root\new") 2>&1 | Out-String)
Check 'R asks for a code instead, and nothing changes without one' { $out -match 'Code \(or just press Enter to stop\)' -and -not (Test-Path $chat) }
$out = (@('', '') | & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine -Mode unpack -Test @(Prof "$root\new") 2>&1 | Out-String)
Check 'Enter uses the folder it found' { (Test-Path $chat) -and $out -match "You're moved in" }

if ($script:failed) { "$($script:failed) check(s) failed."; exit 1 }
'All checks passed.'
Remove-Item $root -Recurse -Force
