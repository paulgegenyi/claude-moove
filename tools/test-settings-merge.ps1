# Replays a move onto a PC that already has Claude, with fake laptops, and checks that settings are combined:
# the old laptop's settings win where both have one, and whatever only this PC has stays (plugin switches, trusted
# folders, prompt history, MCP servers, this PC's IDs and device pairing), while ordered lists like a command's arguments
# are never mixed. Also checks the "theirs" and "mine" choices, a brand-new PC, -Plan, a second move-in that changes
# nothing, a settings.json that can't be read, and a hidden, read-only .claude.json. Touches only a throwaway folder in %TEMP%.
# Run from the repo: powershell -ExecutionPolicy Bypass -File tools\test-settings-merge.ps1 [-Engine <path to claude-moove.ps1>]
param([string]$Engine = (Join-Path $PSScriptRoot '..\engine\claude-moove.ps1'))
$ErrorActionPreference = 'Stop'
$Engine = (Resolve-Path $Engine).Path
$root = Join-Path $env:TEMP 'claude-moove-test-merge'
$utf8 = New-Object Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Web.Extensions
$script:failed = 0
function W($p, $s) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllText($p, $s, $utf8) }
function J($p) { $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue; $js.DeserializeObject([IO.File]::ReadAllText($p)) }
function Check([string]$name, [scriptblock]$test) { $ok = $false; try { $ok = [bool](& $test) } catch {}; if ($ok) { "  ok    $name" } else { "  FAIL  $name"; $script:failed++ } }
function Prof($h) { @('-HomeDir', $h, '-AppDataDir', "$h\AppData\Roaming", '-DesktopDir', "$h\Desktop", '-DocumentsDir', "$h\Documents") }
function Run([string[]]$a) {
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Engine @a 2>&1
  $res = @($out | Where-Object { "$_" -like 'MOOVE-JSON*' })
  if (-not $res.Count) { 'ENGINE PRINTED NO RESULT:'; $out | Select-Object -Last 15; exit 1 }
  $r = ("$($res[-1])".Substring(11)) | ConvertFrom-Json
  if (-not $r.ok) { "ENGINE FAILED: $($r.error)"; exit 1 }
  $r
}
$acct = '11111111-1111-1111-1111-111111111111'; $org = '22222222-2222-2222-2222-222222222222'
function New-Laptop([string]$h, [string]$kind) {   # kind: old, lived (a PC with its own chats and settings), fresh (just installed)
  if (Test-Path $h) { Remove-Item $h -Recurse -Force }
  W "$h\AppData\Roaming\Claude\config.json" "{`"lastKnownAccountUuid`":`"$acct`"}"
  New-Item -ItemType Directory -Force "$h\Desktop", "$h\Documents" | Out-Null
  $sess = "$h\AppData\Roaming\Claude\claude-code-sessions\$acct\$org"
  if ($kind -eq 'old') {
    W "$sess\local_old1.json" '{"sessionId":"local_old1","cliSessionId":"c-old1","cwd":"C:\\cmv-test-nowhere\\a","title":"A chat"}'
    W "$h\.claude\projects\C--cmv-test-nowhere-a\c-old1.jsonl" ('{"type":"user","sessionId":"c-old1","cwd":"C:\\cmv-test-nowhere\\a"}' + "`n")
    W "$h\.claude\settings.json" '{ "hooks": { "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "node counter.mjs && echo done > log.txt" } ] } ] },
      "extraKnownMarketplaces": { "market-a": { "source": { "source": "github", "repo": "example/market-a" } } }, "autoUpdatesChannel": "latest", "model": "opus",
      "permissions": { "allow": [ "Bash(ls)" ] } }'
    W "$h\.claude\hooks\counter.mjs" '// counts prompts'
    W "$h\.claude.json" '{ "numStartups": 50, "theme": "dark", "userID": "old-user", "machineID": "old-machine", "migrationVersion": 4, "oauthAccount": { "emailAddress": "old@example.com" },
      "mcpServers": { "shared-tool": { "command": "python", "args": [ "server.py" ] } }, "legacyDate": "\/Date(0)\/", "emoji": "EMOJI",
      "projects": { "D:/OldApp": { "hasTrustDialogAccepted": true, "allowedTools": [ "Bash(ls)" ] }, "D:/Shared": { "hasTrustDialogAccepted": false, "lastCost": 1.5 } } }'
    $cj = "$h\.claude.json"; W $cj ([IO.File]::ReadAllText($cj).Replace('EMOJI', [char]92 + 'ud83d' + [char]92 + 'ude00'))   # an emoji, escaped the way JSON allows
    W "$h\.claude\history.jsonl" ('{"display":"old prompt","pastedContents":{},"timestamp":2000,"project":"D:/OldApp"}' + "`n")
    W "$h\.claude\plugins\known_marketplaces.json" '{ "market-a": { "source": { "source": "github", "repo": "example/market-a" } } }'
    W "$h\.claude\plugins\installed_plugins.json" '{ "version": 1, "plugins": { "tool-old@market-a": { "version": "0.9.0" } } }'
    W "$h\AppData\Roaming\Claude\claude_desktop_config.json" '{ "preferences": { "theme": "old", "remoteToolsDeviceName": "OLD-PC", "epitaxyPrefs": { "starred-local-code-sessions": [ "s1" ] } } }'
  }
  if ($kind -eq 'lived') {
    foreach ($n in 1, 2) {
      W "$sess\local_new$n.json" "{`"sessionId`":`"local_new$n`",`"cliSessionId`":`"c-new$n`",`"cwd`":`"C:\\cmv-test-nowhere\\b`",`"title`":`"Here $n`"}"
      W "$h\.claude\projects\C--cmv-test-nowhere-b\c-new$n.jsonl" ("{`"type`":`"user`",`"sessionId`":`"c-new$n`",`"cwd`":`"C:\\cmv-test-nowhere\\b`"}" + "`n")
    }
    W "$h\.claude\settings.json" '{ "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": "python guard.py" } ] } ] },
      "enabledPlugins": { "tool-one@market-b": true, "tool-two@market-b": true }, "extraKnownMarketplaces": { "market-b": { "source": { "source": "github", "repo": "example/market-b" } } },
      "model": "sonnet", "statusLine": { "type": "command", "command": "status.cmd" }, "permissions": { "allow": [ "Bash(git status)" ], "defaultMode": "default" } }'
    W "$h\.claude.json" '{ "numStartups": 3, "theme": "light", "userID": "new-user", "machineID": "new-machine", "migrationVersion": 9, "hasCompletedOnboarding": true, "oauthAccount": { "emailAddress": "new@example.com" },
      "mcpServers": { "local-tool": { "type": "stdio", "command": "local-tool" }, "shared-tool": { "command": "node", "args": [ "C:/new/server.js", "--port", "4000" ] } },
      "projects": { "D:/Work/Site": { "hasTrustDialogAccepted": true }, "d:/work/site": { "hasTrustDialogAccepted": true }, "D:/Shared": { "hasTrustDialogAccepted": true } } }'
    W "$h\.claude\history.jsonl" ((1000, 1500, 3000 | ForEach-Object { "{`"display`":`"prompt at $_`",`"pastedContents`":{},`"timestamp`":$_,`"project`":`"D:/Work/Site`"}" }) -join "`n")
    W "$h\.claude\plugins\known_marketplaces.json" '{ "market-b": { "source": { "source": "github", "repo": "example/market-b" } } }'
    W "$h\.claude\plugins\installed_plugins.json" '{ "version": 2, "plugins": { "tool-one@market-b": [ { "scope": "user", "version": "1.0.0" } ] } }'
    W "$h\AppData\Roaming\Claude\claude_desktop_config.json" '{ "preferences": { "theme": "new", "remoteToolsDeviceName": "NEW-PC", "chromeExtension": { "pairedDeviceId": "dev-1" }, "keepAwakeEnabled": true, "epitaxyPrefs": { "starred-local-code-sessions": [ "s2" ] } } }'
  }
  if ($kind -eq 'odd') {   # lived in, with a settings.json Claude Moove can't read, and a hidden, read-only .claude.json
    New-Laptop $h 'lived'
    W "$h\.claude\settings.json" '{ "model": "sonnet", "statusLine": { "type": "command", "command": "status.cmd" }, }'
    (Get-Item -LiteralPath "$h\.claude.json" -Force).Attributes = 'Hidden, ReadOnly'
  }
  if ($kind -eq 'fresh') { W "$h\.claude.json" '{ "userID": "fresh-user", "numStartups": 1 }' }
}

