# CLAUDE MOOVE engine: carries everything Claude from one Windows laptop to another.
# Started by the two buttons one folder up: "pack" on the laptop you're leaving, "unpack" on the one you're moving to.
# What it moves and how it merges: README.md next to this file. This file is plain ASCII on purpose;
# Clawd's block characters are built from character codes so any Windows can read it.
param(
  [Parameter(Mandatory = $true)][ValidateSet('pack', 'unpack', 'preview')][string]$Mode,
  # This laptop's folders. The defaults are the real ones; tests point them somewhere else.
  [string]$HomeDir = $env:USERPROFILE,
  [string]$AppDataDir = $env:APPDATA,
  [string]$DesktopDir = [Environment]::GetFolderPath('Desktop'),
  [string]$DocumentsDir = [Environment]::GetFolderPath('MyDocuments'),
  [string]$OutDir = '',   # where pack puts the transfer folder (default: the Desktop)
  [switch]$Test           # unattended test run: never closes Claude, opens pages, installs or downloads anything
)
$ErrorActionPreference = 'Stop'
$engine    = $PSScriptRoot
$toolRoot  = Split-Path $engine
$stamp     = Get-Date -Format 'yyyy-MM-dd HHmm'
$claudeDir = Join-Path $AppDataDir 'Claude'
$marker    = Join-Path $claudeDir 'claude-moove-synced.json'
$utf8      = New-Object System.Text.UTF8Encoding($false)
$warnings  = New-Object System.Collections.Generic.List[string]
$script:work = $null

# ---------------------------------------------------------------- screen and Clawd
try { [Console]::OutputEncoding = $utf8 } catch {}
$vt = $false
try {
  $con = Add-Type -PassThru -Name Con -Namespace ClaudeMoove -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out int m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, int m);
'@
  $conOut = $con::GetStdHandle(-11); $conMode = 0
  if ($con::GetConsoleMode($conOut, [ref]$conMode)) { $vt = $con::SetConsoleMode($conOut, $conMode -bor 4) }
} catch {}
if ($Mode -eq 'preview') { $vt = $true }
$E = [char]27
$ink = @{ clawd = '38;2;215;119;87'; title = '1;38;2;245;240;232'; dim = '38;2;140;140;140'; ok = '38;2;125;195;125'; warn = '38;2;235;185;90'; bad = '38;2;240;105;105'; pink = '1;38;2;242;140;184'; plain = '0' }
$fallbackInk = @{ clawd = 'DarkYellow'; title = 'White'; dim = 'DarkGray'; ok = 'Green'; warn = 'Yellow'; bad = 'Red'; pink = 'Magenta'; plain = 'Gray' }
# Colours of the flower field, one letter per paint (letters must differ ignoring case).
$paint = @{ o = '215;119;87'; d = '58;118;62'; g = '104;172;88'; p = '242;140;184'; w = '246;244;236'; v = '180;144;234'; r = '238;100;100'; b = '122;174;242'; y = '248;208;86'; k = '92;72;96' }

function Put([string]$text, [string]$kind = 'plain', [switch]$n) {
  if ($vt) { Write-Host "$E[$($ink[$kind])m$text$E[0m" -NoNewline:$n } else { Write-Host $text -ForegroundColor $fallbackInk[$kind] -NoNewline:$n }
}
function Gap { Write-Host '' }
function Clear-Screen { if ($Mode -eq 'preview') { return }; if ($Test) { Write-Host ''; Write-Host ('=' * 40); return }; try { Clear-Host } catch {} }

# Clawd as pixels: '#' is body. Legs have two frames so he can walk while you wait.
$clawdBody = '...############...', '...##.######.##...', '.################.', '...############...'
$clawdLegs = '....#.#....#.#....', '...#.#......#.#...'
# Quarter-block characters indexed by which quarters are filled: top-left 1, top-right 2, bottom-left 4, bottom-right 8.
$quad = 0x20, 0x2598, 0x259D, 0x2580, 0x2596, 0x258C, 0x259E, 0x259B, 0x2597, 0x259A, 0x2590, 0x259C, 0x2584, 0x2599, 0x259F, 0x2588

function Get-Clawd([int]$frame = 0) {   # small Clawd, the same one Claude Code shows when it starts
  $rows = @($clawdBody) + $clawdLegs[$frame] + ('.' * 18)
  for ($y = 0; $y -lt 6; $y += 2) {
    -join (0..8 | ForEach-Object {
        $x = $_ * 2; $i = 0
        if ($rows[$y][$x] -eq '#') { $i += 1 }; if ($rows[$y][$x + 1] -eq '#') { $i += 2 }
        if ($rows[$y + 1][$x] -eq '#') { $i += 4 }; if ($rows[$y + 1][$x + 1] -eq '#') { $i += 8 }
        [char]$quad[$i] })
  }
}
function Get-BigClawd {   # full Clawd: every pixel becomes a 4x2 block
  $block = ([string][char]0x2588) * 4
  foreach ($row in @($clawdBody) + $clawdLegs[0]) {
    $line = -join ($row.ToCharArray() | ForEach-Object { if ($_ -eq '#') { $block } else { '    ' } })
    $line; $line
  }
}
$font = @{
  'C' = '.###', '#...', '#...', '#...', '.###';  'L' = '#...', '#...', '#...', '#...', '####'
  'A' = '.##.', '#..#', '####', '#..#', '#..#';  'U' = '#..#', '#..#', '#..#', '#..#', '.##.'
  'D' = '###.', '#..#', '#..#', '#..#', '###.';  'E' = '####', '#...', '###.', '#...', '####'
  'M' = '#...#', '##.##', '#.#.#', '#...#', '#...#';  'O' = '.##.', '#..#', '#..#', '#..#', '.##.'
  'V' = '#...#', '#...#', '#...#', '.#.#.', '..#..';  '!' = '#', '#', '#', '.', '#';  ' ' = '..', '..', '..', '..', '..'
}
function Get-BigText([string]$text) {   # block letters, two pixel rows per text line
  $rows = @('', '', '', '', '', '')
  foreach ($ch in $text.ToCharArray()) { $g = $font[[string]$ch]; for ($r = 0; $r -lt 5; $r++) { $rows[$r] += $g[$r] + '.' } }
  $rows[5] = '.' * $rows[0].Length
  for ($y = 0; $y -lt 6; $y += 2) {
    $top = $rows[$y]; $bottom = $rows[$y + 1]
    -join (0..($top.Length - 1) | ForEach-Object {
        $t = $top[$_] -eq '#'; $b = $bottom[$_] -eq '#'
        if ($t -and $b) { [char]0x2588 } elseif ($t) { [char]0x2580 } elseif ($b) { [char]0x2584 } else { ' ' } })
  }
}