"Packing a fake old laptop..."
New-Laptop "$root\old" 'old'
if (Test-Path "$root\out") { Remove-Item "$root\out" -Recurse -Force }
$null = Run (@('-Mode', 'pack', '-Test', '-Yes', '-Json', '-OutDir', "$root\out") + (Prof "$root\old"))
$packed = (Get-ChildItem "$root\out" -Directory | Select-Object -First 1).FullName

"Moving in onto a PC with its own chats and settings (the suggested choices)..."
$h = "$root\lived"; New-Laptop $h 'lived'
$r = Run (@('-Mode', 'unpack', '-Test', '-Yes', '-Json', '-From', $packed) + (Prof $h))
$s = J "$h\.claude\settings.json"; $c = J "$h\.claude.json"; $d = (J "$h\AppData\Roaming\Claude\claude_desktop_config.json").preferences
Check 'settings.json was combined' { @($r.choices | Where-Object { $_.choice -eq 'combine' }).Count -eq 1 }
Check "hooks are the old laptop's whole set" { ($s.hooks.Keys -join ',') -eq 'UserPromptSubmit' }
Check 'a hook command keeps its && and >' { $s.hooks.UserPromptSubmit[0].hooks[0].command -ceq 'node counter.mjs && echo done > log.txt' -and ([IO.File]::ReadAllText("$h\.claude\settings.json") -match '&& echo done >') }
Check 'plugins switched on only here stay on' { $s.enabledPlugins['tool-one@market-b'] -eq $true -and $s.enabledPlugins['tool-two@market-b'] -eq $true }
Check "both laptops' marketplaces" { $s.extraKnownMarketplaces.ContainsKey('market-a') -and $s.extraKnownMarketplaces.ContainsKey('market-b') }
Check "the same setting: the old laptop's wins" { $s.model -eq 'opus' }
Check 'a setting only the old laptop had comes in' { $s.autoUpdatesChannel -eq 'latest' }
Check 'a setting only this PC had stays' { $s.statusLine.command -eq 'status.cmd' }
Check "folders from both laptops, including two that differ only in case" { $c.projects.ContainsKey('D:/OldApp') -and $c.projects.ContainsKey('D:/Work/Site') -and $c.projects.ContainsKey('d:/work/site') }
Check 'a folder trusted here stays trusted' { $c.projects['D:/Shared'].hasTrustDialogAccepted -eq $true -and $c.projects['D:/Shared'].lastCost -eq 1.5 }
Check "this PC's IDs and sign-in stay" { $c.userID -eq 'new-user' -and $c.machineID -eq 'new-machine' -and $c.oauthAccount.emailAddress -eq 'new@example.com' }
Check "MCP servers and onboarding only this PC had stay" { $c.mcpServers.ContainsKey('local-tool') -and $c.hasCompletedOnboarding -eq $true }
Check "the old laptop's machine state wins where both have it" { $c.theme -eq 'dark' -and $c.numStartups -eq 50 }
$hist = @([IO.File]::ReadAllLines("$h\.claude\history.jsonl") | ForEach-Object { [regex]::Match($_, '"timestamp":(\d+)').Groups[1].Value })
Check 'prompt history from both, in time order' { ($hist -join ',') -eq '1000,1500,2000,3000' }
Check "app preferences: the old laptop's win, this PC's device name and pairing stay" { $d.theme -eq 'old' -and $d.remoteToolsDeviceName -eq 'NEW-PC' -and $d.chromeExtension.pairedDeviceId -eq 'dev-1' -and $d.keepAwakeEnabled -eq $true }
Check 'starred sessions from both laptops' { (@($d.epitaxyPrefs['starred-local-code-sessions']) -join ',') -eq 's1,s2' }
Check 'permission rules from both laptops' { (@($s.permissions.allow) -join ',') -eq 'Bash(ls),Bash(git status)' -and $s.permissions.defaultMode -eq 'default' }
Check "an MCP server on both: the old laptop's command and arguments, never mixed" { $c.mcpServers['shared-tool'].command -eq 'python' -and (@($c.mcpServers['shared-tool'].args) -join ' ') -eq 'server.py' }
Check "this PC's migration state stays" { $c.migrationVersion -eq 9 }
$raw = [IO.File]::ReadAllText("$h\.claude.json")
Check 'a date-like string and an emoji are written back as they were' { $raw.Contains('"legacyDate": "/Date(0)/"') -and $raw.Contains('"emoji": "' + [char]::ConvertFromUtf32(0x1F600) + '"') }
$km = J "$h\.claude\plugins\known_marketplaces.json"; $ip = J "$h\.claude\plugins\installed_plugins.json"
Check "plugin lists combined, this PC's installed plugins kept" { $km.ContainsKey('market-a') -and $km.ContainsKey('market-b') -and $ip.plugins.ContainsKey('tool-one@market-b') }
Check "a plugin list in another format isn't mixed (the newer one stays)" { $ip.version -eq 2 -and -not $ip.plugins.ContainsKey('tool-old@market-a') }
Check "replaced files were saved first" { @(Get-ChildItem "$h\.claude-moove-safety" -Recurse -File -Filter '.claude.json').Count -eq 1 }

"Moving in again, after changing things here..."
$cfg = "$h\AppData\Roaming\Claude\claude_desktop_config.json"; [IO.File]::WriteAllText($cfg, ([IO.File]::ReadAllText($cfg) -replace '"theme": "old"', '"theme": "changed-here"'), $utf8)
$before = @{}; foreach ($f in "$h\.claude\settings.json", "$h\.claude.json", "$h\.claude\history.jsonl") { $before[$f] = (Get-FileHash $f).Hash }
$null = Run (@('-Mode', 'unpack', '-Test', '-Yes', '-Json', '-From', $packed) + (Prof $h))
Check 'a second move-in changes nothing' { @($before.Keys | Where-Object { (Get-FileHash $_).Hash -ne $before[$_] }).Count -eq 0 }
Check 'a preference changed here after the move stays' { (J $cfg).preferences.theme -eq 'changed-here' }

"Choosing the old laptop's settings.json as it is, and this PC's..."
foreach ($pick in 'theirs', 'mine') {
  $h = "$root\$pick"; New-Laptop $h 'lived'
  $want = Get-Content -Raw "$h\.claude\settings.json"
  W "$root\choices-$pick.json" ("{`"" + "$h\.claude\settings.json".Replace('\', '\\') + "`":`"$pick`"}")
  $null = Run (@('-Mode', 'unpack', '-Test', '-Yes', '-Json', '-From', $packed, '-Choices', "$root\choices-$pick.json") + (Prof $h))
  $s = J "$h\.claude\settings.json"
  if ($pick -eq 'theirs') { Check "theirs: an exact copy of the old laptop's (no plugin switches)" { -not $s.ContainsKey('enabledPlugins') -and $s.model -eq 'opus' } }
  else { Check "mine: this PC's settings.json untouched" { (Get-Content -Raw "$h\.claude\settings.json") -ceq $want } }
}