# ---------------------------------------------------------------- the flower field
# Pixel pictures: each text cell shows two stacked pixels (upper half block, with foreground and background colours).
function Stamp($canvas, [string[]]$sprite, [int]$x0, [int]$y0) {   # '.' in a sprite is see-through
  for ($y = 0; $y -lt $sprite.Count; $y++) {
    for ($x = 0; $x -lt $sprite[$y].Length; $x++) {
      $ch = $sprite[$y][$x]; $cy = $y0 + $y; $cx = $x0 + $x
      if ($ch -ne '.' -and $cy -ge 0 -and $cy -lt $canvas.Count -and $cx -ge 0 -and $cx -lt $canvas[0].Length) { $canvas[$cy][$cx] = $ch }
    }
  }
}
function Write-Canvas($canvas, [int]$indent) {
  for ($y = 0; $y -lt $canvas.Count; $y += 2) {
    $sb = New-Object Text.StringBuilder; [void]$sb.Append(' ' * $indent)
    for ($x = 0; $x -lt $canvas[0].Length; $x++) {
      $t = [string]$canvas[$y][$x]; $b = if ($y + 1 -lt $canvas.Count) { [string]$canvas[$y + 1][$x] } else { '.' }
      if ($t -eq '.' -and $b -eq '.') { [void]$sb.Append(' ') }
      elseif ($b -eq '.') { [void]$sb.Append("$E[38;2;$($paint[$t])m" + [char]0x2580 + "$E[0m") }
      elseif ($t -eq '.') { [void]$sb.Append("$E[38;2;$($paint[$b])m" + [char]0x2584 + "$E[0m") }
      elseif ($t -eq $b) { [void]$sb.Append("$E[38;2;$($paint[$t])m" + [char]0x2588 + "$E[0m") }
      else { [void]$sb.Append("$E[38;2;$($paint[$t]);48;2;$($paint[$b])m" + [char]0x2580 + "$E[0m") }
    }
    Write-Host $sb.ToString()
  }
}
function Get-ClawdSprite([int]$scale, [switch]$Happy) {
  $rows = @(foreach ($row in @($clawdBody) + $clawdLegs[0]) {
      $line = -join ($row.ToCharArray() | ForEach-Object { $(if ($_ -eq '#') { 'o' } else { '.' }) * $scale })
      for ($i = 0; $i -lt $scale; $i++) { $line }
    })
  if ($Happy) {   # happy ^ ^ eyes for the finish
    foreach ($ex in 5, 12) {
      $x = $ex * $scale; $y = $scale
      for ($dy = 0; $dy -lt $scale; $dy++) {
        $a = $rows[$y + $dy].ToCharArray()
        for ($dx = 0; $dx -lt $scale; $dx++) { $a[$x + $dx] = 'o' }
        if ($dy -eq 0) { $a[$x + 1] = '.' }
        if ($dy -eq 1) { $a[$x] = '.'; $a[$x + 2] = '.' }
        $rows[$y + $dy] = -join $a
      }
    }
  }
  $rows
}
function Get-Flower([string]$p, [int]$stem, [string]$kind = 'daisy') {
  $mid = if ($p -eq 'y') { 'o' } else { 'y' }
  $head = if ($kind -eq 'tulip') { "$p.$p", "$p$p$p", ".$p." } else { ".$p.", "$p$mid$p", ".$p." }
  $lines = @($head) + @(for ($i = 0; $i -lt $stem; $i++) { '.g.' })
  if ($stem -ge 3) { $lines[4] = 'gg.' }   # a leaf
  $lines
}
function Get-Scene([switch]$Bloom) {   # Clawd standing in a flower field; with -Bloom everything is in full flower
  $W = 84; $H = 24
  $c = @(1..$H | ForEach-Object { , ('.' * $W).ToCharArray() })
  Stamp $c (Get-ClawdSprite 3 -Happy:$Bloom) 15 4
  for ($x = 0; $x -lt $W; $x++) {   # grass: blades, then lawn with light specks
    if ((($x * 7) % 5) -lt 2) { $c[19][$x] = 'g' }
    $c[20][$x] = if ($x % 4 -eq 1) { 'g' } else { 'd' }
    for ($y = 21; $y -lt $H; $y++) { $c[$y][$x] = if ((($x + $y * 3) % 11) -eq 0) { 'g' } else { 'd' } }
  }
  $tiny = 'p', 'y', 'w', 'v', 'r', 'b'
  for ($x = 3; $x -lt $W; $x += 7) { $c[22 + ($x % 2)][$x] = $tiny[[int][Math]::Floor($x / 7) % $tiny.Count] }
  Stamp $c ('.yyy.', 'yyyyy', 'yyyyy', 'yyyyy', '.yyy.') 77 0           # sun
  Stamp $c ('p.p', '.k.', 'p.p') 4 2                                       # butterflies
  Stamp $c ('v.v', '.k.', 'v.v') 66 3
  Stamp $c (Get-Flower 'p' 6) 1 10; Stamp $c (Get-Flower 'y' 4 'tulip') 6 13; Stamp $c (Get-Flower 'v' 7) 10 9
  Stamp $c (Get-Flower 'w' 6) 69 10; Stamp $c (Get-Flower 'r' 4 'tulip') 74 13; Stamp $c (Get-Flower 'b' 7) 79 9
  Stamp $c (Get-Flower 'p' 1) 20 18; Stamp $c (Get-Flower 'w' 1 'tulip') 41 18; Stamp $c (Get-Flower 'v' 1) 61 18
  if ($Bloom) {
    Stamp $c ('b.b', '.k.', 'b.b') 30 1; Stamp $c ('y.y', '.k.', 'y.y') 52 0
    foreach ($s in @(12, 4), @(25, 2), @(44, 3), @(60, 1), @(72, 6)) { $c[$s[1]][$s[0]] = 'y' }   # sparkles
    Stamp $c (Get-Flower 'r' 2 'tulip') 15 17; Stamp $c (Get-Flower 'y' 1) 31 18; Stamp $c (Get-Flower 'p' 2) 51 17; Stamp $c (Get-Flower 'b' 1 'tulip') 65 18
  }
  , $c
}
function Get-Title {   # CLAUDE MOOVE! in block letters, each letter a different flower colour
  $colors = 'o', 'p', 'y', 'v', 'b', 'w', 'r'; $i = 0
  $rows = @('', '', '', '', '', '')
  foreach ($ch in 'CLAUDE MOOVE!'.ToCharArray()) {
    $g = $font[[string]$ch]; $col = '.'
    if ($ch -ne ' ') { $col = $colors[$i % $colors.Count]; $i++ }
    for ($r = 0; $r -lt 5; $r++) { $rows[$r] += ($g[$r] -replace '#', $col) + '.' }
  }
  $rows[5] = '.' * $rows[0].Length
  , @($rows | ForEach-Object { , $_.ToCharArray() })
}
function Get-FlowerBar([int]$done, [int]$total) {   # progress as a flower bed: done steps bloom, the current one buds
  if (-not $vt) { return ('*' * ($done * 2)) + ('.' * (($total - $done) * 2)) }
  $petals = 'p', 'y', 'v', 'w', 'r', 'b'; $bar = ''
  for ($i = 0; $i -lt $total * 2; $i++) {
    $step = [int][Math]::Floor($i / 2); $col = $paint[$petals[$i % $petals.Count]]
    if ($step -lt $done) { $bar += "$E[38;2;$col;48;2;$($paint.g)m" + [char]0x2580 + "$E[0m " }
    elseif ($step -eq $done) { $bar += "$E[38;2;$col" + 'm' + [char]0x2584 + "$E[0m " }
    else { $bar += "$E[38;2;$($paint.g)m" + [char]0x2584 + "$E[0m " }
  }
  $bar
}

function Show-Big([string[]]$lines, [switch]$Bloom) {
  Clear-Screen
  if ($vt) {
    Write-Canvas (Get-Scene -Bloom:$Bloom) 2
    Write-Canvas (Get-Title) 13
    Put ((' ' * 70) + 'yaay!!') pink
  } else {
    foreach ($l in Get-BigClawd) { Put ('  ' + $l) clawd }
    foreach ($l in Get-BigText 'CLAUDE MOOVE!') { Put ('       ' + $l) clawd }
    Put ((' ' * 63) + 'yaay!!') pink
  }
  foreach ($l in $lines) { if ($l.StartsWith('[x]')) { Put "  $l" ok } elseif ($l.StartsWith('[!]')) { Put "  $l" warn } else { Put "  $l" plain } }
}
function Show-Header([int]$frame = 0) {
  Clear-Screen
  $c = Get-Clawd $frame
  $total = $script:steps.Count; $done = $script:step - 1
  Put (' ' + $c[0] + '  ') clawd -n; Put 'CLAUDE MOOVE' title -n; Put ('  ' + [char]0xB7 + '  ' + $script:what) dim
  Put (' ' + $c[1] + '  ') clawd -n; Put "Step $($script:step) of $total  " plain -n; Put $script:steps[$script:step - 1] title
  Put (' ' + $c[2] + '  ') clawd -n; Write-Host (Get-FlowerBar $done $total)
  Gap
  for ($i = 1; $i -le $total; $i++) {
    if ($i -lt $script:step) { Put ('   [x] ' + $script:steps[$i - 1]) ok }
    elseif ($i -eq $script:step) { Put ('   [>] ' + $script:steps[$i - 1]) title }
    else { Put ('   [ ] ' + $script:steps[$i - 1]) dim }
  }
  Gap
}
function Set-Step([int]$n) { $script:step = $n; Show-Header }
function Wait-Enter([string]$text) { Gap; Put "   $text" title; if (-not $Test) { [void][Console]::ReadLine() } }
function Read-Answer([string]$text) { Gap; Put "   $text" title; if ($Test) { return '' }; ([Console]::ReadLine() + '').Trim().ToUpper() }
function End-Wait { Gap; Put '   Press any key to close this window.' dim; if (-not $Test) { try { [void][Console]::ReadKey($true) } catch { [void](Read-Host) } } }