"Looking first (-Plan)..."
$h = "$root\plan"; New-Laptop $h 'lived'
$p = Run (@('-Mode', 'unpack', '-Test', '-Plan', '-From', $packed) + (Prof $h))
$sc = @($p.conflicts | Where-Object { $_.label -like 'settings.json*' })[0]
Check '-Plan suggests combine and shows the combined file' { $sc.suggested -eq 'combine' -and @($sc.choices) -contains 'combine' -and $sc.combined -and (Test-Path -LiteralPath $sc.combined) }

"Moving in onto a brand-new PC..."
$h = "$root\fresh"; New-Laptop $h 'fresh'
$null = Run (@('-Mode', 'unpack', '-Test', '-Yes', '-Json', '-From', $packed) + (Prof $h))
$c = J "$h\.claude.json"
Check "brand-new PC: the old laptop's folders, this PC's own ID, nobody's sign-in" { $c.projects.ContainsKey('D:/OldApp') -and $c.userID -eq 'fresh-user' -and -not $c.ContainsKey('machineID') -and -not $c.ContainsKey('oauthAccount') -and -not $c.ContainsKey('migrationVersion') }
Check "brand-new PC: the old laptop's settings.json" { (J "$h\.claude\settings.json").model -eq 'opus' }

"Moving in onto a PC whose settings.json can't be read, with a hidden, read-only .claude.json..."
$h = "$root\odd"; New-Laptop $h 'odd'
$want = [IO.File]::ReadAllText("$h\.claude\settings.json")
$r = Run (@('-Mode', 'unpack', '-Test', '-Yes', '-Json', '-From', $packed, '-What', 'hooks') + (Prof $h))
Check "only Hooks ticked: the unreadable settings.json is left as it is, with a warning" { [IO.File]::ReadAllText("$h\.claude\settings.json") -ceq $want -and @($r.warnings | Where-Object { $_ -like "*settings.json couldn't be read*" }).Count -eq 1 }
$null = Run (@('-Mode', 'unpack', '-Test', '-Yes', '-Json', '-From', $packed) + (Prof $h))
$ci = Get-Item -LiteralPath "$h\.claude.json" -Force
Check 'a hidden, read-only .claude.json is combined, and stays hidden and read-only' { (J "$h\.claude.json").projects.ContainsKey('D:/OldApp') -and ($ci.Attributes -band [IO.FileAttributes]::Hidden) -and ($ci.Attributes -band [IO.FileAttributes]::ReadOnly) }
Check "everything ticked: the unreadable settings.json isn't combined, and the newer one (this PC's) stays" { [IO.File]::ReadAllText("$h\.claude\settings.json") -ceq $want }

if ($script:failed) { "$($script:failed) check(s) failed."; exit 1 }
'All checks passed.'
Remove-Item $root -Recurse -Force