# Runs a tool in the background while Clawd walks and a timer ticks, so a long step never looks frozen.
function Start-Tool([string]$exe, [string]$argLine) {
  $p = Start-Process -FilePath $exe -ArgumentList $argLine -NoNewWindow -PassThru `
    -RedirectStandardOutput (Join-Path $env:TEMP 'claude-moove-tool.log') -RedirectStandardError (Join-Path $env:TEMP 'claude-moove-tool.err')
  $null = $p.Handle   # keeps the exit code readable after the process ends
  $p
}
function Wait-Walking($proc, [scriptblock]$status) {
  $frame = 0; $t0 = Get-Date
  while (-not $proc.HasExited) {
    $canDraw = $false; try { $canDraw = $vt -and -not $Test -and ([Console]::CursorTop -lt ([Console]::WindowHeight - 1)) } catch {}
    if ($canDraw) {
      $c = Get-Clawd $frame
      Write-Host -NoNewline ("$E" + '7' + "$E[1;2H$E[$($ink.clawd)m" + $c[0] + "$E[2;2H" + $c[1] + "$E[3;2H" + $c[2] + "$E[0m$E" + '8')
    }
    $el = (Get-Date) - $t0
    $text = if ($status) { & $status } else { 'Working...' }
    if (-not $Test) { Write-Host -NoNewline ("`r   $text  " + ('{0}:{1:00}' -f [int][Math]::Floor($el.TotalMinutes), $el.Seconds) + '      ') }
    Start-Sleep -Milliseconds 350; $frame = 1 - $frame
  }
  $proc.WaitForExit()
  if (-not $Test) { Write-Host ("`r" + (' ' * 70) + "`r") -NoNewline }
}
function Q([string]$s) { '"' + $s + '"' }
function Plural([int]$n, [string]$word) { if ($n -eq 1) { "1 $word" } else { "$n ${word}s" } }
function Copy-Tree([string]$from, [string]$to, [string]$label, [string[]]$extra = @(), [switch]$Merge) {
  if (-not (Test-Path -LiteralPath $from)) { return }
  $a = @((Q $from), (Q $to), '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') + $extra
  if ($Merge) { $a += '/XO' }   # never overwrite a newer file on this laptop
  $p = Start-Tool robocopy ($a -join ' ')
  Wait-Walking $p { $label }
  if ($p.ExitCode -ge 8) { $warnings.Add("Some files in $from couldn't be copied (robocopy code $($p.ExitCode)).") }
}
function Copy-One([string]$from, [string]$toDir) {
  if (Test-Path -LiteralPath $from) { New-Item -ItemType Directory -Force $toDir | Out-Null; Copy-Item -LiteralPath $from -Destination $toDir -Force }
}
function Remove-Tree([string]$p) {   # robocopy can empty folders whose paths are too long for Remove-Item
  if (-not $p -or -not (Test-Path -LiteralPath $p)) { return }
  $empty = Join-Path $env:TEMP 'claude-moove-empty'; New-Item -ItemType Directory -Force $empty | Out-Null
  & robocopy $empty $p /MIR /R:0 /W:0 /NFL /NDL /NJH /NJS /NP | Out-Null
  Remove-Item -LiteralPath $p, $empty -Recurse -Force -ErrorAction SilentlyContinue
}
function New-WorkDir {   # short path, so deep chat folders stay under Windows' 260-character limit
  $id = Get-Random -Maximum 999999
  foreach ($base in "$env:SystemDrive\", $env:LOCALAPPDATA, $env:TEMP) {
    try { $p = Join-Path $base "CMv-$id"; New-Item -ItemType Directory -Path $p -ErrorAction Stop | Out-Null; return $p } catch {}
  }
  throw "Couldn't make a temporary folder."
}
function Read-Json([string]$path) { [IO.File]::ReadAllText($path) | ConvertFrom-Json }
function Invoke-Git([string]$dir) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $o = & git -C $dir @args 2>$null; if ($LASTEXITCODE -eq 0) { $o } } finally { $ErrorActionPreference = $old }
}
function Update-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
function Close-Claude {   # returns $true only if Claude is still open (test runs)
  if (-not (Get-Process -Name claude -ErrorAction SilentlyContinue)) { Put '   [x] Claude is closed.' ok; return $false }
  Put '   Claude is open. It has to close so nothing changes while I work.' plain
  Put '   Your chats are saved, nothing gets lost.' dim
  if ($Test) { Put '   (test run: leaving Claude open)' dim; return $true }
  Wait-Enter "Press Enter and I'll close Claude for you."
  Get-Process -Name claude -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  for ($i = 0; $i -lt 30 -and (Get-Process -Name claude -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
  if (Get-Process -Name claude -ErrorAction SilentlyContinue) { throw "Claude wouldn't close. Right-click its icon near the clock, choose Quit, then run this again." }
  Put '   [x] Claude is closed.' ok
  return $false
}

# ---------------------------------------------------------------- PACK (laptop you're leaving)
function Invoke-Pack {
  $script:what = 'packing up this laptop'
  $script:steps = 'Close Claude', 'Check your projects', 'Copy your Claude stuff', 'Zip it up', 'Make your transfer folder'
  Show-Big @(
    'This packs ALL your Claude stuff into one folder you can carry to your next laptop:',
    'every chat and session, your global CLAUDE.md, settings, hooks, skills, plugins and memory.',
    'It takes about 5 minutes.')
  Wait-Enter 'Press Enter to start.'

  Set-Step 1
  $claudeOpen = Close-Claude

  Set-Step 2
  $metas = @(Get-ChildItem -LiteralPath "$claudeDir\claude-code-sessions" -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue)
  $cwds = $metas | ForEach-Object { (Read-Json $_.FullName).cwd } | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique
  $hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
  $projects = [ordered]@{}
  foreach ($cwd in $cwds) {
    if ($cwd.TrimEnd('\') -eq $HomeDir.TrimEnd('\') -or $cwd.StartsWith($claudeDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
    $top = if ($hasGit) { Invoke-Git $cwd rev-parse --show-toplevel | Select-Object -First 1 }
    $root = if ($top) { $top.Replace('/', '\') } else { $cwd }
    if ($projects.Contains($root)) { continue }
    $info = [ordered]@{ path = $root; remote = $null; unsaved = 0 }
    if ($top) {
      $info.remote = Invoke-Git $root remote get-url origin | Select-Object -First 1
      $info.unsaved = @(Invoke-Git $root status --porcelain).Count + @(Invoke-Git $root log --branches --not --remotes --oneline).Count
    }
    $projects[$root] = $info
  }
  $risky = @($projects.Values | Where-Object { $_.unsaved -gt 0 })
  Put "   [x] Your sessions use $($projects.Count) project folders." ok
  if ($risky.Count) {
    Gap
    Put '   Heads up: these have work that is NOT on GitHub yet:' warn
    foreach ($p in $risky) { Put ('      ' + (Split-Path $p.path -Leaf) + '  (' + (Plural $p.unsaved 'unsaved change') + ')') warn }
    Put '   That work only comes along if you copy the project folder itself to the new laptop,' dim
    Put '   or commit and push it first (Claude can do that for you).' dim
    Wait-Enter 'Press Enter to keep going.'
  }

  Set-Step 3
  $work = New-WorkDir; $script:work = $work
  $sh = Join-Path $work 'home'; $sa = Join-Path $work 'appdata\Claude'; $c = Join-Path $HomeDir '.claude'
  # ~/.claude without caches, live-process files, telemetry and the login token (you sign in again on the new laptop)
  $skipDirs = 'cache', 'shell-snapshots', 'session-env', 'sessions', 'telemetry', 'daemon', 'downloads'
  $skipFiles = '.credentials.json', 'daemon.lock', 'daemon.log', 'daemon.status.json', '.last-cleanup', '.last-update-result.json'
  Copy-Tree $c "$sh\.claude" 'Copying chats, settings, hooks, skills and memory...' (
    @('/XD') + ($skipDirs | ForEach-Object { Q "$c\$_" }) + @('/XF') + ($skipFiles | ForEach-Object { Q "$c\$_" }) + @('claude-data.zip'))
  foreach ($f in '.claude.json', 'AGENTS.md') { Copy-One (Join-Path $HomeDir $f) $sh }
  foreach ($d in 'claude-code-sessions', 'local-agent-mode-sessions', 'scratch-workspaces') {
    Copy-Tree "$claudeDir\$d" "$sa\$d" "Copying the app's session list..." @('/XF', 'claude-data.zip')
  }
  if (-not $claudeOpen) { Copy-Tree "$claudeDir\Local Storage" "$sa\Local Storage" 'Copying your sidebar layout...' }
  foreach ($f in 'claude_desktop_config.json', 'git-worktrees.json') { Copy-One "$claudeDir\$f" $sa }
  $transcripts = 0
  foreach ($d in Get-ChildItem -LiteralPath "$c\projects" -Directory -ErrorAction SilentlyContinue) {
    $transcripts += @(Get-ChildItem -LiteralPath $d.FullName -File -Filter *.jsonl -ErrorAction SilentlyContinue).Count
  }
  Put "   [x] Copied $($metas.Count) sessions and $transcripts chat files." ok
  if ($claudeOpen) { Put '   (Claude was open, so the sidebar layout was skipped.)' dim }

  Set-Step 4
  $dest = Join-Path $(if ($OutDir) { $OutDir } else { $DesktopDir }) "Claude Moove $stamp"
  New-Item -ItemType Directory -Force (Join-Path $dest 'engine') | Out-Null
  $zip = Join-Path $dest 'engine\claude-data.zip'
  $p = Start-Tool tar ('-a -c -f ' + (Q $zip) + ' -C ' + (Q $work) + ' .')
  Wait-Walking $p { if (Test-Path -LiteralPath $zip) { 'Zipping...  ' + [int]((Get-Item -LiteralPath $zip).Length / 1MB) + ' MB so far' } else { 'Zipping...' } }
  if ($p.ExitCode -ne 0) { throw "Zipping failed (tar code $($p.ExitCode)). Is the Desktop's drive full?" }
  $mb = [int]((Get-Item -LiteralPath $zip).Length / 1MB)
  Put "   [x] Zipped: $mb MB." ok

  Set-Step 5
  Get-ChildItem -LiteralPath $toolRoot -Filter '*.cmd' | Copy-Item -Destination $dest
  Copy-One (Join-Path $toolRoot 'LICENSE') $dest
  foreach ($f in 'claude-moove.ps1', 'claude-moove-merge.mjs', 'README.md') { Copy-Item -LiteralPath (Join-Path $engine $f) (Join-Path $dest "engine\$f") }
  $manifest = [ordered]@{
    tool = 'Claude Moove'; version = 1; created = (Get-Date).ToString('o'); computer = $env:COMPUTERNAME
    home = $HomeDir; appData = $AppDataDir; desktop = $DesktopDir; documents = $DocumentsDir
    accounts = @(Get-ChildItem -LiteralPath "$claudeDir\claude-code-sessions" -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
    sessions = $metas.Count; transcripts = $transcripts; projects = @($projects.Values)
  }
  [IO.File]::WriteAllText((Join-Path $dest 'engine\manifest.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
  [IO.File]::WriteAllText($marker, ([ordered]@{ lastPack = (Get-Date).ToString('o') } | ConvertTo-Json), $utf8)
  Remove-Tree $work; $script:work = $null
  Put '   [x] Transfer folder ready.' ok

  Show-Big @(
    "[x] All packed: $($metas.Count) sessions, $transcripts chat files, $mb MB.",
    '',
    'Your transfer folder is on your Desktop:',
    "      Claude Moove $stamp",
    '',
    'WHAT NOW',
    ' 1. Copy that whole folder to a USB stick (or upload it to Google Drive).',
    " 2. On the new laptop, open the folder and double-click  2 - UNPACK (on the laptop you're moving to)",
    '    It walks you through everything else.',
    '',
    'Keep that folder private: it holds your full chat history.')
  if ($warnings.Count) { foreach ($w in $warnings) { Put "  [!] $w" warn } }
  if (-not $Test) { Start-Process explorer.exe "/select,`"$dest`"" }
  End-Wait
}

# ---------------------------------------------------------------- path fixing (different user name, OneDrive Desktop, ...)
function Set-PathMap($manifest) {
  $pairs = @()
  foreach ($pair in @(@($manifest.desktop, $DesktopDir), @($manifest.documents, $DocumentsDir), @($manifest.appData, $AppDataDir), @($manifest.home, $HomeDir))) {
    if ($pair[0] -and $pair[1] -and ($pair[0].TrimEnd('\') -cne $pair[1].TrimEnd('\'))) { $pairs += , @($pair[0].TrimEnd('\'), $pair[1].TrimEnd('\')) }
  }
  $script:pathMap = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
  $script:encMap = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($pair in $pairs) {
    $o = $pair[0]; $n = $pair[1]
    $script:pathMap[$o] = $n                                       # C:\Users\Alex
    $script:pathMap[$o.Replace('\', '\\')] = $n.Replace('\', '\\') # C:\\Users\\Alex   (inside JSON)
    $script:pathMap[$o.Replace('\', '/')] = $n.Replace('\', '/')   # C:/Users/Alex     (CLAUDE.md, hooks)
    $script:encMap[($o -replace '[^A-Za-z0-9]', '-')] = ($n -replace '[^A-Za-z0-9]', '-')   # C--Users-Alex (chat folder names)
  }
  $script:rxPath = $null; $script:rxEnc = $null
  if ($script:pathMap.Count) {
    $keys = ($script:pathMap.Keys | Sort-Object Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $ekeys = ($script:encMap.Keys | Sort-Object Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|'
    # One pass each, longest match first, and never inside a longer name (Alex vs Alexander or Alex.LAPTOP).
    $script:rxPath = [regex]::new("(?:$keys)(?![\w-]|\.\w)", 'IgnoreCase')
    $script:rxEnc = [regex]::new("(?:$ekeys)(?![A-Za-z0-9])", 'IgnoreCase')
  }
  $pairs
}
function Convert-Text([string]$s) {
  if (-not $script:rxPath -or -not $s) { return $s }
  $s = $script:rxPath.Replace($s, [Text.RegularExpressions.MatchEvaluator] { param($m) $script:pathMap[$m.Value] })
  $script:rxEnc.Replace($s, [Text.RegularExpressions.MatchEvaluator] { param($m) $script:encMap[$m.Value] })
}
function Convert-StageFiles([string]$sh, [string]$sa) {
  $files = New-Object System.Collections.Generic.List[IO.FileInfo]
  $sources = @(
    @($sh, $false), @("$sh\.claude", $false), @("$sh\.claude\plugins", $false), @("$sh\.claude\claude-moove", $false), @($sa, $false),
    @("$sa\claude-code-sessions", $true), @("$sa\local-agent-mode-sessions", $true))
  foreach ($src in $sources) {
    try {
      foreach ($f in Get-ChildItem -LiteralPath $src[0] -File -Force -Recurse:$src[1] -ErrorAction SilentlyContinue) {
        if ($f.Extension -in '.json', '.md', '.jsonl') { $files.Add($f) }
      }
    } catch {}
  }
  foreach ($f in $files) {
    try {
      $text = [IO.File]::ReadAllText($f.FullName); $new = Convert-Text $text
      if ($new -cne $text) { $t = $f.LastWriteTimeUtc; [IO.File]::WriteAllText($f.FullName, $new, $utf8); $f.LastWriteTimeUtc = $t }
    } catch { $warnings.Add("Couldn't update paths in $($f.Name).") }
  }
  # Claude keeps each folder's chats in a folder named after the path, so those names change too.
  foreach ($d in Get-ChildItem -LiteralPath "$sh\.claude\projects" -Directory -ErrorAction SilentlyContinue) {
    $new = $script:rxEnc.Replace($d.Name, [Text.RegularExpressions.MatchEvaluator] { param($m) $script:encMap[$m.Value] })
    if ($new -ceq $d.Name) { continue }
    $dest = Join-Path $d.Parent.FullName $new
    if ($new -ieq $d.Name) { Rename-Item -LiteralPath $d.FullName "$new.cmv"; Rename-Item -LiteralPath "$dest.cmv" $new }
    elseif (Test-Path -LiteralPath $dest) { & robocopy $d.FullName $dest /E /MOVE /R:0 /W:0 /NFL /NDL /NJH /NJS /NP | Out-Null }
    else { Rename-Item -LiteralPath $d.FullName $new }
  }
}

# ---------------------------------------------------------------- merging chats that exist on both laptops
# Chat files only ever grow. If one copy is the start of the other, the longer one is newer and wins.
# If both grew differently (you used the same chat on both laptops), both are kept.
function Get-PrefixHash([string]$path, [long]$n) {
  $sha = [Security.Cryptography.SHA256]::Create(); $s = [IO.File]::OpenRead($path)
  try {
    $buf = New-Object byte[] 1048576; $left = $n
    while ($left -gt 0) { $r = $s.Read($buf, 0, [int][Math]::Min($buf.Length, $left)); if ($r -le 0) { break }; [void]$sha.TransformBlock($buf, 0, $r, $null, 0); $left -= $r }
    [void]$sha.TransformFinalBlock($buf, 0, 0); [BitConverter]::ToString($sha.Hash)
  } finally { $s.Dispose(); $sha.Dispose() }
}
function Compare-Transcript([string]$incoming, [string]$local) {
  $a = Get-Item -LiteralPath $incoming; $b = Get-Item -LiteralPath $local
  if ($a.Length -eq $b.Length -and [Math]::Abs(($a.LastWriteTimeUtc - $b.LastWriteTimeUtc).TotalSeconds) -le 2) { return 'same' }
  $n = [Math]::Min($a.Length, $b.Length)
  if ((Get-PrefixHash $incoming $n) -ne (Get-PrefixHash $local $n)) { return 'diverged' }
  if ($a.Length -gt $b.Length) { 'incoming' } elseif ($a.Length -lt $b.Length) { 'local' } else { 'same' }
}
function Get-TargetTranscript([string]$id) { Join-Path (Join-Path "$HomeDir\.claude\projects" $script:transcriptDir[$id]) "$id.jsonl" }
function Add-Pending([string]$a, [string]$b, [string]$titleA, [string]$titleB) {   # each copy gets a one-time note about the other
  $script:pending[$a] = [ordered]@{ otherTranscript = (Get-TargetTranscript $b); otherTitle = $titleB }
  $script:pending[$b] = [ordered]@{ otherTranscript = (Get-TargetTranscript $a); otherTitle = $titleA }
}
function Merge-Transcripts([string]$sh, $referenced) {
  $projT = "$HomeDir\.claude\projects"
  foreach ($d in Get-ChildItem -LiteralPath "$sh\.claude\projects" -Directory -ErrorAction SilentlyContinue) {
    foreach ($f in Get-ChildItem -LiteralPath $d.FullName -File -Filter *.jsonl -ErrorAction SilentlyContinue) {
      $id = $f.BaseName; $script:transcriptDir[$id] = $d.Name
      $t = Join-Path (Join-Path $projT $d.Name) $f.Name
      try {
        if (-not (Test-Path -LiteralPath $t)) { $script:rel[$id] = 'new'; continue }
        $r = Compare-Transcript $f.FullName $t; $script:rel[$id] = $r
        if ($r -eq 'incoming') { $f.LastWriteTimeUtc = [DateTime]::UtcNow }
        elseif ($r -eq 'diverged') {
          $newId = [guid]::NewGuid().ToString()
          $forkPath = Join-Path $d.FullName "$newId.jsonl"
          [IO.File]::WriteAllText($forkPath, [IO.File]::ReadAllText($f.FullName).Replace("`"sessionId`":`"$id`"", "`"sessionId`":`"$newId`""), $utf8)
          (Get-Item -LiteralPath $forkPath).LastWriteTimeUtc = $f.LastWriteTimeUtc
          Remove-Item -LiteralPath $f.FullName -Force
          $script:forkOf[$id] = $newId; $script:transcriptDir[$newId] = $d.Name
          if (-not $referenced.Contains($id)) { Add-Pending $id $newId 'this chat' 'the copy from your other laptop' }
        }
        else { Remove-Item -LiteralPath $f.FullName -Force }   # same, or this laptop's copy is newer: leave it alone
      } catch { $warnings.Add("Couldn't compare chat $id; kept the newer file.") }
    }
  }
}
function Get-SessionRelation($I, $L) {   # I = from the other laptop, L = already on this laptop
  if ($I.cliSessionId -eq $L.cliSessionId) {
    switch ($script:rel[$I.cliSessionId]) { 'incoming' { return 'incoming' } 'new' { return 'incoming' } 'diverged' { return 'diverged' } default { return 'local' } }
  }
  # One side rewound or forked into a new chat file: whoever moved on from an untouched copy of the other is newer.
  if ((@($I.priorCliSessionIds) -contains $L.cliSessionId) -and ($script:rel[$L.cliSessionId] -in 'same', 'incoming')) { return 'incoming' }
  if ((@($L.priorCliSessionIds) -contains $I.cliSessionId) -and ($script:rel[$I.cliSessionId] -in 'same', 'local')) { return 'local' }
  'diverged'
}
function Merge-Sessions([string]$sa) {
  $sessS = "$sa\claude-code-sessions"; $sessT = "$claudeDir\claude-code-sessions"
  foreach ($f in Get-ChildItem -LiteralPath $sessS -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue) {
    $t = $sessT + $f.FullName.Substring($sessS.Length)
    if (-not (Test-Path -LiteralPath $t)) { $script:count.new++; continue }
    $I = Read-Json $f.FullName; $L = Read-Json $t
    switch (Get-SessionRelation $I $L) {
      'incoming' { $f.LastWriteTimeUtc = [DateTime]::UtcNow; $script:count.updated++ }
      'local' { Remove-Item -LiteralPath $f.FullName -Force; $script:count.kept++ }
      'diverged' {
        # Keep this laptop's session as it is and add the other laptop's version next to it.
        $cli = if ($script:forkOf.ContainsKey($I.cliSessionId)) { $script:forkOf[$I.cliSessionId] } else { $I.cliSessionId }
        $newLocal = 'local_' + [guid]::NewGuid()
        $text = [IO.File]::ReadAllText($f.FullName)
        $text = ([regex]'"sessionId"\s*:\s*"[^"]*"').Replace($text, "`"sessionId`":`"$newLocal`"", 1)
        $text = ([regex]'"cliSessionId"\s*:\s*"[^"]*"').Replace($text, "`"cliSessionId`":`"$cli`"", 1)
        $text = ([regex]'"title"\s*:\s*"((?:[^"\\]|\\.)*)"').Replace($text, [Text.RegularExpressions.MatchEvaluator] { param($m) '"title":"' + $m.Groups[1].Value + ' (other laptop)"' }, 1)
        [IO.File]::WriteAllText((Join-Path $f.DirectoryName "$newLocal.json"), $text, $utf8)
        Remove-Item -LiteralPath $f.FullName -Force
        if (-not $script:transcriptDir.ContainsKey($L.cliSessionId)) { $script:transcriptDir[$L.cliSessionId] = $L.cwd -replace '[^A-Za-z0-9]', '-' }
        if (-not $script:transcriptDir.ContainsKey($cli)) { $script:transcriptDir[$cli] = $I.cwd -replace '[^A-Za-z0-9]', '-' }
        Add-Pending $L.cliSessionId $cli $L.title ("$($I.title) (other laptop)")
        $script:count.both++
      }
    }
  }
  # Archived chats: keep everything archived on either laptop archived.
  foreach ($f in Get-ChildItem -LiteralPath $sessS -Recurse -File -Filter 'archived-sessions.idx' -ErrorAction SilentlyContinue) {
    $t = $sessT + $f.FullName.Substring($sessS.Length)
    if (-not (Test-Path -LiteralPath $t)) { continue }
    $all = @(@((Read-Json $f.FullName).archived) + @((Read-Json $t).archived) | Where-Object { $_ } | Sort-Object -Unique)
    [IO.File]::WriteAllText($f.FullName, ([ordered]@{ v = 1; archived = $all } | ConvertTo-Json -Compress), $utf8)
    $f.LastWriteTimeUtc = [DateTime]::UtcNow
  }
}

# ---------------------------------------------------------------- UNPACK (laptop you're moving to)
function Invoke-Unpack {
  $script:what = 'moving in on this laptop'
  $script:steps = 'Find your packed stuff', 'Claude app installed', 'Signed in to the same account', 'Close Claude', 'Unpack and merge your chats', 'Node.js and Git', 'Your project folders'
  Show-Big @(
    'This moves all your Claude stuff onto THIS laptop: every chat and session, your global',
    'CLAUDE.md, settings, hooks, skills, plugins and memory. Nothing already here gets lost.',
    'It takes about 5 minutes, and I check everything as we go.')
  Wait-Enter 'Press Enter to start.'

  Set-Step 1
  $zip = Join-Path $engine 'claude-data.zip'; $mf = Join-Path $engine 'manifest.json'
  if (-not (Test-Path -LiteralPath $zip) -or -not (Test-Path -LiteralPath $mf)) {
    throw "This folder has no packed Claude stuff in it. On your old laptop, double-click '1 - PACK', then bring over the folder it puts on the Desktop."
  }
  $manifest = Read-Json $mf
  Put ('   [x] Packed on ' + $manifest.computer + ' at ' + ([datetime]$manifest.created).ToString('yyyy-MM-dd HH:mm') + ": $($manifest.sessions) sessions.") ok

  Set-Step 2
  while (-not (Test-Path -LiteralPath (Join-Path $claudeDir 'config.json'))) {
    Put "   Claude isn't installed on this laptop yet (or hasn't been opened once)." warn
    Put '     1. Press Enter and I open the download page for you.' plain
    Put '     2. Install Claude, open it and sign in.' plain
    Put '     3. Come back to this window and press Enter.' plain
    if ($Test) { throw 'Claude is not installed (test run).' }
    Wait-Enter 'Press Enter to open the download page.'
    Start-Process 'https://claude.ai/download'
    Wait-Enter 'Claude installed and you are signed in? Press Enter.'
    Set-Step 2
  }
  Put '   [x] Claude is installed.' ok

  Set-Step 3
  while ($true) {
    $acct = (Read-Json (Join-Path $claudeDir 'config.json')).lastKnownAccountUuid
    if ($acct -and ((@($manifest.accounts) -contains $acct) -or -not @($manifest.accounts).Count)) { Put '   [x] Signed in to the same account as your old laptop.' ok; break }
    if (-not $acct) {
      Put "   You're not signed in to Claude yet." warn
      Put '   Open Claude and sign in with the same account you used on your old laptop.' plain
      if ($Test) { throw 'Not signed in (test run).' }
      Wait-Enter 'Signed in? Press Enter.'
    } else {
      Put "   You're signed in to a DIFFERENT Claude account than on your old laptop." warn
      Put '   Your chats belong to the old account and only show up when you use that one.' plain
      Put '   Switch accounts in Claude, then press Enter. (Or type C and press Enter to carry on anyway.)' plain
      if ($Test -or (Read-Answer 'Your choice:') -eq 'C') { break }
    }
    Set-Step 3
  }

  Set-Step 4
  [void](Close-Claude)

  Set-Step 5
  $work = New-WorkDir; $script:work = $work
  $p = Start-Tool tar ('-x -f ' + (Q $zip) + ' -C ' + (Q $work))
  Wait-Walking $p { 'Unpacking...' }
  if ($p.ExitCode -ne 0) { throw "Couldn't unpack claude-data.zip (tar code $($p.ExitCode)). It may be damaged: copy the folder over again." }
  $sh = Join-Path $work 'home'; $sa = Join-Path $work 'appdata\Claude'
  $firstMoove = -not (Test-Path -LiteralPath $marker)   # first time here: the packed settings replace the fresh install's defaults

  $pairs = @(Set-PathMap $manifest)
  if ($pairs.Count) {
    Put '   [x] Your folders have different paths on this laptop; fixing them:' ok
    foreach ($pair in $pairs) { Put ('         ' + $pair[0] + '  ->  ' + $pair[1]) dim }
    Convert-StageFiles $sh $sa
  }

  $script:rel = @{}; $script:forkOf = @{}; $script:pending = @{}; $script:transcriptDir = @{}
  $script:count = @{ new = 0; updated = 0; kept = 0; both = 0 }
  $referenced = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($dir in "$sa\claude-code-sessions", "$claudeDir\claude-code-sessions") {
    foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue) {
      $j = Read-Json $f.FullName
      foreach ($id in @($j.cliSessionId) + @($j.priorCliSessionIds)) { if ($id) { [void]$referenced.Add($id) } }
    }
  }
  Merge-Transcripts $sh $referenced
  Merge-Sessions $sa

  # Settings and instruction files. Normally the newer copy wins. On a laptop's first unpack the packed ones win,
  # because what's there is just a fresh install. Anything replaced is saved in the safety folder first.
  $safety = Join-Path $HomeDir ".claude-moove-safety\$stamp"
  $config = @()
  $config += Get-ChildItem -LiteralPath "$sh\.claude" -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.json', '.md' }
  $config += Get-ChildItem -LiteralPath "$sh\.claude\plugins" -File -Force -Filter *.json -ErrorAction SilentlyContinue
  $config += Get-ChildItem -LiteralPath $sh -File -Force -ErrorAction SilentlyContinue
  $config += Get-ChildItem -LiteralPath $sa -File -Force -Filter *.json -ErrorAction SilentlyContinue
  $toHome = { param($p) if ($p.StartsWith($sh)) { $HomeDir + $p.Substring($sh.Length) } else { $claudeDir + $p.Substring($sa.Length) } }

  Copy-Tree "$sh\.claude" "$HomeDir\.claude" 'Putting your chats, hooks, skills and memory in place...' (
    @('/XF') + ($config | Where-Object { $_.FullName.StartsWith("$sh\.claude\") } | ForEach-Object { Q $_.FullName })) -Merge
  Copy-Tree $sa $claudeDir "Putting the app's session list in place..." (
    @('/XD', (Q "$sa\Local Storage"), '/XF') + ($config | Where-Object { $_.FullName.StartsWith($sa) } | ForEach-Object { Q $_.FullName })) -Merge

  $replaced = 0
  foreach ($f in $config) {
    $dest = & $toHome $f.FullName
    if (Test-Path -LiteralPath $dest) {
      if ((Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $f.FullName).Hash) { continue }
      if (-not $firstMoove -and (Get-Item -LiteralPath $dest -Force).LastWriteTimeUtc -ge $f.LastWriteTimeUtc) { continue }
      $keep = Join-Path $safety $dest.Substring([IO.Path]::GetPathRoot($dest).Length)
      New-Item -ItemType Directory -Force (Split-Path $keep) | Out-Null
      Copy-Item -LiteralPath $dest $keep -Force
      $replaced++
    }
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath $f.FullName $dest -Force
  }
  # The sidebar layout is a small database: it's swapped whole (never mixed), and only for a newer one.
  $lsS = "$sa\Local Storage"; $lsT = "$claudeDir\Local Storage"
  if (Test-Path -LiteralPath $lsS) {
    $newest = { param($d) (Get-ChildItem -LiteralPath $d -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc | Select-Object -Last 1).LastWriteTimeUtc }
    if ($firstMoove -or -not (Test-Path -LiteralPath $lsT) -or ((& $newest $lsS) -gt (& $newest $lsT))) {
      if (Test-Path -LiteralPath $lsT) { New-Item -ItemType Directory -Force $safety | Out-Null; Move-Item -LiteralPath $lsT (Join-Path $safety 'Local Storage'); $replaced++ }
      Copy-Tree $lsS $lsT 'Putting your sidebar layout in place...'
    }
  }
  if ($script:pending.Count) {
    $pf = Join-Path $HomeDir '.claude\claude-moove\pending-merges.json'
    $all = [ordered]@{}
    if (Test-Path -LiteralPath $pf) { (Read-Json $pf).PSObject.Properties | ForEach-Object { $all[$_.Name] = $_.Value } }
    foreach ($k in $script:pending.Keys) { $all[$k] = $script:pending[$k] }
    New-Item -ItemType Directory -Force (Split-Path $pf) | Out-Null
    [IO.File]::WriteAllText($pf, ($all | ConvertTo-Json -Depth 5), $utf8)
  }
  [IO.File]::WriteAllText($marker, ([ordered]@{ lastUnpack = (Get-Date).ToString('o'); from = $manifest.computer } | ConvertTo-Json), $utf8)
  Remove-Tree $work; $script:work = $null

  $cnt = $script:count
  if ($cnt.new) { Put "   [x] Added from your old laptop: $(Plural $cnt.new 'session')." ok }
  if ($cnt.updated) { Put "   [x] Updated because the other laptop's copy was newer: $(Plural $cnt.updated 'session')." ok }
  if ($cnt.kept) { Put "   [x] Already up to date here, left as they are: $(Plural $cnt.kept 'session')." ok }
  if ($cnt.both) { Put "   [x] Used on BOTH laptops: $(Plural $cnt.both 'chat'). You get both copies, nothing lost." warn }
  if ($replaced) { Put "   [x] Older settings replaced; the old ones are saved in $safety" ok }

  Set-Step 6
  $tools = @(
    @{ name = 'Node.js'; cmd = 'node'; id = 'OpenJS.NodeJS.LTS'; url = 'https://nodejs.org/en/download'; why = 'Claude hooks and plugins often run on it' },
    @{ name = 'Git'; cmd = 'git'; id = 'Git.Git'; url = 'https://git-scm.com/download/win'; why = 'Claude uses it in your projects, and it can download them from GitHub' })
  foreach ($tool in $tools) {
    if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) { Put "   [x] $($tool.name) is installed." ok; continue }
    Put "   [ ] $($tool.name) is missing: $($tool.why)." warn
    if ($Test) { $warnings.Add("$($tool.name) isn't installed."); continue }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      if ((Read-Answer "Press Enter to install $($tool.name) now (this accepts its license), or type S and Enter to skip.") -ne 'S') {
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & winget install --id $tool.id -e --silent --accept-package-agreements --accept-source-agreements
        $ErrorActionPreference = $old; Update-Path
      }
    } else {
      Wait-Enter "Press Enter to open the $($tool.name) download page."
      Start-Process $tool.url
      Wait-Enter 'Install it, then press Enter.'
      Update-Path
    }
    if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) { Put "   [x] $($tool.name) is installed." ok } else { $warnings.Add("$($tool.name) still isn't installed: $($tool.why).") }
  }
  if ($script:pending.Count) {
    # The one-time "this chat was also used on your other laptop" note. Inert unless a note is waiting.
    $hook = Join-Path $HomeDir '.claude\hooks\claude-moove-merge.mjs'
    New-Item -ItemType Directory -Force (Split-Path $hook) | Out-Null
    Copy-Item -LiteralPath (Join-Path $engine 'claude-moove-merge.mjs') $hook -Force
    if (Get-Command node -ErrorAction SilentlyContinue) { & node $hook --install (Join-Path $HomeDir '.claude\settings.json'); Put '   [x] Merge note switched on for the chats used on both laptops.' ok }
    else { $warnings.Add('The note about chats used on both laptops needs Node.js; both copies are still there.') }
  }

  Set-Step 7
  $missing = @()
  foreach ($proj in @($manifest.projects)) {
    if (-not $proj) { continue }
    $path = Convert-Text $proj.path
    if (-not (Test-Path -LiteralPath $path)) { $missing += [pscustomobject]@{ path = $path; remote = $proj.remote; unsaved = $proj.unsaved } }
  }
  if (-not $missing.Count) { Put '   [x] All your project folders are here.' ok }
  else {
    $fromGit = @($missing | Where-Object { $_.remote })
    if ($fromGit.Count -and (Get-Command git -ErrorAction SilentlyContinue)) {
      Put "   These project folders aren't on this laptop yet, but they're on GitHub:" plain
      foreach ($m in $fromGit) { Put ('      ' + $m.path) plain }
      $answer = Read-Answer 'Press Enter to download them to exactly those places (a GitHub sign-in may pop up), or type S and Enter to skip.'
      if (-not $Test -and $answer -ne 'S') {
        foreach ($m in $fromGit) {
          New-Item -ItemType Directory -Force (Split-Path $m.path) | Out-Null
          $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
          & git clone $m.remote $m.path
          $ErrorActionPreference = $old
          if (Test-Path -LiteralPath $m.path) { Put ('   [x] Downloaded ' + (Split-Path $m.path -Leaf)) ok }
        }
      }
    }
    foreach ($m in $missing) {
      $name = Split-Path $m.path -Leaf
      if (-not (Test-Path -LiteralPath $m.path)) { $warnings.Add("Copy the folder '$name' from your old laptop to exactly: $($m.path)") }
      elseif ($m.unsaved -gt 0) { $warnings.Add("'$name' came from GitHub, but its $($m.unsaved) unsaved changes from the old laptop aren't in it. Copy them over if you need them.") }
    }
  }
  # Keep the buttons on this laptop's Desktop for the next move.
  $keepTool = Join-Path $DesktopDir 'Claude Moove'
  if ($toolRoot.TrimEnd('\') -ne $keepTool) {
    New-Item -ItemType Directory -Force (Join-Path $keepTool 'engine') | Out-Null
    Get-ChildItem -LiteralPath $toolRoot -Filter '*.cmd' | Copy-Item -Destination $keepTool -Force
    Copy-One (Join-Path $toolRoot 'LICENSE') $keepTool
    foreach ($f in 'claude-moove.ps1', 'claude-moove-merge.mjs', 'README.md') { Copy-Item -LiteralPath (Join-Path $engine $f) (Join-Path $keepTool "engine\$f") -Force }
  }

  $final = @("[x] You're moved in. Open Claude: your sessions are in the sidebar.")
  if ($cnt.both) { $final += "[x] Used on both laptops: $(Plural $cnt.both 'chat'). You have both: the one from here, and the one marked '(other laptop)'.", "    The first time you open either, Claude gets a one-time note about what happened in the other." }
  foreach ($w in $warnings) { $final += "[!] $w" }
  $final += '', "Next time you move: open 'Claude Moove' on your Desktop and double-click 1 - PACK."
  Show-Big $final
  End-Wait
}

function Show-Fail([string]$msg) {
  if ($script:steps) { Show-Header } else { Clear-Screen; foreach ($l in Get-Clawd) { Put (' ' + $l) clawd } ; Gap }
  Put '   Oh no, something went wrong:' bad
  Put "   $msg" bad
  Gap
  Put "   Nothing was deleted. If you're stuck, take a photo of this screen and show it to Claude." dim
  End-Wait
}

function Invoke-Preview {   # draws each screen once, without doing anything, to check how they look
  $script:what = 'packing up this laptop'
  $script:steps = 'Close Claude', 'Check your projects', 'Copy your Claude stuff', 'Zip it up', 'Make your transfer folder'
  Write-Host '@@SCREEN The first thing you see'
  Show-Big @(
    'This packs ALL your Claude stuff into one folder you can carry to your next laptop:',
    'every chat and session, your global CLAUDE.md, settings, hooks, skills, plugins and memory.',
    'It takes about 5 minutes.')
  Wait-Enter 'Press Enter to start.'
  Write-Host '@@SCREEN Every step after that (Clawd stays at the top, the flowers bloom as you go)'
  Set-Step 4
  Put '   [x] Copied 42 sessions and 120 chat files.' ok
  Put '   Zipping...  640 MB so far  2:13' plain
  Write-Host '@@SCREEN Unpacking on the new laptop (paths fixed and chats merged for you)'
  $script:what = 'moving in on this laptop'
  $script:steps = 'Find your packed stuff', 'Claude app installed', 'Signed in to the same account', 'Close Claude', 'Unpack and merge your chats', 'Node.js and Git', 'Your project folders'
  Set-Step 5
  Put '   [x] Your folders have different paths on this laptop; fixing them:' ok
  Put '         C:\Users\Alex\Desktop  ->  C:\Users\alex.lee\OneDrive\Desktop' dim
  Put '         C:\Users\Alex  ->  C:\Users\alex.lee' dim
  Put '   [x] Added from your old laptop: 38 sessions.' ok
  Put "   [x] Updated because the other laptop's copy was newer: 3 sessions." ok
  Put '   [x] Used on BOTH laptops: 1 chat. You get both copies, nothing lost.' warn
  $script:what = 'packing up this laptop'
  $script:steps = 'Close Claude', 'Check your projects', 'Copy your Claude stuff', 'Zip it up', 'Make your transfer folder'
  Write-Host '@@SCREEN The end'
  Show-Big -Bloom @(
    '[x] All packed: 42 sessions, 120 chat files, 900 MB.',
    'Your transfer folder is on your Desktop:  Claude Moove 2026-01-01 1200',
    'WHAT NOW',
    ' 1. Copy that whole folder to a USB stick (or upload it to Google Drive).',
    " 2. On the new laptop, open it and double-click  2 - UNPACK (on the laptop you're moving to)",
    'Keep that folder private: it holds your full chat history.')
  End-Wait
}

try {
  switch ($Mode) { 'pack' { Invoke-Pack } 'unpack' { Invoke-Unpack } 'preview' { Invoke-Preview } }
  Remove-Tree $script:work
  exit 0
} catch {
  $msg = $_.Exception.Message
  Remove-Tree $script:work
  Show-Fail $msg
  exit 3
}
