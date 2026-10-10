# CLAUDE MOOVE engine: carries everything Claude from one Windows laptop to another.
# Started by the two buttons one folder up: "pack" on the laptop you're leaving, "unpack" on the one you're moving to.
# What it moves and how it merges: README.md next to this file. This file is plain ASCII on purpose;
# Clawd's block characters are built from character codes so any Windows can read it.
param(
  [Parameter(Mandatory = $true)][ValidateSet('menu', 'pack', 'unpack', 'preview')][string]$Mode,
  # This laptop's folders. The defaults are the real ones; tests point them somewhere else.
  [string]$HomeDir = $env:USERPROFILE,
  [string]$AppDataDir = $env:APPDATA,
  [string]$DesktopDir = [Environment]::GetFolderPath('Desktop'),
  [string]$DocumentsDir = [Environment]::GetFolderPath('MyDocuments'),
  [string]$OutDir = '',   # where pack puts the transfer folder (default: the Desktop)
  [ValidateSet('ask', 'send', 'usb')][string]$Transfer = 'ask',   # pack: how the folder gets to the new laptop
  [string]$ReceiveCode = '',   # unpack: the croc code, instead of asking for it
  [string[]]$What = @(),  # what comes along: chats, memory, instructions, settings, hooks, skills, plugins, sidebar, projects (default: all that apply)
  [string]$Projects = '', # per project, "name=mode,...": all, github, claude or none (* for every project)
  [string]$From = '',     # unpack: the transfer folder to use, instead of looking for one
  [string]$Choices = '',  # unpack: JSON file, a choice per file changed on both laptops: mine, theirs, both, or a merged file's path
  [switch]$Plan,          # unpack: only report what would happen (JSON), with copies of the other laptop's versions; changes nothing
  [switch]$Yes,           # no questions: take the defaults; never closes Claude or installs anything
  [switch]$Json,          # quiet: the result comes as one MOOVE-JSON line (for the Claude skill)
  [switch]$WhenClosed,    # unpack: skip the pick screen, wait for Claude to close, then bring in -What
  [switch]$Test           # unattended test run: never closes Claude, opens pages or installs anything
)
$ErrorActionPreference = 'Stop'
$engine    = $PSScriptRoot
$toolRoot  = Split-Path $engine
$stamp     = Get-Date -Format 'yyyy-MM-dd HHmm'
$claudeDir = Join-Path $AppDataDir 'Claude'
$marker    = Join-Path $claudeDir 'claude-moove-synced.json'
$utf8      = New-Object System.Text.UTF8Encoding($false)
$warnings  = New-Object System.Collections.Generic.List[string]
$homepage  = 'https://github.com/paulgegenyi/claude-moove'
$oneLiner  = 'irm https://raw.githubusercontent.com/paulgegenyi/claude-moove/main/moove.ps1 | iex'
$script:work = $null
$script:received = $null
if ($Plan) { $Json = [switch]$true }
$What = @($What | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
$quiet = [bool]$Json                      # no screens, just the result
$interactive = -not ($Yes -or $Json)      # someone is at the keyboard

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
  if ($quiet) { return }
  if ($vt) { Write-Host "$E[$($ink[$kind])m$text$E[0m" -NoNewline:$n } else { Write-Host $text -ForegroundColor $fallbackInk[$kind] -NoNewline:$n }
}
function Gap { if (-not $quiet) { Write-Host '' } }
function Clear-Screen { if ($Mode -eq 'preview' -or $quiet) { return }; if ($Test) { Write-Host ''; Write-Host ('=' * 40); return }; try { Clear-Host } catch {} }

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
  if ($quiet) { return }
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
  if ($quiet) { return }
  Clear-Screen
  $c = Get-Clawd $frame
  $total = $script:steps.Count; $done = $script:step - 1
  Put (' ' + $c[0] + '  ') clawd -n; Put 'CLAUDE MOOVE' title -n; Put ('  ' + [char]0xB7 + '  ' + $script:doing) dim
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
function Read-Line {   # one typed line; test runs read scripted lines when input is redirected, or get an empty answer
  if (-not $interactive) { return '' }
  if ($Test) {
    if ([Console]::IsInputRedirected) { $l = [Console]::In.ReadLine(); if ($null -ne $l) { Write-Host "<< $l"; return $l.Trim() } }
    return ''
  }
  ([Console]::ReadLine() + '').Trim()
}
function Wait-Enter([string]$text) { Gap; Put "   $text" title; if ($interactive -and -not $Test) { [void][Console]::ReadLine() } }
function Read-Answer([string]$text) { Gap; Put "   $text" title; (Read-Line).ToUpper() }
function End-Wait { Gap; Put '   Press any key to close this window.' dim; if ($interactive -and -not $Test) { try { [void][Console]::ReadKey($true) } catch { [void](Read-Host) } } }

# Runs a tool in the background while Clawd walks and a timer ticks, so a long step never looks frozen.
function Start-Tool([string]$exe, [string]$argLine) {
  # Started through cmd, which sends its output to a log, so the process is ours from the start and its exit code is always
  # there (Start-Process can lose it when a tool finishes in an instant).
  $log = Join-Path $env:TEMP 'claude-moove-tool.log'
  $psi = New-Object System.Diagnostics.ProcessStartInfo 'cmd.exe', ('/d /s /c "' + $exe + ' ' + $argLine + ' > "' + $log + '" 2>&1"')
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  [System.Diagnostics.Process]::Start($psi)
}
function Show-Walk([int]$frame, [string]$text, [datetime]$t0) {   # one frame of Clawd walking, with the status and a timer
  if ($Test -or $quiet) { return }
  $canDraw = $false; try { $canDraw = $vt -and ([Console]::CursorTop -lt ([Console]::WindowHeight - 1)) } catch {}
  if ($canDraw) {
    $c = Get-Clawd $frame
    Write-Host -NoNewline ("$E" + '7' + "$E[1;2H$E[$($ink.clawd)m" + $c[0] + "$E[2;2H" + $c[1] + "$E[3;2H" + $c[2] + "$E[0m$E" + '8')
  }
  $el = (Get-Date) - $t0
  Write-Host -NoNewline ("`r" + ("   $text  " + ('{0}:{1:00}' -f [int][Math]::Floor($el.TotalMinutes), $el.Seconds)).PadRight(70))   # padded, so a shorter status covers a longer one
}
function Wait-Walking($proc, [scriptblock]$status, [scriptblock]$giveUp) {
  $frame = 0; $t0 = Get-Date
  while (-not $proc.HasExited) {
    if ($giveUp -and (& $giveUp)) { $proc.Kill(); break }
    Show-Walk $frame $(if ($status) { & $status } else { 'Working...' }) $t0
    Start-Sleep -Milliseconds 350; $frame = 1 - $frame
  }
  $proc.WaitForExit()
  if (-not $Test -and -not $quiet) { Write-Host ("`r" + (' ' * 70) + "`r") -NoNewline }
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

# Settings files that get combined are read into case-sensitive dictionaries: ConvertFrom-Json refuses a .claude.json
# that holds two folders whose names differ only in case, which Claude writes. They're written back the way Claude writes them.
Add-Type -AssemblyName System.Web.Extensions
function New-JsonMap { New-Object 'System.Collections.Generic.Dictionary[string,object]' }
function Read-JsonMap([string]$path) {
  $text = [IO.File]::ReadAllText($path)
  if (-not $text.Trim()) { return New-JsonMap }
  $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
  $js.MaxJsonLength = [int]::MaxValue; $js.RecursionLimit = 1000
  $j = $js.DeserializeObject($text)
  if ($j -isnot [Collections.IDictionary]) { throw "$path doesn't hold a JSON object." }
  $j
}
# Only the escapes JSON needs, so hook commands keep their && and >
$jsonEscapes = New-Object regex '[\x00-\x1f"\\]', 'Compiled'
$jsonEscape = [Text.RegularExpressions.MatchEvaluator] {
  param($m)
  switch ([int]$m.Value[0]) { 34 { '\"' } 92 { '\\' } 10 { '\n' } 13 { '\r' } 9 { '\t' } 8 { '\b' } 12 { '\f' } default { '\u{0:x4}' -f $_ } }
}
$epoch = New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
function Format-JsonString([string]$s) { '"' + $jsonEscapes.Replace($s, $jsonEscape) + '"' }
function Write-JsonText($v, [string]$pad = '') {   # two-space indents, like Claude's own files
  if ($null -eq $v) { return 'null' }
  if ($v -is [string]) { return Format-JsonString $v }
  if ($v -is [bool]) { return $(if ($v) { 'true' } else { 'false' }) }
  if ($v -is [datetime]) { return Format-JsonString ('/Date({0})/' -f [long]($v.ToUniversalTime() - $epoch).TotalMilliseconds) }   # read from a "\/Date(n)\/" string
  $in = $pad + '  '
  if ($v -is [Collections.IDictionary]) {
    if (-not $v.Count) { return '{}' }
    return "{`n" + (@(foreach ($k in $v.Keys) { $in + (Format-JsonString $k) + ': ' + (Write-JsonText $v[$k] $in) }) -join ",`n") + "`n$pad}"
  }
  if ($v -is [Collections.IList]) {
    if (-not $v.Count) { return '[]' }
    return "[`n" + (@(foreach ($x in $v) { $in + (Write-JsonText $x $in) }) -join ",`n") + "`n$pad]"
  }
  if ($v -is [double] -or $v -is [single]) { return $v.ToString('R', [Globalization.CultureInfo]::InvariantCulture) }
  ([IFormattable]$v).ToString($null, [Globalization.CultureInfo]::InvariantCulture)
}
# Lists that are sets, so both laptops' entries can be kept: permission rules, allowed tools, MCP server switches, starred sessions,
# allowed sites. Any other list (a command's arguments, say) depends on its order, so it comes whole from the old laptop.
$setLists = 'allow', 'deny', 'ask', 'additionalDirectories', 'allowedTools', 'enabledMcpjsonServers', 'disabledMcpjsonServers', 'starred-local-code-sessions', 'launchPreviewAllowedOrigins'
function Merge-Json($mine, $theirs, [string]$name = '') {   # the old laptop's value wins; whatever only this PC has stays
  if ($mine -is [Collections.IDictionary] -and $theirs -is [Collections.IDictionary]) {
    $out = New-JsonMap
    foreach ($k in $theirs.Keys) { if ($mine.ContainsKey($k)) { $out[$k] = Merge-Json $mine[$k] $theirs[$k] $k } else { $out[$k] = $theirs[$k] } }
    foreach ($k in $mine.Keys) { if (-not $out.ContainsKey($k)) { $out[$k] = $mine[$k] } }
    return $out
  }
  if ($setLists -ccontains $name -and $mine -is [Array] -and $theirs -is [Array]) {   # both laptops' entries, each once, the old laptop's first
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'; $list = New-Object System.Collections.Generic.List[object]
    foreach ($x in @($theirs) + @($mine)) { if ($seen.Add((Write-JsonText $x))) { $list.Add($x) } }
    return , $list.ToArray()
  }
  if ($name -cmatch '^has[A-Z]' -and $mine -is [bool] -and $mine -and $theirs -is [bool]) { return $true }   # trusted or set up once here: still so
  if ($theirs -is [Array]) { return , $theirs }
  $theirs
}
# This PC's own IDs, install, sign-in, device pairing and how far its Claude has updated its files, which must never become the old laptop's
$machineKeys = @{ '.claude.json' = 'userID', 'machineID', 'anonymousId', 'oauthAccount', 'installMethod', 'autoUpdates', 'autoUpdatesProtectedForNative', 'firstStartTime', 'migrationVersion'
  'claude_desktop_config.json' = 'preferences.remoteToolsDeviceName', 'preferences.chromeExtension' }
function Set-MachineKeys($merged, $mine, [string]$file) {
  foreach ($path in @($machineKeys[$file] | Where-Object { $_ })) {
    $bits = @($path.Split('.')); $leaf = $bits[-1]; $m = $merged; $h = $mine
    for ($i = 0; $i -lt $bits.Count - 1; $i++) {
      $m = if ($m -is [Collections.IDictionary] -and $m.ContainsKey($bits[$i])) { $m[$bits[$i]] } else { $null }
      $h = if ($h -is [Collections.IDictionary] -and $h.ContainsKey($bits[$i])) { $h[$bits[$i]] } else { $null }
    }
    if ($m -isnot [Collections.IDictionary]) { continue }
    if ($h -is [Collections.IDictionary] -and $h.ContainsKey($leaf)) { $m[$leaf] = $h[$leaf] } else { [void]$m.Remove($leaf) }
  }
}
function Write-TextFile([string]$path, [string]$text) {   # WriteAllText refuses a hidden or read-only file (Copy-Item -Force didn't); its attributes stay
  $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  $odd = [IO.FileAttributes]'Hidden, ReadOnly'
  $attr = if ($item -and ($item.Attributes -band $odd)) { $item.Attributes }
  if ($attr) { $rest = $attr -band -bnot $odd; $item.Attributes = $(if ($rest) { $rest } else { [IO.FileAttributes]::Normal }) }
  [IO.File]::WriteAllText($path, $text, $utf8)
  if ($attr) { (Get-Item -LiteralPath $path -Force).Attributes = $attr }
}
function Invoke-Git([string]$dir) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $o = & git -C $dir -c core.quotepath=off @args 2>$null; if ($LASTEXITCODE -eq 0) { $o } } finally { $ErrorActionPreference = $old }   # file names as they are, not escaped
}
function Update-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
# Test runs never touch the real Claude: a file in the fake profile stands for "Claude is open", and closing deletes it.
function Test-ClaudeOpen {
  if ($Test) { return Test-Path -LiteralPath (Join-Path $claudeDir 'test-claude-open') }
  [bool](Get-Process -Name claude -ErrorAction SilentlyContinue)
}
function Stop-Claude {   # $true once Claude is closed. Chats are saved as you go, so nothing gets lost
  if ($Test) { Remove-Item -LiteralPath (Join-Path $claudeDir 'test-claude-open') -Force -ErrorAction SilentlyContinue; return $true }
  Get-Process -Name claude -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  for ($i = 0; $i -lt 30 -and (Test-ClaudeOpen); $i++) { Start-Sleep -Milliseconds 500 }
  -not (Test-ClaudeOpen)
}

# ---------------------------------------------------------------- sending over the internet (croc)
# croc (open source, MIT) sends a folder end to end encrypted, matched by a one-time code. Nothing is opened
# on either laptop: both only connect out, directly on the same network or through croc's relay otherwise.
function Get-Croc {   # croc's path; installs or upgrades it first (with permission) when missing or older than v10
  Update-Path
  $cmd = Get-Command croc -ErrorAction SilentlyContinue
  if ($cmd) { try { if ([version]((& $cmd.Source --version) -replace '[^0-9.]', '') -ge [version]'10.0') { return $cmd.Source } } catch {} }
  if ($Test) { return $null }
  if (-not $interactive) { $warnings.Add('Sending needs croc 10 or newer. Install it with  winget install schollz.croc  and try again.'); return $null }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { $warnings.Add("Sending needs croc, and this laptop can't install apps by itself."); return $null }
  Put '   To send over the internet I use croc: a small, free, open-source tool that sends' plain
  Put '   folders end-to-end encrypted, matched by a one-time code.' plain
  if ((Read-Answer "Press Enter to install it from Windows' app catalogue (this accepts its MIT licence), or type S and Enter to skip.") -eq 'S') { return $null }
  $verb = if ($cmd) { 'upgrade' } else { 'install' }
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  & winget $verb --id schollz.croc --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
  $ErrorActionPreference = $old
  Update-Path
  $cmd = Get-Command croc -ErrorAction SilentlyContinue
  if ($cmd) { $cmd.Source } else { $warnings.Add("croc didn't install."); $null }
}
function Start-Croc([string]$croc, [string[]]$croArgs, [string]$log) {
  $p = Start-Process -FilePath $croc -ArgumentList $croArgs -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
  $null = $p.Handle
  $p
}
function Read-Log([string]$log) {   # what croc has printed so far (it keeps both files open while it runs)
  $text = ''
  foreach ($f in $log, "$log.err") {
    try { $fs = [IO.File]::Open($f, 'Open', 'Read', 'ReadWrite'); try { $text += (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() } } catch {}
  }
  $text
}
function Remove-Log([string]$log) { foreach ($f in $log, "$log.err") { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
function Get-LastLine([string]$text) { $l = @(($text -split "[`r`n]+") | Where-Object { $_.Trim() }); if ($l.Count) { $l[$l.Count - 1].Trim() } else { '(nothing)' } }
function Get-Percent([string]$text) { $m = [regex]::Matches($text, '(\d{1,3})%'); if ($m.Count) { $m[$m.Count - 1].Groups[1].Value + '%' } else { '' } }
function New-LogPath([string]$kind) { Join-Path $env:TEMP ("claude-moove-$kind-" + [guid]::NewGuid().ToString('N') + '.log') }

function Get-SendStatus([string]$text) {   # what croc is doing, from what it has printed: getting the folder ready, waiting for the code, or sending
  $lines = @(($text -split "[`r`n]+") | Where-Object { $_.Trim() })
  $at = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*Sending \(.*->') { $at = $i } }   # "Sending (this laptop->new laptop)": connected
  if ($at -ge 0) {   # then a bar per file, like "claude-data.zip  44% |...| (141/315 MB, 680 MB/s)"
    $bar = "$(@($lines | Select-Object -Skip ($at + 1) | Where-Object { $_ -match '\d%' }) | Select-Object -Last 1)"
    $pc = [regex]::Match($bar, '(\d{1,3})%'); $speed = [regex]::Match($bar, '[\d.]+ ?[kMG]?B/s')
    return 'Sending to the new laptop...' + $(if ($pc.Success) { '  ' + $pc.Value }) + $(if ($speed.Success) { ', ' + $speed.Value })
  }
  $last = if ($lines.Count) { $lines[-1] } else { '' }
  if ($last -match '^\s*Hashing') {   # croc fingerprints the files first, at disk speed: nothing has left this laptop yet
    $pc = [regex]::Match($last, '(\d{1,3})%')
    return 'Getting the folder ready...' + $(if ($pc.Success) { '  ' + $pc.Value })
  }
  'Waiting for the new laptop to type the code...'
}
function Send-Folder([string]$folder) {   # returns $true once the new laptop has everything
  $croc = Get-Croc
  if (-not $croc) { return $false }
  $p = $null; $code = ''; $log = ''
  # croc's own DNS lookup first (Windows' lookup of the relay can take longer than croc waits), Windows' as the fallback
  foreach ($extra in @(@('--internal-dns'), @())) {
    $log = New-LogPath 'send'
    $p = Start-Croc $croc (@('--ignore-stdin', '--disable-clipboard') + $extra + @('send', (Q $folder))) $log
    $t0 = Get-Date
    while (-not $p.HasExited -and -not $code -and ((Get-Date) - $t0).TotalSeconds -lt 60) {
      Start-Sleep -Milliseconds 300
      $m = [regex]::Match((Read-Log $log), 'code=([A-Za-z0-9-]+)'); if ($m.Success) { $code = $m.Groups[1].Value }
    }
    if ($code) { break }
    if (-not $p.HasExited) { $p.Kill() }
    Remove-Log $log
  }
  if (-not $code) { $warnings.Add("Couldn't reach croc's relay, so nothing was sent. Carry the folder on a USB stick instead."); return $false }
  Gap
  Put '   Your code:   ' plain -n; Put $code pink
  Gap
  Put '   On the NEW laptop, open PowerShell and paste:' title
  Put "     $oneLiner" plain
  Put '   then choose  2  (move in) and type the code above when it asks.' plain
  Put '   Keep this window open until it says done.' dim
  Put '   The code works once: only type it on your own laptop.' dim
  Put "   If the new laptop can't connect, close this and carry the folder instead (it's on your Desktop)." dim
  if ($Test -or $Json) { Write-Host "MOOVE-CODE:$code" }   # for the Claude skill and unattended tests
  Gap
  Wait-Walking $p { Get-SendStatus (Read-Log $log) }
  $ok = $p.ExitCode -eq 0
  $why = Get-LastLine (Read-Log $log)
  Remove-Log $log
  if (-not $ok) { $warnings.Add("The transfer stopped before it finished (croc said: $why). Run PACK again for a new code, or carry the folder on a USB stick.") }
  $ok
}

function Find-PackedFolders {   # packed folders on this PC or a plugged-in drive, newest first
  $places = @($DesktopDir, (Join-Path $HomeDir 'Downloads'), $DocumentsDir) +
    @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Root -ne "$env:SystemDrive\" } | ForEach-Object Root)
  $hits = foreach ($p in $places) {
    if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
    foreach ($d in Get-ChildItem -LiteralPath $p -Directory -Filter 'Claude Moove*' -ErrorAction SilentlyContinue) {
      # also one level down: a zip extracted into a folder of the same name, or a folder received with croc
      foreach ($c in @($d) + @(Get-ChildItem -LiteralPath $d.FullName -Directory -Filter 'Claude Moove*' -ErrorAction SilentlyContinue)) {
        if (Test-Path -LiteralPath (Join-Path $c.FullName 'engine\claude-data.zip')) { $c }
      }
    }
  }
  @($hits | Sort-Object LastWriteTime -Descending)
}
function Read-Code { Gap; Put '   Code (or just press Enter to stop):' title; Read-Line }
function Receive-Folder {   # asks for the old laptop's code and receives its folder; returns that folder's path
  Put '   If your old laptop is sending it over the internet, type the code it shows.' plain
  for ($try = 1; $try -le 3; $try++) {
    $c = if ($ReceiveCode) { $ReceiveCode } else { Read-Code }
    if (-not $c) { throw 'Nothing to unpack yet. Pack on the old laptop first, then send it, or plug in the drive you carried it on.' }
    if ($c -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{4,63}$') {
      Put "   That doesn't look like a code. It's a few words joined by dashes, like  joy-buzz-tiger" warn
      if ($ReceiveCode) { break } else { continue }
    }
    $croc = Get-Croc
    if (-not $croc) { throw 'Receiving needs croc. Carry the folder over on a USB stick instead.' }
    $inbox = Join-Path $DesktopDir "Claude Moove received $stamp"
    New-Item -ItemType Directory -Force $inbox | Out-Null
    $text = ''
    foreach ($extra in @(@('--internal-dns'), @())) {
      $log = New-LogPath 'receive'; $t0 = Get-Date
      $p = Start-Croc $croc (@('--ignore-stdin', '--yes', '--overwrite') + $extra + @('--out', (Q $inbox), $c)) $log
      Wait-Walking $p { $pc = Get-Percent (Read-Log $log); if ($pc) { "Receiving...  $pc" } else { 'Connecting to your old laptop...' } } {
        ((Get-Date) - $t0).TotalSeconds -gt 120 -and -not (Get-Percent (Read-Log $log)) }   # nobody sending: give up after 2 minutes
      $text = Read-Log $log
      Remove-Log $log
      $found = Get-ChildItem -LiteralPath $inbox -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'engine\manifest.json') } | Select-Object -First 1
      if ($p.ExitCode -eq 0 -and $found) { Put '   [x] Received from your old laptop.' ok; $script:received = $found.FullName; return $found.FullName }
    }   # a failed first try gets a second one with Windows' DNS lookup, for networks that block outside DNS
    if ($text -match 'rate limit|admission') {   # croc's free relay allows 5 transfers an hour per internet connection
      Put "   croc's free relay is busy for this internet connection: it allows 5 transfers an hour." warn
      Put '   Wait a while and pack again for a fresh code, use your phone''s hotspot, or carry the folder on a USB stick.' warn
    }
    else { Put "   That didn't work. Check the code on your old laptop (its window must still be open) and try again." warn }
    Put ('   croc said: ' + (Get-LastLine $text)) dim
    if ($ReceiveCode) { break }
  }
  throw "Couldn't receive anything from the old laptop. Run PACK there again for a fresh code, or carry the folder on a USB stick."
}

# ---------------------------------------------------------------- what can come along
$labels = [ordered]@{ chats = 'Chats and sessions'; memory = 'Memory'; instructions = 'Instructions'; settings = 'Settings'; hooks = 'Hooks'
  skills = 'Skills, commands, agents'; plugins = 'Plugins'; sidebar = 'Sidebar layout'; projects = 'Projects' }
$skipDirs  = 'cache', 'shell-snapshots', 'session-env', 'sessions', 'telemetry', 'daemon', 'downloads'
$skipFiles = '.credentials.json', 'daemon.lock', 'daemon.log', 'daemon.status.json', '.last-cleanup', '.last-update-result.json'
$chatDirs  = 'projects', 'file-history', 'todos', 'plans', 'uploads'   # in ~/.claude; projects also holds memory
$appChats  = 'claude-code-sessions', 'local-agent-mode-sessions', 'scratch-workspaces'
$partDirs  = [ordered]@{ instructions = @('rules'); hooks = @('hooks'); skills = @('skills', 'commands', 'agents', 'output-styles'); plugins = @('plugins') }   # their folders in ~/.claude
$partKeys  = [ordered]@{ hooks = @('hooks'); plugins = @('enabledPlugins', 'extraKnownMarketplaces') }   # and their switches in settings.json
$rootFiles = 'CLAUDE.md', 'CLAUDE.local.md', 'AGENTS.md'
# Folders that installing or building brings back, so they never travel. In git repos, ignored build output too.
$rebuildable = 'node_modules', '.venv', 'venv', '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache', '.tox', '.next', '.nuxt', '.svelte-kit',
  '.turbo', '.parcel-cache', '.cache', '.gradle', '.terraform', '.vs', '.angular', '.expo', '.dart_tool', 'Pods', 'DerivedData'
$generated = 'dist', 'build', 'target', 'coverage', 'out'
$bigProject = 300MB   # a project with more local files than this starts as "GitHub only" or "Claude files only"

function Show-Top([string]$subtitle) {   # small Clawd header for the pick screens
  if ($quiet) { return }
  Clear-Screen
  $c = Get-Clawd
  Put (' ' + $c[0] + '  ') clawd -n; Put 'CLAUDE MOOVE' title -n; Put ('  ' + [char]0xB7 + '  ' + $script:doing) dim
  Put (' ' + $c[1] + '  ') clawd -n; Put $subtitle plain
  Put (' ' + $c[2] + '  ') clawd -n; Write-Host (Get-FlowerBar 4 4)
  Gap
}
function Get-Lower([string]$key) { $l = $labels[$key]; $l.Substring(0, 1).ToLower() + $l.Substring(1) }   # "skills, commands, agents"
function Write-Item([int]$n, $it, [string]$lock) {
  $on = $it.on -and -not $lock
  $line = '   {0,2}  {1} {2,-27} {3}' -f $n, $(if ($on) { '[x]' } else { '[ ]' }), $labels[$it.key], $(if ($lock) { $lock } else { $it.detail })
  Put $line $(if ($on) { 'plain' } else { 'dim' })
}
function Read-Choice { Gap; Put '   > ' title -n; Read-Line }
function Write-Result($obj) { if ($Json) { Write-Host ('MOOVE-JSON:' + ($obj | ConvertTo-Json -Compress -Depth 8)) } }
function Format-Size([long]$b) {
  $ic = [Globalization.CultureInfo]::InvariantCulture
  if ($b -ge 1GB) { [string]::Format($ic, '{0:0.0} GB', $b / 1GB) } elseif ($b -ge 1MB) { [string]::Format($ic, '{0:0.0} MB', $b / 1MB) }
  elseif ($b -ge 1KB) { [string]::Format($ic, '{0:0} KB', $b / 1KB) } else { "$b bytes" }
}
function Install-Tool([string]$which) {   # Node.js or Git, with Windows' own app installer when it's there
  $t = if ($which -eq 'node') { @{ name = 'Node.js'; cmd = 'node'; id = 'OpenJS.NodeJS.LTS'; url = 'https://nodejs.org/en/download' } } else { @{ name = 'Git'; cmd = 'git'; id = 'Git.Git'; url = 'https://git-scm.com/download/win' } }
  if ($Test) { return }
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Put "   Installing $($t.name) (this accepts its licence)..." plain
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & winget install --id $t.id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
    $ErrorActionPreference = $old
  } else {
    Start-Process $t.url
    Wait-Enter "Install $($t.name) from the page that just opened, then press Enter."
  }
  Update-Path
}

# ---------------------------------------------------------------- your projects
function Get-ProjectClaudeFiles([string]$root, [bool]$isGit) {   # project Claude files GitHub doesn't have (all of them outside git)
  $root = $root.TrimEnd('\')
  $cands = @(foreach ($n in $rootFiles) { if (Test-Path -LiteralPath (Join-Path $root $n) -PathType Leaf) { $n } })
  foreach ($d in Get-ChildItem -LiteralPath (Join-Path $root '.claude') -Force -ErrorAction SilentlyContinue) {
    if ($d.PSIsContainer -and $d.Name -eq 'worktrees') { continue }   # agent worktrees are whole copies of the project
    $files = if ($d.PSIsContainer) { Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue } else { $d }
    foreach ($f in $files) { if ($f.Length -lt 5MB -and $f.Extension -ne '.lock') { $cands += $f.FullName.Substring($root.Length + 1) } }   # lock files only matter while Claude runs
  }
  if (-not $isGit -or -not $cands.Count) { return $cands }
  $spec = @($rootFiles) + '.claude' + ':(exclude).claude/worktrees'
  $notOnGit = @{}
  foreach ($l in @(Invoke-Git $root ls-files --others --exclude-standard @spec) + @(Invoke-Git $root ls-files --others --ignored --exclude-standard @spec) + @(Invoke-Git $root ls-files --modified @spec)) {
    if ($l) { $notOnGit[$l.Replace('/', '\')] = $true }
  }
  @($cands | Where-Object { $notOnGit.ContainsKey($_) })
}
function Test-Skipped([string]$rel, [string[]]$skip) {   # rebuildable folders, transfer folders, agent worktrees and Claude's lock files
  foreach ($part in $rel.Split('\')) { if ($skip -contains $part -or $part -like 'Claude Moove*') { return $true } }
  ($rel -like '.claude\worktrees*') -or ($rel -like '.claude\*.lock')
}
function Measure-Files([string]$root, [string[]]$rels, [string[]]$skip, [string[]]$except, [long]$budget) {
  # how many files and bytes are in these folders below root (rebuildable ones left out); stops counting once past the budget
  $n = 0; $bytes = [long]0
  $todo = New-Object System.Collections.Generic.Stack[string]
  foreach ($r in $rels) { $todo.Push($r) }
  while ($todo.Count -and $bytes -le $budget) {
    $r = $todo.Pop(); $entries = @()
    try { $entries = ([IO.DirectoryInfo]$(if ($r) { Join-Path $root $r } else { $root })).GetFileSystemInfos() } catch { continue }   # too deep or not allowed: not counted
    foreach ($e in $entries) {
      if ($skip -contains $e.Name -or $e.Name -like 'Claude Moove*') { continue }
      $er = if ($r) { "$r\$($e.Name)" } else { $e.Name }
      if ($er -like '.claude\worktrees*' -or $er -like '.claude\*.lock') { continue }
      if ($e -is [IO.DirectoryInfo]) { if (-not ($e.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $except -notcontains $e.FullName) { $todo.Push($er) } }   # no links, no projects of their own
      else { $n++; $bytes += $e.Length }
    }
  }
  @{ count = $n; size = $bytes; big = ($bytes -gt $budget) }
}
function Get-LocalFiles([string]$root) {   # what GitHub doesn't have as it is: untracked, git-ignored and changed files
  $skip = $rebuildable + $generated
  $dirs = @(); $loose = @(); $deleted = @(); $looseBytes = [long]0
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($l in @(Invoke-Git $root ls-files --others --exclude-standard --directory) + @(Invoke-Git $root ls-files --others --ignored --exclude-standard --directory)) {
    if (-not $l -or $l.StartsWith('"')) { continue }   # names git can only print quoted are rare; they stay behind
    $rel = $l.TrimEnd('/').Replace('/', '\')
    if ((Test-Skipped $rel $skip) -or -not $seen.Add($rel)) { continue }
    if ($l.EndsWith('/')) { $dirs += $rel }
    else { $fi = Get-Item -LiteralPath (Join-Path $root $rel) -Force -ErrorAction SilentlyContinue; if ($fi -and -not $fi.PSIsContainer) { $loose += $rel; $looseBytes += $fi.Length } }
  }
  foreach ($l in @(Invoke-Git $root ls-files --modified)) {   # changed since the last commit, or deleted
    if (-not $l -or $l.StartsWith('"')) { continue }
    $rel = $l.Replace('/', '\')
    if (-not $seen.Add($rel)) { continue }
    $fi = Get-Item -LiteralPath (Join-Path $root $rel) -Force -ErrorAction SilentlyContinue
    if ($fi) { $loose += $rel; $looseBytes += $fi.Length } else { $deleted += $rel }
  }
  $m = Measure-Files $root $dirs $skip @() ($bigProject - $looseBytes)
  @{ dirs = $dirs; loose = $loose; deleted = $deleted; count = $m.count + $loose.Count; size = $m.size + $looseBytes; big = $m.big -or ($looseBytes -gt $bigProject)
    sample = (Get-Sample (@($dirs | ForEach-Object { "$_\" }) + $loose)) }
}
function Get-TranscriptFolder([string]$file) {   # the folder a chat ran in, from the first lines of its transcript
  $sr = $null
  try {
    $sr = New-Object IO.StreamReader($file)
    for ($i = 0; $i -lt 50; $i++) {
      $l = $sr.ReadLine(); if ($null -eq $l) { break }
      if ($l.Contains('"cwd"')) { $c = ($l | ConvertFrom-Json).cwd; if ($c) { return $c } }
    }
  } catch {} finally { if ($sr) { $sr.Dispose() } }
  $null
}
function Get-ChatFolders {   # every folder a chat ran in: Code tab sessions, and terminal chats from their transcripts
  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($f in Get-ChildItem -LiteralPath "$claudeDir\claude-code-sessions" -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue) {
    try { $c = (Read-Json $f.FullName).cwd; if ($c) { [void]$set.Add($c.TrimEnd('\')) } } catch {}
  }
  foreach ($d in Get-ChildItem -LiteralPath "$HomeDir\.claude\projects" -Directory -ErrorAction SilentlyContinue) {
    foreach ($t in Get-ChildItem -LiteralPath $d.FullName -File -Filter *.jsonl -ErrorAction SilentlyContinue) {
      $c = Get-TranscriptFolder $t.FullName
      if ($c) { [void]$set.Add($c.TrimEnd('\')); break }   # the chats in one folder all started in the same place
    }
  }
  $set
}
function Get-Projects {   # each folder you've chatted in (or its git repo), with what could come along from it
  $hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
  $notProjects = @("$HomeDir\.claude", $claudeDir, "$HomeDir\AppData\Local\Temp") | ForEach-Object { $_.TrimEnd('\') + '\' }   # Claude's own and temporary folders
  $special = @($DesktopDir, $DocumentsDir, "$HomeDir\Desktop", "$HomeDir\Documents", "$HomeDir\Downloads") | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
  $found = [ordered]@{}
  foreach ($cwd in @(Get-ChatFolders | Sort-Object)) {
    if (-not (Test-Path -LiteralPath $cwd -PathType Container)) { continue }
    if (@($notProjects | Where-Object { ($cwd + '\').StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { continue }
    $root = $cwd; $top = $null
    if ($hasGit) {
      $g = @(Invoke-Git $cwd rev-parse --path-format=absolute --show-toplevel --git-dir --git-common-dir)
      if ($g.Count -ge 3) {
        $top = $g[0].Replace('/', '\')
        # a worktree (the app makes them for some sessions) belongs to its main checkout
        $top = if ($g[1] -ne $g[2]) { Split-Path $g[2].Replace('/', '\') } else { $top }
      } else { $top = Invoke-Git $cwd rev-parse --show-toplevel | Select-Object -First 1; if ($top) { $top = $top.Replace('/', '\') } }
      if ($top) { $root = $top }
    }
    if ($root.TrimEnd('\') -eq $HomeDir.TrimEnd('\') -or $found.Contains($root)) { continue }   # your user folder is not a project
    $found[$root] = [bool]$top
  }
  $roots = @($found.Keys)
  $list = foreach ($root in $roots) {
    if (-not $quiet -and -not $Test) { Write-Host -NoNewline ("`r   Looking at your projects: $(Split-Path $root -Leaf)..." + (' ' * 30)) }
    $p = [ordered]@{ name = (Split-Path $root -Leaf); path = $root; kind = 'local'; remote = $null; branch = $null; head = $null; ahead = 0
      mode = 'none'; modes = @(); dirs = @(); loose = @(); deleted = @(); count = 0; size = [long]0; big = $false; sample = ''; claude = @(); slot = 0; bundle = $false }
    $isGit = $found[$root]
    if (($special -contains $root) -or ([IO.Path]::GetPathRoot($root).TrimEnd('\') -eq $root)) { $p.kind = 'special' }   # Desktop and such: only Claude files
    elseif ($isGit) {
      $p.remote = Invoke-Git $root remote get-url origin | Select-Object -First 1
      if ($p.remote) { $p.kind = 'git' }
      $p.branch = Invoke-Git $root rev-parse --abbrev-ref HEAD | Select-Object -First 1
      $p.head = Invoke-Git $root rev-parse HEAD | Select-Object -First 1
      $p.ahead = @(Invoke-Git $root rev-list --branches --not --remotes).Count   # commits that aren't on GitHub
    }
    $p.claude = @(Get-ProjectClaudeFiles $root $isGit)
    if ($p.kind -eq 'git') {
      $l = Get-LocalFiles $root
      foreach ($k in 'dirs', 'loose', 'deleted', 'count', 'size', 'big', 'sample') { $p[$k] = $l[$k] }
    } elseif ($p.kind -eq 'local') {   # the whole folder, without projects inside it
      $m = Measure-Files $root @('') $rebuildable @($roots | Where-Object { $_ -ne $root }) $bigProject
      $p.count = $m.count; $p.size = $m.size; $p.big = $m.big
      $p.sample = Get-Sample @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue | Where-Object { $rebuildable -notcontains $_.Name -and $_.Name -notlike 'Claude Moove*' } |
          ForEach-Object { if ($_.PSIsContainer) { "$($_.Name)\" } else { $_.Name } })
    }
    if ($p.kind -eq 'git') { $p.modes = @('all', 'github', 'none') } elseif ($p.kind -eq 'local') { $p.modes = @('all', 'claude', 'none') } else { $p.modes = @('claude', 'none') }
    if ($p.kind -eq 'special') { if (-not $p.claude.Count) { continue }; $p.mode = 'claude' }   # nothing of Claude's there: not worth a line
    elseif (-not $p.big) { $p.mode = 'all' }
    elseif ($p.kind -eq 'git') { $p.mode = 'github' }
    elseif ($p.claude.Count) { $p.mode = 'claude' }
    $p
  }
  if (-not $quiet -and -not $Test) { Write-Host -NoNewline ("`r" + (' ' * 90) + "`r") }
  @($list)
}
function Set-ProjectModes($plist, [string]$spec) {   # -Projects "name=mode,...": all, github, claude or none; * means every project
  foreach ($part in @($spec -split ',' | Where-Object { $_.Trim() })) {
    $name, $mode = $part.Trim() -split '\s*=\s*', 2
    $hit = @(if ($name -eq '*') { $plist } else { $plist | Where-Object { $_.name -eq $name -or $_.path -eq $name } })
    if (-not $hit.Count) { $warnings.Add("-Projects: there's no project called '$name'."); continue }
    foreach ($p in $hit) {
      $m = if ($mode) { $mode.ToLower() } else { $p.modes[0] }
      if ($p.modes -contains $m) { $p.mode = $m } else { $warnings.Add("-Projects: $($p.name) can be $($p.modes -join ', '), not '$mode'.") }
    }
  }
}
function Get-Sample($rels) {   # the first few names, folders first, like "data\, .env, CLAUDE.local.md"
  $tops = @($rels | ForEach-Object { $i = $_.IndexOf('\'); if ($i -gt 0) { $_.Substring(0, $i + 1) } else { $_ } } | Select-Object -Unique)
  $tops = @($tops | Sort-Object { -not $_.EndsWith('\') }, { $_ })
  (($tops | Select-Object -First 2) -join ', ') + $(if ($tops.Count -gt 2) { ', ...' })   # two, so a line fits the window
}
function Get-ModeText($p) {   # what happens to a project, in a few words
  switch ($p.mode) {
    'all' { if ($p.kind -eq 'git') { 'GitHub + local files' } else { 'whole folder' } }
    'github' { 'GitHub only' }
    'claude' { 'Claude files only' }
    default { 'left behind' }
  }
}
function Show-ProjectsOut($plist, $state) {   # pack: which projects come along, and how
  Show-Top 'Pick your projects. Just Enter goes back.'
  Put '       Project              Comes along' title
  $n = 0
  foreach ($p in $plist) {
    $n++; $on = $p.mode -ne 'none'
    $amount = if ($p.big) { "over $([int]($bigProject / 1MB)) MB" } else { "$(Format-Size $p.size), $(Plural $p.count 'file')" }
    $detail = switch ($p.mode) {
      'all' { $(if ($p.count) { "$($amount): $($p.sample)" } elseif ($p.kind -eq 'git') { 'nothing else: GitHub has it all' } else { 'empty' }) +
        $(if ($p.ahead) { "; $(Plural $p.ahead 'unpushed commit')" }) }
      'github' { $(if ($p.count) { "local files stay behind ($($amount): $($p.sample))" } else { '' }) + $(if ($p.ahead) { "; $(Plural $p.ahead 'unpushed commit') come along" }) }
      'claude' { $(if ($p.claude.Count) { $p.claude -join ', ' } else { 'none here' }) + $(if ($p.kind -eq 'local' -and $p.size) { "; the folder ($amount) stays behind" }) }
      default { $(if ($p.kind -eq 'git') { 'not downloaded on the new laptop' } else { '' }) }
    }
    Put ('   {0,2}  {1,-20} ' -f $n, $p.name) $(if ($on) { 'plain' } else { 'dim' }) -n
    Put ('{0,-21} ' -f (Get-ModeText $p)) $(if ($on) { 'pink' } else { 'dim' }) -n
    Put $detail.TrimStart(';', ' ') dim
  }
  Gap
  Put "   GitHub projects download again on the new laptop. Local files are what GitHub doesn't have:" dim
  Put '   git-ignored files like .env, and uncommitted work. node_modules and the like stay behind.' dim
  if ($state.msg) { Gap; Put "   $($state.msg)" warn; $state.msg = '' }
  Gap
  Put '   Type a number to switch. A brings everything, N nothing. Just Enter goes back.' dim
}
function Edit-Projects($plist, [string]$show) {   # the projects screen: a number switches a project, A all, N none, Enter goes back
  $state = @{ msg = '' }
  while ($interactive) {
    & $show $plist $state
    $a = Read-Choice
    if ($a -eq '') { return }
    $k = 0
    if ([int]::TryParse($a, [ref]$k) -and $k -ge 1 -and $k -le $plist.Count) { $p = $plist[$k - 1]; $p.mode = $p.modes[([array]::IndexOf($p.modes, $p.mode) + 1) % $p.modes.Count] }
    elseif ($a -eq 'A') { foreach ($p in $plist) { $p.mode = $p.modes[0] } }
    elseif ($a -eq 'N') { foreach ($p in $plist) { $p.mode = 'none' } }
    else { $state.msg = "I didn't get that one." }
  }
}
function Get-ProjectsLine($plist) {   # the projects line on the main screen
  $going = @($plist | Where-Object { $_.mode -ne 'none' })
  if (-not $plist.Count) { return 'none found' }
  $local = [long]0; foreach ($p in $going) { if ($p.mode -eq 'all') { $local += $p.size } }
  "$($going.Count) of $($plist.Count)" + $(if ($local) { ", $(Format-Size $local) of local files" }) 
}
function Copy-FileList([string]$from, [string]$to, [string[]]$rels, [string]$label) {   # a list of files, one robocopy per folder (long paths are fine)
  $byDir = [ordered]@{}
  foreach ($r in $rels) { $d = Split-Path $r; if (-not $byDir.Contains($d)) { $byDir[$d] = New-Object System.Collections.Generic.List[string] }; $byDir[$d].Add((Split-Path $r -Leaf)) }
  foreach ($d in $byDir.Keys) {
    $names = $byDir[$d]
    for ($i = 0; $i -lt $names.Count; $i += 40) {
      $chunk = $names.GetRange($i, [Math]::Min(40, $names.Count - $i))
      $a = @((Q $(if ($d) { Join-Path $from $d } else { $from })), (Q $(if ($d) { Join-Path $to $d } else { $to }))) + @($chunk | ForEach-Object { Q $_ }) + @('/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/IS', '/IT')
      $p = Start-Tool robocopy ($a -join ' ')
      Wait-Walking $p { $label }
      if ($p.ExitCode -ge 8) { $warnings.Add("Some files in $(Join-Path $from $d) couldn't be copied (robocopy code $($p.ExitCode)).") }
    }
  }
}
function Copy-Projects($plist, [string]$work) {   # each project's files under projects\<n>, and commits GitHub doesn't have as projects\<n>.bundle
  $n = 0
  $roots = @($plist | ForEach-Object { $_.path })
  foreach ($p in $plist) {
    if ($p.mode -eq 'none') { continue }
    $n++; $p.slot = $n; $to = "$work\projects\$n"
    if ($p.mode -eq 'all' -and $p.kind -eq 'local') {   # the whole folder, without rebuildable folders and projects inside it
      Copy-Tree $p.path $to "Copying $($p.name)..." (@('/XD') + @($rebuildable | ForEach-Object { Q $_ }) + @((Q 'Claude Moove*'), (Q "$($p.path)\.claude\worktrees")) +
        @($roots | Where-Object { $_ -ne $p.path -and $_.StartsWith($p.path + '\', [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { Q $_ }))
    } elseif ($p.mode -eq 'all') {   # a GitHub project: only what GitHub doesn't have
      foreach ($d in $p.dirs) {
        $x = @('/XD') + @(($rebuildable + $generated) | ForEach-Object { Q $_ }) + @((Q 'Claude Moove*'), (Q "$($p.path)\.claude\worktrees"))
        if ($d -eq '.claude' -or $d -like '.claude\*') { $x += @('/XF', '*.lock') }   # Claude's lock files only matter while it runs
        Copy-Tree "$($p.path)\$d" "$to\$d" "Copying $($p.name)..." $x
      }
      if ($p.loose.Count) { Copy-FileList $p.path $to $p.loose "Copying $($p.name)..." }
    } elseif ($p.mode -eq 'claude' -and $p.claude.Count) { Copy-FileList $p.path $to $p.claude "Copying $($p.name)..." }
    if ($p.kind -eq 'git' -and $p.ahead) {   # every local branch's commits that aren't on GitHub, as one git bundle
      $b = "$work\projects\$n.bundle"
      $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
      & git -C $p.path bundle create $b --branches --not --remotes 2>&1 | Out-Null
      $ErrorActionPreference = $old
      $p.bundle = Test-Path -LiteralPath $b
      if (-not $p.bundle) { $warnings.Add("$($p.name): its $(Plural $p.ahead 'commit') that aren't on GitHub couldn't be packed. Push them first.") }
    }
  }
}
function Save-PartialSettings($want, [string]$to) {   # settings.json with only the ticked parts' switches (hooks, plugins) in it
  $from = Join-Path $HomeDir '.claude\settings.json'
  if (-not (Test-Path -LiteralPath $from)) { return }
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  $drop = @(foreach ($k in $partKeys.Keys) { if (-not $want[$k]) { $partKeys[$k] } })
  if ($want.settings -and -not $drop.Count) { Copy-Item -LiteralPath $from $to -Force; return }   # all of it, as it is
  $j = Read-Json $from
  if ($want.settings) { foreach ($key in $drop) { $j.PSObject.Properties.Remove($key) } }
  else {   # settings unticked: only the switches of the ticked parts
    $keep = @(foreach ($k in $partKeys.Keys) { if ($want[$k]) { $partKeys[$k] } })
    foreach ($prop in @($j.PSObject.Properties)) { if ($keep -notcontains $prop.Name) { $j.PSObject.Properties.Remove($prop.Name) } }
  }
  [IO.File]::WriteAllText($to, ($j | ConvertTo-Json -Depth 64), $utf8)
  (Get-Item -LiteralPath $to).LastWriteTimeUtc = (Get-Item -LiteralPath $from).LastWriteTimeUtc   # it still counts as the age of the original
}
function Copy-Selected($want, [string]$work, $plist) {   # copies only the ticked kinds of data into the work folder
  $sh = Join-Path $work 'home'; $sa = Join-Path $work 'appdata\Claude'; $c = Join-Path $HomeDir '.claude'
  $parts = @($partDirs.Values | ForEach-Object { $_ })
  if ($want.settings) {   # the rest of ~/.claude: settings files, scheduled tasks and such (not chats, memory, caches or the login token)
    Copy-Tree $c "$sh\.claude" 'Copying your settings...' (
      @('/XD') + (($skipDirs + $chatDirs + $parts) | ForEach-Object { Q "$c\$_" }) +
      @('/XF') + (($skipFiles + 'history.jsonl', 'CLAUDE.md', 'settings.json') | ForEach-Object { Q "$c\$_" }) + @('claude-data.zip'))
    Copy-One (Join-Path $HomeDir '.claude.json') $sh
    Copy-One "$claudeDir\claude_desktop_config.json" $sa
  }
  if ($want.settings -or $want.hooks -or $want.plugins) { Save-PartialSettings $want "$sh\.claude\settings.json" }
  if ($want.instructions) {
    Copy-One "$c\CLAUDE.md" "$sh\.claude"; Copy-One (Join-Path $HomeDir 'AGENTS.md') $sh
    Copy-Tree "$c\rules" "$sh\.claude\rules" 'Copying your instructions...'
  }
  foreach ($k in 'hooks', 'skills', 'plugins') { if ($want[$k]) { foreach ($d in $partDirs[$k]) { Copy-Tree "$c\$d" "$sh\.claude\$d" "Copying your $(Get-Lower $k)..." } } }
  if ($want.chats) {
    Copy-Tree "$c\projects" "$sh\.claude\projects" 'Copying your chats...' @('/XD', 'memory')
    foreach ($d in $chatDirs | Where-Object { $_ -ne 'projects' }) { Copy-Tree "$c\$d" "$sh\.claude\$d" 'Copying your chats...' }
    Copy-One "$c\history.jsonl" "$sh\.claude"
    foreach ($d in $appChats) { Copy-Tree "$claudeDir\$d" "$sa\$d" "Copying the app's session list..." @('/XF', 'claude-data.zip') }
    Copy-One "$claudeDir\git-worktrees.json" $sa
  }
  if ($want.memory) {
    foreach ($d in Get-ChildItem -LiteralPath "$c\projects" -Directory -ErrorAction SilentlyContinue) {
      if (Test-Path -LiteralPath "$($d.FullName)\memory") { Copy-Tree "$($d.FullName)\memory" "$sh\.claude\projects\$($d.Name)\memory" 'Copying memory...' }
    }
  }
  if ($want.sidebar) { Copy-Tree "$claudeDir\Local Storage" "$sa\Local Storage" 'Copying your sidebar layout...' }
  if ($want.projects) { Copy-Projects $plist $work }
}
function Get-PartDetails([string]$base) {   # what a home folder's .claude holds, kind by kind, for the pick screens (kinds with nothing are left out)
  $c = Join-Path $base '.claude'
  $count = { param($dir, $filter) @(Get-ChildItem -LiteralPath "$c\$dir" -Recurse -File -Filter $filter -ErrorAction SilentlyContinue).Count }
  $s = $null; try { $s = Read-Json "$c\settings.json" } catch {}
  $d = @{}
  $ins = @(@('CLAUDE.md', (Test-Path -LiteralPath "$c\CLAUDE.md")), @('AGENTS.md', (Test-Path -LiteralPath (Join-Path $base 'AGENTS.md'))), @('rules', ((& $count 'rules' '*.md') -gt 0))) | Where-Object { $_[1] } | ForEach-Object { $_[0] }
  if ($ins) { $d.instructions = 'your global ' + (@($ins) -join ', ') }
  $d.settings = 'settings.json, MCP servers, app settings'
  $h = & $count 'hooks' '*'
  if ($h -or ($s -and $s.hooks)) { $d.hooks = $(if ($h) { Plural $h 'hook file' } else { 'set up in settings.json' }) }
  $sk = @(Get-ChildItem -LiteralPath "$c\skills" -Directory -ErrorAction SilentlyContinue).Count; $cm = & $count 'commands' '*.md'; $ag = & $count 'agents' '*.md'
  $bits = @(if ($sk) { Plural $sk 'skill' }; if ($cm) { Plural $cm 'command' }; if ($ag) { Plural $ag 'agent' })
  if ($bits.Count -or (& $count 'output-styles' '*')) { $d.skills = $(if ($bits.Count) { $bits -join ', ' } else { 'output styles' }) }
  $pl = 0; try { $pl = @((Read-Json "$c\plugins\installed_plugins.json").plugins.PSObject.Properties).Count } catch {}
  if ($pl -or (Test-Path -LiteralPath "$c\plugins") -or ($s -and $s.enabledPlugins)) { $d.plugins = $(if ($pl) { Plural $pl 'plugin' } else { 'your plugins' }) }
  $d
}

# ---------------------------------------------------------------- PACK (laptop you're leaving)
function Show-PackMenu($items, $state, $plist) {
  Show-Top 'Pick what comes along, then press Enter.'
  Put '   What comes along' title
  $n = 0
  foreach ($it in $items) {
    $n++
    if ($it.key -eq 'projects') { $it.on = [bool]@($plist | Where-Object { $_.mode -ne 'none' }).Count; $it.detail = (Get-ProjectsLine $plist) + "  (type $n to pick)" }
    Write-Item $n $it $(if ($it.key -eq 'sidebar' -and $state.open) { 'needs Claude closed (press C)' })
  }
  Gap
  if ($state.open) { Put "   Claude is open. That's fine: everything except the sidebar layout can go now." plain; Put '    C  close Claude first, to bring the sidebar layout too' dim }
  else { Put '   [x] Claude is closed, so everything can come along.' ok }
  Gap
  Put '   How it gets to the new laptop' title
  Put ('    S  ' + $(if ($state.how -eq 'send') { '(o)' } else { '( )' }) + ' send it over the internet with a one-time code') $(if ($state.how -eq 'send') { 'plain' } else { 'dim' })
  Put "          both laptops on; croc's free relay allows 5 sends an hour per internet connection" dim
  Put ('    U  ' + $(if ($state.how -eq 'usb') { '(o)' } else { '( )' }) + ' carry it on a pendrive or USB stick') $(if ($state.how -eq 'usb') { 'plain' } else { 'dim' })
  if ($state.msg) { Gap; Put "   $($state.msg)" warn; $state.msg = '' }
  Gap
  Put '   Type a number or letter and press Enter to change something. Just Enter starts, Q quits.' dim
}

function Invoke-Pack {
  $script:doing = 'packing up this laptop'; $script:steps = $null
  Show-Top 'Looking around...'
  $c = Join-Path $HomeDir '.claude'
  $metas = @(Get-ChildItem -LiteralPath "$claudeDir\claude-code-sessions" -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue)
  $transcripts = 0; $memories = 0
  foreach ($d in Get-ChildItem -LiteralPath "$c\projects" -Directory -ErrorAction SilentlyContinue) {
    $transcripts += @(Get-ChildItem -LiteralPath $d.FullName -File -Filter *.jsonl -ErrorAction SilentlyContinue).Count
    if (Test-Path -LiteralPath "$($d.FullName)\memory") { $memories++ }
  }
  $plist = @(Get-Projects)
  if ($Projects) { Set-ProjectModes $plist $Projects }
  $parts = Get-PartDetails $HomeDir
  $state = @{ open = (Test-ClaudeOpen); how = $(if ($Transfer -ne 'ask') { $Transfer } elseif ($interactive -and -not $Test) { 'send' } else { 'usb' }); msg = '' }
  $items = @([ordered]@{ key = 'chats'; on = $true; detail = "$(Plural $metas.Count 'session'), $(Plural $transcripts 'chat')" })
  if ($memories) { $items += [ordered]@{ key = 'memory'; on = $true; detail = "notes Claude keeps, in $(Plural $memories 'project')" } }
  foreach ($k in 'instructions', 'settings', 'hooks', 'skills', 'plugins') { if ($parts.ContainsKey($k)) { $items += [ordered]@{ key = $k; on = $true; detail = $parts[$k] } } }
  $items += [ordered]@{ key = 'sidebar'; on = $true; detail = 'how your sidebar is organised' }
  if ($plist.Count) { $items += [ordered]@{ key = 'projects'; on = $true; detail = '' } }
  if ($What.Count) {
    foreach ($it in $items) { $it.on = $What -contains $it.key }
    if ($What -notcontains 'projects') { foreach ($p in $plist) { $p.mode = 'none' } }
  }
  if ($Plan) {   # what could come along, for the Claude skill to talk through; nothing is packed
    Write-Result ([ordered]@{ ok = $true; plan = $true; claudeOpen = $state.open
        what = @($items | ForEach-Object { [ordered]@{ key = $_.key; on = [bool]$_.on; detail = $_.detail } })
        projects = @($plist | ForEach-Object { [ordered]@{ name = $_.name; path = $_.path; kind = $_.kind; mode = $_.mode; modes = $_.modes; localFiles = $_.count
              size = $_.size; overLimit = $_.big; sample = $_.sample; claudeFiles = @($_.claude); commitsNotOnGitHub = $_.ahead } })
        warnings = @($warnings) })
    return
  }

  while ($interactive) {
    $state.open = Test-ClaudeOpen   # the user may quit Claude themselves
    Show-PackMenu $items $state $plist
    $a = Read-Choice
    if ($a -eq '') { break }
    if ($a -eq 'Q') { Put '   Nothing was changed.' dim; End-Wait; return }
    if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $items.Count) {
      $it = $items[[int]$a - 1]
      if ($it.key -eq 'projects') { Edit-Projects $plist 'Show-ProjectsOut' }
      elseif ($it.key -eq 'sidebar' -and $state.open) { $state.msg = 'Close Claude first (C) to bring the sidebar layout.' }
      else { $it.on = -not $it.on }
    }
    elseif ($a -eq 'C' -and $state.open) { if (Stop-Claude) { $state.open = $false } else { $state.msg = "Claude didn't close. Quit it from its icon near the clock, then press C again." } }
    elseif ($a -eq 'S') { $state.how = 'send' }
    elseif ($a -eq 'U') { $state.how = 'usb' }
    else { $state.msg = "I didn't get that one." }
  }
  $want = @{}; foreach ($it in $items) { $want[$it.key] = [bool]$it.on }
  $want.projects = [bool]@($plist | Where-Object { $_.mode -ne 'none' }).Count -and $want.projects
  $state.open = Test-ClaudeOpen
  if ($state.open) { $want.sidebar = $false }   # its database is locked while Claude runs
  if (-not ($want.Values -contains $true)) { throw 'Nothing was ticked, so there is nothing to pack.' }

  $script:steps = @('Copy your Claude stuff', 'Zip it up', 'Make your transfer folder')
  if ($state.how -eq 'send') { $script:steps += 'Send it to the new laptop' }
  Set-Step 1
  $work = New-WorkDir; $script:work = $work
  Copy-Selected $want $work $plist
  $took = @($items | Where-Object { $want[$_.key] } | ForEach-Object { Get-Lower $_.key })
  Put ('   [x] Copied: ' + ($took -join ', ') + '.') ok
  if ($state.open -and ($items | Where-Object { $_.key -eq 'sidebar' -and $_.on })) { Put '   (Claude is open, so the sidebar layout stays behind. Close Claude and pack again if you want it.)' dim }

  Set-Step 2
  $dest = Join-Path $(if ($OutDir) { $OutDir } else { $DesktopDir }) "Claude Moove $stamp"
  New-Item -ItemType Directory -Force (Join-Path $dest 'engine') | Out-Null
  $zip = Join-Path $dest 'engine\claude-data.zip'
  $p = Start-Tool tar ('-a -c -f ' + (Q $zip) + ' -C ' + (Q $work) + ' .')
  Wait-Walking $p { if (Test-Path -LiteralPath $zip) { 'Zipping...  ' + [int]((Get-Item -LiteralPath $zip).Length / 1MB) + ' MB so far' } else { 'Zipping...' } }
  if ($p.ExitCode -ne 0) { throw "Zipping failed (tar code $($p.ExitCode)). Is the Desktop's drive full?" }
  $mb = [int]((Get-Item -LiteralPath $zip).Length / 1MB)
  Put "   [x] Zipped: $mb MB." ok

  Set-Step 3
  # The buttons travel too: on a pendrive they're plain local files, so Windows doesn't flag them on the new laptop.
  Get-ChildItem -LiteralPath $toolRoot -Filter '*.cmd' | Copy-Item -Destination $dest
  Copy-One (Join-Path $toolRoot 'LICENSE') $dest
  foreach ($f in 'claude-moove.ps1', 'claude-moove-merge.mjs', 'README.md') { Copy-Item -LiteralPath (Join-Path $engine $f) (Join-Path $dest "engine\$f") }
  $going = @(if ($want.projects) { $plist | Where-Object { $_.mode -ne 'none' } })
  $manifest = [ordered]@{
    tool = 'Claude Moove'; version = 3; created = (Get-Date).ToString('o'); computer = $env:COMPUTERNAME
    home = $HomeDir; appData = $AppDataDir; desktop = $DesktopDir; documents = $DocumentsDir
    accounts = @(Get-ChildItem -LiteralPath "$claudeDir\claude-code-sessions" -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
    sessions = $metas.Count; transcripts = $transcripts; what = @($items | Where-Object { $want[$_.key] } | ForEach-Object { $_.key })
    projects = @($going | ForEach-Object {
        [ordered]@{ name = $_.name; path = $_.path; kind = $_.kind; mode = $_.mode; remote = $_.remote; branch = $_.branch; head = $_.head; slot = $_.slot
          count = $(if ($_.mode -eq 'all') { $_.count } elseif ($_.mode -eq 'claude') { $_.claude.Count } else { 0 }); size = $(if ($_.mode -eq 'all') { $_.size } else { 0 })
          bundle = $_.bundle; ahead = $_.ahead; deleted = @(if ($_.mode -eq 'all') { $_.deleted }); claudeFiles = @($_.claude) } })
  }
  [IO.File]::WriteAllText((Join-Path $dest 'engine\manifest.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
  Update-Marker @{ lastPack = (Get-Date).ToString('o') }
  Remove-Tree $work; $script:work = $null
  Put '   [x] Transfer folder ready.' ok

  $sent = $false
  if ($state.how -eq 'send') {
    Set-Step 4
    $sent = Send-Folder $dest
    if ($sent) { Put '   [x] Sent! The new laptop has everything.' ok }
  }

  $done = @($(if ($want.chats) { "[x] All packed: $(Plural $metas.Count 'session'), $(Plural $transcripts 'chat file'), $mb MB." } else { "[x] All packed: $($took -join ', '), $mb MB." }))
  if ($going.Count) { $done += "[x] Projects: $(($going | ForEach-Object { $_.name + ' (' + (Get-ModeText $_) + ')' }) -join ', ')." }
  $done += ''
  if ($sent) {
    $done += '[x] Sent to the new laptop. It carries on there by itself.', '',
      "A copy stays on your Desktop as  Claude Moove $stamp  in case you need it again.",
      'Delete it once the new laptop is all set: it holds your full chat history.'
  } else {
    $done += 'Your transfer folder is on your Desktop:', "      Claude Moove $stamp", '', 'WHAT NOW',
      ' 1. Copy that whole folder to a USB stick (or a cloud drive).',
      " 2. On the new laptop, open the folder and double-click  2 - UNPACK (on the laptop you're moving to)",
      '    or open PowerShell, paste this line and choose  2  (it finds the folder by itself):',
      "      $oneLiner", '',
      'Keep that folder private: it holds your full chat history' + $(if ($going.Count) { ' and your projects'' local files.' } else { '.' })
  }
  foreach ($w in $warnings) { $done += "[!] $w" }
  Show-Big -Bloom $done
  $skipped = @($items | Where-Object { $_.on -and -not $want[$_.key] } | ForEach-Object { $_.key })   # the sidebar, when Claude was open
  Write-Result ([ordered]@{ ok = $true; folder = $dest; mb = $mb; sessions = $metas.Count; chats = $transcripts; what = $manifest.what; skipped = $skipped
      projects = @($going | ForEach-Object { [ordered]@{ name = $_.name; mode = $_.mode; files = $(if ($_.mode -eq 'all') { $_.count } else { 0 }); size = $(if ($_.mode -eq 'all') { $_.size } else { 0 }); commits = $(if ($_.bundle) { $_.ahead } else { 0 }) } })
      sent = $sent; warnings = @($warnings) })
  if ($interactive -and -not $Test -and -not $sent) { Start-Process explorer.exe "/select,`"$dest`"" }
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
    @("$sa\claude-code-sessions", $true), @("$sa\local-agent-mode-sessions", $true), @((Join-Path (Split-Path $sh) 'projects'), $true))
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
    $I = Read-Json $f.FullName; $L = $null; try { $L = Read-Json $t } catch {}   # Move-Chats already left out the old laptop's damaged ones
    if (-not $L) { $f.LastWriteTimeUtc = [DateTime]::UtcNow; $script:count.updated++; continue }   # this laptop's is damaged: the old laptop's replaces it
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
    $all = @(@(foreach ($p in $f.FullName, $t) { try { (Read-Json $p).archived } catch {} }) | Where-Object { $_ } | Sort-Object -Unique)   # a damaged list counts as empty
    [IO.File]::WriteAllText($f.FullName, ([ordered]@{ v = 1; archived = $all } | ConvertTo-Json -Compress), $utf8)
    $f.LastWriteTimeUtc = [DateTime]::UtcNow
  }
}

# ---------------------------------------------------------------- UNPACK (laptop you're moving to)
$liveNames = '.claude.json', 'claude_desktop_config.json'   # Claude keeps rewriting these while it runs, so they wait until it's closed

function Get-AccountState($mf) {   # same, different, none (not signed in) or noapp (the app isn't installed or never opened)
  $cfg = Join-Path $claudeDir 'config.json'
  if (-not (Test-Path -LiteralPath $cfg)) { return 'noapp' }
  $acct = (Read-Json $cfg).lastKnownAccountUuid
  if (-not $acct) { 'none' } elseif ((@($mf.accounts) -contains $acct) -or -not @($mf.accounts).Count) { 'same' } else { 'different' }
}
function Read-Marker {   # files settled in earlier moves, so the same difference isn't asked about twice
  $r = @{}
  try { $m = Read-Json $marker; if ($m.resolved) { foreach ($p in $m.resolved.PSObject.Properties) { $r[$p.Name] = $p.Value } } } catch {}
  $r
}
function Update-Marker([hashtable]$set) {   # notes that this laptop packed or moved in, keeping what's already noted
  $all = [ordered]@{}
  try { foreach ($p in (Read-Json $marker).PSObject.Properties) { $all[$p.Name] = $p.Value } } catch {}
  foreach ($k in $set.Keys) { $all[$k] = $set[$k] }
  New-Item -ItemType Directory -Force $claudeDir | Out-Null
  [IO.File]::WriteAllText($marker, ($all | ConvertTo-Json -Depth 5), $utf8)
}
function Get-PlaceText([string]$path) {   # where a found folder is, in a few words
  foreach ($pl in @(@($DesktopDir, 'on your Desktop'), @((Join-Path $HomeDir 'Downloads'), 'in your Downloads'), @($DocumentsDir, 'in your Documents'))) {
    if ($pl[0] -and $path.StartsWith($pl[0].TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $pl[1] }
  }
  "on drive $($path.Substring(0, 2)) (a USB stick, say)"
}
function Show-Found([string]$folder, [string]$computer, [string]$packed, [int]$count) {
  Put "   I found a packed Claude Moove folder $(Get-PlaceText $folder)." plain
  if ($computer) { Put "   From $computer, packed $packed." plain }
  Put "   $folder" dim
  if ($count -gt 1) { Put "   It's the newest of the $count I found." dim }
  Gap
  Put '   Enter  use it' plain
  Put '   R      receive one over the internet with a code instead' plain
  Put '   Q      quit; nothing changes' plain
}
function Confirm-Found([string]$folder, [int]$count) {   # a packed folder that's already here: use it, receive one instead, or quit
  $computer = ''; $packed = ''
  try { $mf = Read-Json (Join-Path $folder 'engine\manifest.json'); $computer = [string]$mf.computer; $packed = ([datetime]$mf.created).ToString('yyyy-MM-dd HH:mm') } catch {}
  Show-Found $folder $computer $packed $count
  while ($true) {
    $a = Read-Answer 'Your choice:'
    if ($a -eq '') { return 'use' }
    if ($a -eq 'R') { return 'receive' }
    if ($a -eq 'Q') { return 'quit' }
    Put "   I didn't get that one." warn
  }
}
function Find-Source {   # the transfer folder: -From, next to this engine, on this PC or a drive (asked first), or received with a code
  if ($From) {
    $f = [IO.Path]::GetFullPath($From).TrimEnd('\')
    foreach ($d in $f, (Split-Path $f)) { if ($d -and (Test-Path -LiteralPath (Join-Path $d 'engine\claude-data.zip'))) { return $d } }
    throw "There's no packed Claude data in $From."
  }
  if ((Test-Path -LiteralPath (Join-Path $engine 'claude-data.zip')) -and (Test-Path -LiteralPath (Join-Path $engine 'manifest.json'))) { return $toolRoot }
  if (-not $ReceiveCode) {
    $cand = @(Find-PackedFolders)
    if ($cand.Count) {   # one already here: with someone at the keyboard, ask before using it
      $how = if ($interactive) { Confirm-Found $cand[0].FullName $cand.Count } else { 'use' }
      if ($how -eq 'use') { return $cand[0].FullName }
      if ($how -eq 'quit') { return $null }
      return Receive-Folder
    }
  }
  if (-not $interactive -and -not $ReceiveCode) { throw "Couldn't find a packed folder on this PC or a plugged-in drive. Name one with -From, or receive one with -ReceiveCode." }
  Put "   I couldn't find a packed folder on this PC or a plugged-in drive." plain
  Receive-Folder
}

# Files people care about (global CLAUDE.md, AGENTS.md, settings.json, and the files of projects already here) are compared one by one.
# When both laptops changed one, nothing is overwritten blindly: keep this PC's, take the old laptop's, or keep both.
function Test-ClaudeFile([string]$rel) { ($rootFiles -contains $rel) -or ($rel -like '.claude\*') }
function New-FileItem([string]$in, [string]$dest, [string]$label, [string]$cat, $proj, [string]$rel) {
  # "keep both" leaves the other copy next to it, so only where a spare copy does nothing: instructions, docs, .json and .env files,
  # but not inside folders where Claude would pick it up as an extra command, agent, skill or rule
  $leaf = Split-Path $dest -Leaf
  $active = $rel -match '^\.claude\\(commands|agents|skills|rules|output-styles)\\'
  $bothOk = ($cat -ne 'projects') -or (-not $active -and (($leaf -match '\.(md|json)$') -or ($leaf -like '.env*')))
  # origin is the old laptop's file as packed; incoming is what would be used, which for settings.json is assembled per part
  # combined is set for settings.json: both laptops' settings in one file
  [pscustomobject]@{ id = $dest; label = $label; incoming = $in; origin = $in; combined = $null; dest = $dest; cat = $cat; project = $proj; rel = $rel; bothOk = $bothOk
    group = $null; fixed = $false; state = ''; hash = ''; key = ''; newer = ''; default = ''; choice = '' }
}
function Get-Options($f) {   # a file's choices, in the order its number cycles through them
  if ($f.combined) { return @('combine', 'theirs', 'mine') + @(if ($f.bothOk) { 'both' }) }
  @(if ($f.bothOk) { 'both' }) + @('mine', 'theirs')
}
function Test-Pristine($f) {   # this PC's copy of a project file is just what's committed to git
  if (-not $script:hasGit) { return $false }
  $r = $f.rel.Replace('\', '/')
  [bool](Invoke-Git $f.project.path ls-files $r) -and -not (Invoke-Git $f.project.path status --porcelain $r)
}
function Update-FileState($f) {   # copy (not here yet), same, settled (in an earlier move) or conflict (changed on both laptops)
  $f.state = 'copy'
  if (-not (Test-Path -LiteralPath $f.dest)) { return }
  $f.hash = (Get-FileHash -LiteralPath $f.incoming).Hash
  $f.key = if ($f.origin -ne $f.incoming) { (Get-FileHash -LiteralPath $f.origin).Hash } else { $f.hash }   # remembered once settled
  $here = (Get-FileHash -LiteralPath $f.dest).Hash
  if ($here -eq $f.hash -or ($f.combined -and $here -eq (Get-FileHash -LiteralPath $f.combined).Hash)) { $f.state = 'same'; return }
  if ($script:resolved[$f.dest] -eq $f.key) { $f.state = 'settled'; return }
  $f.state = 'conflict'
  $f.newer = if ((Get-Item -LiteralPath $f.incoming -Force).LastWriteTimeUtc -gt (Get-Item -LiteralPath $f.dest -Force).LastWriteTimeUtc) { 'theirs' } else { 'mine' }
  # settings.json is combined: the old laptop's settings win, and what only this PC has stays.
  # A brand-new install's instructions, or a project file that's just what GitHub has, give way (a project set up here is deliberate).
  # Instructions are kept both; the rest goes newer-wins.
  if ($f.combined) { $f.default = 'combine' }
  elseif (($script:firstMoove -and -not $f.project) -or ($f.project -and (Test-Pristine $f))) { $f.default = 'theirs' }
  elseif ($f.bothOk -and $f.dest.EndsWith('.md')) { $f.default = 'both' }
  else { $f.default = $f.newer }
  if (-not $f.choice -or ($f.choice -eq 'combine' -and -not $f.combined)) { $f.choice = $f.default }
}
function Build-SettingsJson($P, $want) {   # settings.json from both laptops: each part (hooks, plugins, the rest) from where it's wanted
  # Two versions: theirs (the old laptop's, as ticked) and combined (the old laptop's settings win, whatever only this PC has stays)
  $in = "$($P.sh)\.claude\settings.json"; $lo = "$HomeDir\.claude\settings.json"
  if (-not (Test-Path -LiteralPath $in)) { return $null }
  $old = @{ rest = ($want.settings -and $P.packed -contains 'settings') }
  foreach ($k in $partKeys.Keys) { $old[$k] = [bool]$want[$k] }
  $whole = $old.rest -and -not @($partKeys.Keys | Where-Object { -not $old[$_] }).Count   # all of it from the old laptop
  if (-not $old.rest -and -not @($partKeys.Keys | Where-Object { $old[$_] }).Count) { return $null }   # none of it
  try { $fromOld = Read-JsonMap $in } catch {
    if ($whole) { return [pscustomobject]@{ theirs = $in; combined = $null } }
    $warnings.Add("The old laptop's settings.json couldn't be read, so it stayed behind."); return $null
  }
  $fromHere = New-JsonMap
  if (Test-Path -LiteralPath $lo) {
    try { $fromHere = Read-JsonMap $lo } catch {   # a comment or a stray comma, say: this PC's is kept or replaced whole, never combined or added to
      $msg = "This PC's settings.json couldn't be read (a comment or a stray comma, maybe), so it wasn't combined with the old laptop's."
      if (-not $warnings.Contains($msg)) { $warnings.Add($msg) }
      if ($whole) { return [pscustomobject]@{ theirs = $in; combined = $null } }
      return $null
    }
  }
  $base = if ($old.rest) { $fromOld } else { $fromHere }
  $theirs = New-JsonMap; foreach ($k in $base.Keys) { $theirs[$k] = $base[$k] }
  $combined = Merge-Json $fromHere $(if ($old.rest) { $fromOld } else { New-JsonMap })
  foreach ($k in $partKeys.Keys) {
    foreach ($key in $partKeys[$k]) {
      $o = $old[$k] -and $fromOld.ContainsKey($key); $h = $fromHere.ContainsKey($key)
      [void]$theirs.Remove($key); [void]$combined.Remove($key)
      $src = if ($old[$k]) { $fromOld } else { $fromHere }
      if ($src.ContainsKey($key)) { $theirs[$key] = $src[$key] }
      # combined: the old laptop's hooks come as a whole set; plugin switches and marketplaces one by one, so one switched on only here stays on
      if (-not $o) { if ($h) { $combined[$key] = $fromHere[$key] } }
      elseif ($k -eq 'hooks' -or -not $h) { $combined[$key] = $fromOld[$key] }
      else { $combined[$key] = Merge-Json $fromHere[$key] $fromOld[$key] }
    }
  }
  $r = [ordered]@{}
  foreach ($name in 'theirs', 'combined') {
    $out = "$($P.work)\settings.$name.json"
    [IO.File]::WriteAllText($out, (Write-JsonText $(if ($name -eq 'theirs') { $theirs } else { $combined })) + "`n", $utf8)
    (Get-Item -LiteralPath $out).LastWriteTimeUtc = (Get-Item -LiteralPath $in).LastWriteTimeUtc
    $r[$name] = $out
  }
  if ($whole) { $r.theirs = $in }   # the old laptop's file as it is
  [pscustomobject]$r
}

function Get-UnpackPlan([string]$src) {   # unpacks the data next to this PC's, then works out what can come in and what differs
  Remove-Tree $script:work
  $mf = Read-Json (Join-Path $src 'engine\manifest.json')
  $work = New-WorkDir; $script:work = $work
  $tar = Start-Tool tar ('-x -f ' + (Q (Join-Path $src 'engine\claude-data.zip')) + ' -C ' + (Q $work))
  Wait-Walking $tar { 'Unpacking...' }
  if ($tar.ExitCode -ne 0) { throw "Couldn't unpack claude-data.zip (tar code $($tar.ExitCode)). It may be damaged: copy the folder over again." }
  $sh = Join-Path $work 'home'; $sa = Join-Path $work 'appdata\Claude'; $c = "$sh\.claude"
  $pairs = @(Set-PathMap $mf)
  if ($pairs.Count) { Convert-StageFiles $sh $sa }
  # A PC with chats of its own is only ever merged into. One chat doesn't count: it may be the one running the Claude Moove skill.
  $chatsHere = @(Get-ChildItem -LiteralPath "$HomeDir\.claude\projects" -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter *.jsonl -ErrorAction SilentlyContinue } | Select-Object -First 2).Count
  $sessionsHere = @(Get-ChildItem -LiteralPath "$claudeDir\claude-code-sessions" -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue | Select-Object -First 2).Count
  $livedIn = ($chatsHere -gt 1) -or ($sessionsHere -gt 1)
  $mk = $null; try { $mk = Read-Json $marker } catch {}
  # A brand-new install takes everything as it was, also in a second run that brings in what waited for Claude to close.
  $script:firstMoove = -not $livedIn -and (-not $mk -or $mk.freshInstall)
  $script:resolved = Read-Marker
  $script:hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
  $packed = if ($mf.what) { @($mf.what) } else { @('chats', 'settings', 'memory', 'sidebar') }   # packs from 1.0 hold all but projects
  if ([int]$mf.version -lt 3 -and $packed -contains 'settings') { $packed += 'instructions', 'hooks', 'skills', 'plugins' }   # before 1.2, settings held all of these

  $plist = @(foreach ($pr in @($mf.projects)) {
      if (-not $pr) { continue }
      $path = Convert-Text $pr.path
      $kind = if ($pr.kind) { $pr.kind } elseif ($pr.remote) { 'git' } else { 'local' }
      $packedMode = if ($pr.mode) { $pr.mode } else { 'claude' }   # packs before 1.2 hold only Claude files
      $stage = if ($pr.slot) { Join-Path $work "projects\$($pr.slot)" } else { '' }
      $hasFiles = [bool]$stage -and (Test-Path -LiteralPath $stage)
      $bundle = if ($pr.slot -and (Test-Path -LiteralPath (Join-Path $work "projects\$($pr.slot).bundle"))) { Join-Path $work "projects\$($pr.slot).bundle" } else { $null }
      $here = Test-Path -LiteralPath $path
      $count = 0; $size = [long]0
      if ($hasFiles) { $m = Measure-Files $stage @('') @() @() ([long]::MaxValue); $count = $m.count; $size = $m.size }
      if ($here) { $modes = @('all', 'none') }
      elseif ($kind -eq 'git' -and $hasFiles) { $modes = @('all', 'github', 'none') }
      elseif ($kind -eq 'git') { $modes = @('all', 'none') }
      elseif ($kind -eq 'local' -and $packedMode -eq 'all') { $modes = @('all', 'none') }
      else { $modes = @('none') }   # only its Claude files came, and the folder isn't here yet
      [pscustomobject]@{ name = (Split-Path $path -Leaf); path = $path; kind = $kind; remote = $pr.remote; branch = $pr.branch; head = $pr.head
        packed = $packedMode; stage = $stage; hasFiles = $hasFiles; bundle = $bundle; ahead = [int]$pr.ahead; deleted = @($pr.deleted | Where-Object { $_ })
        here = $here; modes = $modes; mode = $modes[0]; count = $count; size = $size }
    })
  if ($What.Count -and $What -notcontains 'projects') { foreach ($pr in $plist) { $pr.mode = 'none' } }
  if ($Projects) { Set-ProjectModes $plist $Projects }

  # what's in the package, kind by kind
  $memDirs = @(Get-ChildItem -LiteralPath "$c\projects" -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'memory') })
  $sj = $null; try { $sj = Read-Json "$c\settings.json" } catch {}
  $parts = Get-PartDetails $sh
  $lsHere = Test-Path -LiteralPath "$claudeDir\Local Storage"
  $has = [ordered]@{
    chats = $packed -contains 'chats'; memory = [bool]$memDirs.Count
    instructions = ($packed -contains 'instructions') -and $parts.ContainsKey('instructions')
    settings = $packed -contains 'settings'
    hooks = ($packed -contains 'hooks') -and ((Test-Path -LiteralPath "$c\hooks") -or ($sj -and $sj.PSObject.Properties['hooks']))
    skills = ($packed -contains 'skills') -and $parts.ContainsKey('skills')
    plugins = ($packed -contains 'plugins') -and ((Test-Path -LiteralPath "$c\plugins") -or ($sj -and ($sj.PSObject.Properties['enabledPlugins'] -or $sj.PSObject.Properties['extraKnownMarketplaces'])))
    sidebar = Test-Path -LiteralPath "$sa\Local Storage"; projects = [bool]$plist.Count }
  $items = @()
  foreach ($k in $has.Keys) {
    if (-not $has[$k]) { continue }
    $detail = switch ($k) {
      'chats' { "$(Plural $mf.sessions 'session'), $(Plural $mf.transcripts 'chat')" }
      'memory' { "notes Claude keeps, in $(Plural $memDirs.Count 'project')" }
      'sidebar' { '' }
      'projects' { '' }
      default { $(if ($parts.ContainsKey($k)) { $parts[$k] } else { '' }) }
    }
    $items += [ordered]@{ key = $k; on = $(if ($k -eq 'sidebar') { $script:firstMoove -or -not $lsHere } else { $true }); detail = $detail }
  }
  if ($What.Count) { foreach ($it in $items) { if ($it.key -ne 'projects') { $it.on = $What -contains $it.key } } }
  $want = @{}; foreach ($it in $items) { $want[$it.key] = [bool]$it.on }
  $P = @{ src = $src; mf = $mf; work = $work; sh = $sh; sa = $sa; packed = $packed }

  $files = New-Object System.Collections.Generic.List[object]
  if ($has.instructions) {
    foreach ($g in @(@('.claude\CLAUDE.md', 'CLAUDE.md (global)'), @('AGENTS.md', 'AGENTS.md (user folder)'))) {
      $in = Join-Path $sh $g[0]
      if (Test-Path -LiteralPath $in) { $files.Add((New-FileItem $in (Join-Path $HomeDir $g[0]) $g[1] 'instructions' $null $g[0])) }
    }
  }
  if ($has.settings) {
    $in = Build-SettingsJson $P $(if ($want.settings) { $want } else { @{ settings = $true; hooks = $want.hooks; plugins = $want.plugins } })
    if ($in) {
      $item = New-FileItem $in.theirs (Join-Path $HomeDir '.claude\settings.json') 'settings.json (global)' 'settings' $null '.claude\settings.json'
      $item.origin = "$c\settings.json"; $item.combined = $in.combined; $files.Add($item)
    }
  }
  foreach ($pr in $plist) {   # a project that's already here: its files are compared one by one
    if (-not $pr.here -or -not $pr.hasFiles) { continue }
    foreach ($fi in Get-ChildItem -LiteralPath $pr.stage -Recurse -File -Force -ErrorAction SilentlyContinue) {
      $rel = $fi.FullName.Substring($pr.stage.Length + 1)
      $item = New-FileItem $fi.FullName (Join-Path $pr.path $rel) "$($pr.name)\$rel" 'projects' $pr $rel
      if (-not (Test-ClaudeFile $rel)) { $item.group = $pr.path }   # everything but Claude's files is settled per project
      $files.Add($item)
    }
  }
  foreach ($f in $files) { Update-FileState $f }
  $groups = [ordered]@{}
  foreach ($f in $files) {
    if (-not $f.group -or $f.state -ne 'conflict') { continue }
    if (-not $groups.Contains($f.group)) { $groups[$f.group] = [pscustomobject]@{ path = $f.group; project = $f.project; files = New-Object System.Collections.Generic.List[object]; choice = 'mine'; label = '' } }
    $groups[$f.group].files.Add($f)
  }
  foreach ($g in $groups.Values) {   # this PC's copies win, unless they're all just what git has (a project freshly downloaded here)
    $g.choice = if (@($g.files | Where-Object { $_.default -ne 'theirs' }).Count) { 'mine' } else { 'theirs' }
    $g.label = "$($g.project.name): $(Plural $g.files.Count 'other file')"
  }
  if ($Choices) {   # decided ahead of time (the Claude skill): mine, theirs, both, or the path of a merged file; <project>\* for a project's other files
    $picked = @{}
    foreach ($prop in (Read-Json $Choices).PSObject.Properties) { $picked[$prop.Name.Replace('/', '\')] = [string]$prop.Value }
    foreach ($g in $groups.Values) { $v = $picked["$($g.path)\*"]; if ($v -eq 'mine' -or $v -eq 'theirs') { $g.choice = $v.ToLower() } }
    foreach ($f in $files) {
      $v = $picked[$f.id]
      if (-not $v) { continue }
      if ($v -in (Get-Options $f)) { $f.choice = $v.ToLower(); $f.fixed = $true }
      elseif (Test-Path -LiteralPath $v -PathType Leaf) { $f.choice = [IO.Path]::GetFullPath($v); $f.fixed = $true }
      else { $warnings.Add("Ignored the choice for $($f.label): '$v' isn't $((Get-Options $f) -join ', ') or a file.") }
    }
  }
  $P.pairs = $pairs; $P.livedIn = $livedIn; $P.projects = $plist; $P.files = $files; $P.groups = $groups; $P.items = $items; $P.lsHere = $lsHere
  $P.canReceive = $false; $P.installed = Test-Path -LiteralPath (Join-Path $claudeDir 'config.json'); $P.account = Get-AccountState $mf
  $P.open = Test-ClaudeOpen; $P.node = [bool](Get-Command node -ErrorAction SilentlyContinue)
  $P
}
function Get-ShownConflicts($P) {   # files changed on both laptops, one by one, in the kinds of data that are ticked
  $on = @($P.items | Where-Object { $_.on } | ForEach-Object { $_.key })
  @($P.files | Where-Object { $_.state -eq 'conflict' -and -not $_.group -and $on -contains $_.cat -and (-not $_.project -or $_.project.mode -ne 'none') })
}
function Get-ShownGroups($P) {   # per project: the other files that differ, settled with one choice
  if (-not @($P.items | Where-Object { $_.key -eq 'projects' -and $_.on }).Count) { return @() }
  @($P.groups.Values | Where-Object { $_.project.mode -ne 'none' })
}
function Get-ChoiceText([string]$c) {
  switch ($c) { 'combine' { 'combine, old laptop wins' } 'both' { 'keep both, Claude merges them' } 'mine' { "keep this PC's" } 'theirs' { "take the old laptop's" } default { 'use the merged version' } }
}
function Get-ProjectsInLine($plist) {   # the projects line on the move-in screen
  $going = @($plist | Where-Object { $_.mode -ne 'none' })
  $down = @($going | Where-Object { -not $_.here -and $_.kind -eq 'git' }).Count; $copy = @($going | Where-Object { -not $_.here -and $_.kind -ne 'git' }).Count; $here = @($going | Where-Object { $_.here }).Count
  $bits = @(if ($down) { "$down from GitHub" }; if ($copy) { "$copy copied" }; if ($here) { "$here already here" })
  "$($going.Count) of $($plist.Count)" + $(if ($bits.Count) { ': ' + ($bits -join ', ') }) 
}
function Show-ProjectsIn($plist, $state) {   # move-in: what happens to each project
  Show-Top 'Pick your projects. Just Enter goes back.'
  Put '       Project              What happens' title
  $n = 0
  foreach ($p in $plist) {
    $n++; $on = $p.mode -ne 'none'
    $what = if (-not $on) { 'left out' } elseif ($p.here) { 'already here: add its files' } elseif ($p.kind -eq 'git') { if ($p.mode -eq 'all' -and $p.hasFiles) { 'download + local files' } else { 'download from GitHub' } } else { 'copy the whole folder' }
    $detail = if ($p.modes.Count -eq 1) { "only its Claude files came; copy the folder from your old laptop to $($p.path) first" }
      elseif ($p.here) { "$(Plural $p.count 'file') from the old laptop" + $(if ($p.bundle) { ", $(Plural $p.ahead 'unpushed commit')" }) }
      elseif ($p.kind -eq 'git') { $(if ($p.mode -eq 'all' -and $p.count) { "$(Format-Size $p.size), $(Plural $p.count 'local file'); " }) + $(if ($p.bundle) { "$(Plural $p.ahead 'unpushed commit'); " }) + "to $($p.path)" }
      else { "$(Format-Size $p.size), to $($p.path)" }
    Put ('   {0,2}  {1,-20} ' -f $n, $p.name) $(if ($on) { 'plain' } else { 'dim' }) -n
    Put ('{0,-28} ' -f $what) $(if ($on) { 'pink' } else { 'dim' }) -n
    Put $detail dim
  }
  Gap
  Put "   GitHub projects download again, with the old laptop's local files and unpushed commits on top." dim
  Put '   A project that''s already here keeps its own copy of anything that differs, unless you choose otherwise.' dim
  if (-not $script:hasGit -and @($plist | Where-Object { $_.mode -ne 'none' -and -not $_.here -and $_.kind -eq 'git' }).Count) { Put "   [ ] Git is missing, so projects can't be downloaded. Press G on the main screen to install it." warn }
  if ($state.msg) { Gap; Put "   $($state.msg)" warn; $state.msg = '' }
  Gap
  Put '   Type a number to switch. A brings everything, N nothing. Just Enter goes back.' dim
}

function Show-UnpackMenu($P, $state) {
  Show-Top 'Pick what comes in, then press Enter.'
  $mf = $P.mf
  Put ("   From $($mf.computer), packed " + ([datetime]$mf.created).ToString('yyyy-MM-dd HH:mm') + ':  ') plain -n; Put $P.src dim
  if ($P.livedIn) { Put '   This PC already has its own Claude chats. They stay; yours are merged in next to them.' plain }
  switch ($P.account) {
    'same' { Put '   [x] Signed in to the same account.' ok }
    'different' { Put "   [!] Claude is signed in to a different account than on $($mf.computer); your sessions only show up in that one." warn; Put '       Switch accounts in Claude, then press A. Or just carry on.' dim }
    'none' { Put "   [!] You're not signed in to Claude yet. Sign in with the same account, then press A." warn }
    'noapp' { Put "   [!] Claude isn't installed here yet (or hasn't been opened once).   D  open the download page" warn }
  }
  if ($P.pairs.Count) { Put '   Your folders have different paths here; I fix them as I go:' plain; foreach ($pair in $P.pairs) { Put ('      ' + $pair[0] + '  ->  ' + $pair[1]) dim } }
  Gap
  Put '   What comes in' title
  $n = 0
  foreach ($it in $P.items) {
    $n++
    if ($it.key -eq 'sidebar') { $it.detail = if (-not $it.on) { 'this PC keeps its own' } elseif ($P.lsHere) { "replaces this PC's (it's saved first)" } else { 'grouping and pins from your old laptop' } }
    if ($it.key -eq 'projects') { $it.on = [bool]@($P.projects | Where-Object { $_.mode -ne 'none' }).Count; $it.detail = (Get-ProjectsInLine $P.projects) + "  (type $n to pick)" }
    Write-Item $n $it ''
  }
  $shown = @(Get-ShownConflicts $P); $groups = @(Get-ShownGroups $P)
  if ($shown.Count -or $groups.Count) {
    Gap
    Put '   Changed on both laptops (type a number to switch)' title
    foreach ($f in $shown) {
      $n++
      Put ('   {0,2}  {1,-31} ' -f $n, $f.label) plain -n
      Put (Get-ChoiceText $f.choice) pink -n
      Put $(if ($f.newer -eq 'theirs') { '   newer on the old laptop' } else { '   newer here' }) dim
    }
    foreach ($g in $groups) {
      $n++
      Put ('   {0,2}  {1,-31} ' -f $n, $g.label) plain -n
      Put (Get-ChoiceText $g.choice) pink -n
      Put ('   ' + (Get-Sample @($g.files | ForEach-Object { $_.rel }))) dim
    }
  }
  Gap
  if ($P.open) { Put '   Claude is open. Projects, settings and memory can come in now;' plain; Put '   chats and the sidebar layout come in the moment you close it.    C  close Claude now' plain }
  else { Put '   [x] Claude is closed, so everything can come in.' ok }
  if (-not $P.node) { Put '   [ ] Node.js is missing: many hooks need it, and so do the merge notes.   N  install it' warn }
  if (-not $script:hasGit -and @($P.projects | Where-Object { $_.mode -ne 'none' -and -not $_.here -and $_.kind -eq 'git' }).Count) { Put "   [ ] Git is missing, so your projects can't come from GitHub.   G  install it" warn }
  if ($P.canReceive) { Put '    R  receive it over the internet instead, with a code' dim }
  if ($state.msg) { Gap; Put "   $($state.msg)" warn; $state.msg = '' }
  Gap
  Put '   Type a number or letter and press Enter to change something. Just Enter starts, Q quits.' dim
}

function Write-Plan($P) {   # -Plan: what would happen, with copies of the other laptop's versions to compare. Changes nothing.
  $review = Join-Path $env:TEMP ('claude-moove-review\' + $stamp.Replace(' ', '-'))
  Remove-Tree $review
  New-Item -ItemType Directory -Force $review | Out-Null
  $i = 0
  $conflicts = @(foreach ($f in $P.files) {
      if ($f.state -ne 'conflict') { continue }
      $i++; $copy = Join-Path $review ('{0:000}-{1}' -f $i, (Split-Path $f.dest -Leaf))
      Copy-Item -LiteralPath $f.incoming $copy -Force
      $both = $null; if ($f.combined) { $both = Join-Path $review ('{0:000}-combined-{1}' -f $i, (Split-Path $f.dest -Leaf)); Copy-Item -LiteralPath $f.combined $both -Force }
      [ordered]@{ id = $f.id; label = $f.label; kind = $f.cat; group = $(if ($f.group) { "$($f.group)\*" } else { $null }); mine = $f.dest; theirs = $copy; combined = $both; newer = $f.newer
        suggested = $(if ($f.group) { $P.groups[$f.group].choice } else { $f.default }); choices = @(Get-Options $f) }
    })
  $wanted = [ordered]@{}; foreach ($it in $P.items) { $wanted[$it.key] = [bool]$it.on }
  Write-Result ([ordered]@{
      ok = $true; plan = $true; folder = $P.src; from = $P.mf.computer; packedAt = $P.mf.created
      livedIn = $P.livedIn; freshInstall = $script:firstMoove; claudeOpen = $P.open; claudeInstalled = $P.installed; account = $P.account
      node = $P.node; git = $script:hasGit; what = $wanted
      paths = @($P.pairs | ForEach-Object { [ordered]@{ old = $_[0]; new = $_[1] } })
      projects = @($P.projects | ForEach-Object { [ordered]@{ name = $_.name; path = $_.path; here = $_.here; kind = $_.kind; mode = $_.mode; modes = $_.modes
            files = $_.count; size = $_.size; commits = $(if ($_.bundle) { $_.ahead } else { 0 }) } })
      conflicts = $conflicts
      groups = @($P.groups.Values | ForEach-Object { [ordered]@{ id = "$($_.path)\*"; label = $_.label; suggested = $_.choice; choices = @('mine', 'theirs') } })
      waitsForClaudeToClose = @(if ($P.open) { @('chats', 'sidebar') | Where-Object { $wanted[$_] } })
      warnings = @($warnings) })
  Remove-Tree $P.work; $script:work = $null
}

# ---------------------------------------------------------------- moving things in
function Save-Safety([string]$dest) {   # a copy of a file before it's replaced, in ~/.claude-moove-safety/<date>
  $keep = Join-Path $script:safety $dest.Substring([IO.Path]::GetPathRoot($dest).Length)
  New-Item -ItemType Directory -Force (Split-Path $keep) | Out-Null
  Copy-Item -LiteralPath $dest $keep -Force
  $script:replaced++
}
function Copy-Newer($f, [string]$dest) {   # one file that can't be combined: the newer copy wins (the packed one on a brand-new install)
  if (Test-Path -LiteralPath $dest) {
    if ((Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $f.FullName).Hash) { return }
    if (-not $script:firstMoove -and (Get-Item -LiteralPath $dest -Force).LastWriteTimeUtc -ge $f.LastWriteTimeUtc) { return }
    Save-Safety $dest
  }
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  Copy-Item -LiteralPath $f.FullName $dest -Force
}
function Merge-SettingsFile($f, [string]$dest) {   # a .json settings file is combined: the old laptop's values win, whatever only this PC has stays
  if ($f.Name -notlike '*.json') { Copy-Newer $f $dest; return }
  $key = (Get-FileHash -LiteralPath $f.FullName).Hash
  if ($script:resolved[$dest] -eq $key) { return }   # combined in an earlier move: what changed here since stays
  $here = Test-Path -LiteralPath $dest
  try { $mine = if ($here) { Read-JsonMap $dest } else { New-JsonMap }; $theirs = Read-JsonMap $f.FullName }
  catch { Copy-Newer $f $dest; return }   # not readable as JSON: as before
  if ($mine.ContainsKey('version') -and $theirs.ContainsKey('version') -and "$($mine['version'])" -cne "$($theirs['version'])") { Copy-Newer $f $dest; return }   # two formats of one file: as before
  $merged = Merge-Json $mine $theirs
  Set-MachineKeys $merged $mine $f.Name
  $text = Write-JsonText $merged
  if (-not $here -or $text -cne [IO.File]::ReadAllText($dest)) {
    if ($here) { Save-Safety $dest } else { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null }
    Write-TextFile $dest $text
  }
  $script:settled[$dest] = $key
}
function Merge-History($f, [string]$dest) {   # the prompt history: both laptops' prompts, each once, in time order
  if (-not (Test-Path -LiteralPath $dest)) { Copy-Newer $f $dest; return }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'; $rows = New-Object System.Collections.Generic.List[object]; $i = 0
  foreach ($file in $dest, $f.FullName) {
    foreach ($l in [IO.File]::ReadAllLines($file)) {
      if (-not $l.Trim() -or -not $seen.Add($l)) { continue }
      $m = [regex]::Match($l, '"timestamp"\s*:\s*(\d+)')
      $rows.Add([pscustomobject]@{ t = $(if ($m.Success) { [long]$m.Groups[1].Value } else { [long]0 }); i = $i++; l = $l })
    }
  }
  $text = (@($rows | Sort-Object t, i | ForEach-Object { $_.l }) -join "`n") + "`n"
  if ($text -ceq [IO.File]::ReadAllText($dest)) { return }
  Save-Safety $dest
  Write-TextFile $dest $text
}
function Use-Choice($f) {   # a file changed on both laptops, settled the way the user (or Claude) chose
  $c = $f.choice; $other = $null
  if ($c -eq 'both') {   # this PC's stays in use; the old laptop's sits next to it until Claude merges them
    $other = Join-Path (Split-Path $f.dest) ([IO.Path]::GetFileNameWithoutExtension($f.dest) + '.from-' + $script:fromTag + [IO.Path]::GetExtension($f.dest))
    Copy-Item -LiteralPath $f.incoming $other -Force
    $script:fileNotes.Add([ordered]@{ file = $f.dest; other = $other; from = $script:fromPc })
  } elseif ($c -ne 'mine') {   # theirs, combined, or a merged version
    Save-Safety $f.dest
    Copy-Item -LiteralPath $(if ($c -eq 'theirs') { $f.incoming } elseif ($c -eq 'combine') { $f.combined } else { $c }) $f.dest -Force
  }
  $script:settled[$f.dest] = $f.key
  if (-not $f.group) { $script:choicesMade.Add([ordered]@{ id = $f.id; label = $f.label; choice = $(if ($c -in 'mine', 'theirs', 'both', 'combine') { $c } else { 'merged' }); otherCopy = $other }) }
}
function Use-File($f) {   # $true if the file came in or was settled
  Update-FileState $f   # looks again: something may have changed since the screen
  if ($f.state -eq 'copy') { New-Item -ItemType Directory -Force (Split-Path $f.dest) | Out-Null; Copy-Item -LiteralPath $f.incoming $f.dest -Force; return $true }
  if ($f.state -eq 'conflict') { Use-Choice $f; return $true }
  $false
}
function Use-PartialSettings($P, $want) {   # only hooks or plugins ticked: their switches go into this PC's settings.json
  $built = Build-SettingsJson $P $want
  if (-not $built) { return }
  $assembled = if ($built.combined) { $built.combined } else { $built.theirs }
  $dest = "$HomeDir\.claude\settings.json"
  if (Test-Path -LiteralPath $dest) {
    if ((Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $assembled).Hash) { return }
    Save-Safety $dest
  } else { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null }
  Copy-Item -LiteralPath $assembled $dest -Force
}
function Move-Parts($P, $want, [switch]$SkipLive, [switch]$LiveOnly) {   # ~/.claude apart from chats and memory, kind by kind
  $c = "$($P.sh)\.claude"; $sa = $P.sa
  if (-not $LiveOnly) {
    if ($want.instructions) {
      foreach ($f in $P.files) { if ($f.cat -eq 'instructions') { [void](Use-File $f) } }
      Copy-Tree "$c\rules" "$HomeDir\.claude\rules" 'Putting your rules in place...' -Merge
    }
    foreach ($k in 'hooks', 'skills') { if ($want[$k]) { foreach ($d in $partDirs[$k]) { Copy-Tree "$c\$d" "$HomeDir\.claude\$d" "Putting your $(Get-Lower $k) in place..." -Merge } } }
    if ($want.plugins) {   # plugin lists are combined with a safety copy; the plugins themselves file by file
      $lists = @(Get-ChildItem -LiteralPath "$c\plugins" -File -Filter *.json -Force -ErrorAction SilentlyContinue)
      Copy-Tree "$c\plugins" "$HomeDir\.claude\plugins" 'Putting your plugins in place...' (@('/XF') + @($lists | ForEach-Object { Q $_.FullName })) -Merge
      foreach ($f in $lists) { Merge-SettingsFile $f "$HomeDir\.claude\plugins\$($f.Name)" }
    }
    if ($want.settings) {   # the rest of ~/.claude; its loose files are handled below
      $parts = @($partDirs.Values | ForEach-Object { $_ })
      Copy-Tree $c "$HomeDir\.claude" 'Putting your settings in place...' (
        @('/XD') + @(($chatDirs + $parts) | ForEach-Object { Q "$c\$_" }) + @('/XF') + @(Get-ChildItem -LiteralPath $c -File -Force -ErrorAction SilentlyContinue | ForEach-Object { Q $_.FullName })) -Merge
      $built = Build-SettingsJson $P $want   # from this PC's settings.json as it is now, which may have changed since the screen
      foreach ($f in $P.files) { if ($f.cat -eq 'settings') { if ($built) { $f.incoming = $built.theirs; $f.combined = $built.combined }; [void](Use-File $f) } }
    } elseif ($want.hooks -or $want.plugins) { Use-PartialSettings $P $want }
  }
  if ($want.settings) {   # loose settings files: combined; the ones a running Claude rewrites wait until it's closed
    $loose = @(Get-ChildItem -LiteralPath $c -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin 'CLAUDE.md', 'settings.json', 'history.jsonl' }) +
      @(Get-ChildItem -LiteralPath $P.sh -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'AGENTS.md' }) +
      @(Get-Item -LiteralPath "$sa\claude_desktop_config.json" -Force -ErrorAction SilentlyContinue)
    foreach ($f in $loose) {
      $live = $liveNames -contains $f.Name
      if (($SkipLive -and $live) -or ($LiveOnly -and -not $live)) { continue }
      $dest = if ($f.FullName.StartsWith($sa)) { $claudeDir + $f.FullName.Substring($sa.Length) } else { $HomeDir + $f.FullName.Substring($P.sh.Length) }
      Merge-SettingsFile $f $dest
    }
  }
}
function Move-Memory($P) {
  foreach ($d in Get-ChildItem -LiteralPath "$($P.sh)\.claude\projects" -Directory -ErrorAction SilentlyContinue) {
    if (Test-Path -LiteralPath "$($d.FullName)\memory") { Copy-Tree "$($d.FullName)\memory" "$HomeDir\.claude\projects\$($d.Name)\memory" 'Putting memory in place...' -Merge }
  }
}
function Invoke-GitStep([string]$dir) {   # a git command whose output doesn't matter; $true if it worked
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & git -C $dir @args 2>&1 | Out-Null; $LASTEXITCODE -eq 0 } finally { $ErrorActionPreference = $old }
}
function Get-Project($pr) {   # downloads a project from GitHub to exactly its old place; $true when it's there
  if ($Test -and -not (Test-Path -LiteralPath $pr.remote)) { $warnings.Add("Test run: '$($pr.name)' wasn't downloaded."); return $false }   # tests use a local folder as "GitHub"
  New-Item -ItemType Directory -Force (Split-Path $pr.path) | Out-Null
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  if ($quiet -or $Test) { & git clone -q $pr.remote $pr.path 2>&1 | Out-Null } else { & git clone $pr.remote $pr.path | Out-Host }
  $ErrorActionPreference = $old
  if (Test-Path -LiteralPath (Join-Path $pr.path '.git')) { return $true }
  $warnings.Add("Couldn't download '$($pr.name)' from $($pr.remote). Copy it from your old laptop to exactly: $($pr.path)")
  $false
}
function Save-Bundle($pr) {   # commits that couldn't be added: kept in the safety folder for later
  $keep = Join-Path $script:safety "$($pr.name).bundle"
  New-Item -ItemType Directory -Force $script:safety | Out-Null
  Copy-Item -LiteralPath $pr.bundle $keep -Force
  $warnings.Add("$($pr.name): its commits that weren't on GitHub couldn't be added. They're saved in $keep (fetch that file with git to get them).")
}
function Restore-Commits($pr) {   # a fresh download: commits that weren't on GitHub, then the old laptop's branch and commit; how many came back
  $got = 0
  if ($pr.bundle) { if (Invoke-GitStep $pr.path fetch -q --update-head-ok $pr.bundle '+refs/heads/*:refs/heads/*') { $got = $pr.ahead } else { Save-Bundle $pr } }
  if ($pr.head -and (Invoke-GitStep $pr.path cat-file -e "$($pr.head)^{commit}")) {
    if ($pr.branch -and $pr.branch -ne 'HEAD') {
      [void](Invoke-GitStep $pr.path checkout -q -f -B $pr.branch $pr.head)
      if (Invoke-GitStep $pr.path rev-parse -q --verify "refs/remotes/origin/$($pr.branch)") { [void](Invoke-GitStep $pr.path branch -q "--set-upstream-to=origin/$($pr.branch)" $pr.branch) }
    } else { [void](Invoke-GitStep $pr.path checkout -q -f --detach $pr.head) }
  } elseif ($pr.branch -and $pr.branch -ne 'HEAD') { [void](Invoke-GitStep $pr.path checkout -q $pr.branch) }
  $got
}
function Move-Projects($P) {   # GitHub projects come down again, then everything the old laptop had on top
  foreach ($pr in $P.projects) {
    if ($pr.mode -eq 'none') { continue }
    if (-not $pr.here -and -not (Test-Path -LiteralPath $pr.path)) {
      if ($pr.kind -eq 'git') {
        if (-not $script:hasGit) { $warnings.Add("Git isn't installed, so '$($pr.name)' wasn't downloaded. Install Git and move in again."); continue }
        if (-not (Get-Project $pr)) { continue }
        $commits = Restore-Commits $pr
        if ($pr.mode -eq 'all' -and $pr.hasFiles) { Copy-Tree $pr.stage $pr.path "Adding $($pr.name)'s local files..." }   # a fresh download: the old laptop's files go on top
        if ($pr.mode -eq 'all') { foreach ($d in $pr.deleted) { Remove-Item -LiteralPath (Join-Path $pr.path $d) -Force -ErrorAction SilentlyContinue } }
        Put ("   [x] $($pr.name): downloaded from GitHub" + $(if ($pr.mode -eq 'all' -and $pr.count) { ", with $(Plural $pr.count 'local file')" }) + $(if ($commits) { ", and $(Plural $commits 'commit') that weren't on GitHub" }) + '.') ok
        $script:projectsIn++
      } elseif ($pr.packed -eq 'all') {
        Copy-Tree $pr.stage $pr.path "Copying $($pr.name)..."
        Put "   [x] $($pr.name): copied, $(Format-Size $pr.size)." ok
        $script:projectsIn++
      }
      continue
    }
    # already here: add what's missing, settle what differs, and keep commits that weren't on GitHub as old-laptop/ branches
    $n = 0; foreach ($f in $P.files) { if ($f.project -eq $pr -and (Use-File $f)) { $n++ } }
    $extra = ''
    if ($pr.bundle -and (Test-Path -LiteralPath (Join-Path $pr.path '.git'))) {
      if (Invoke-GitStep $pr.path fetch -q $pr.bundle '+refs/heads/*:refs/remotes/old-laptop/*') { $extra = "; its commits that weren't on GitHub are in the old-laptop/ branches" }
      else { Save-Bundle $pr }
    }
    Put "   [x] $($pr.name): $(Plural $n 'file') added or settled$extra." ok
    $script:projectsIn++
  }
}
function Move-Chats($P) {   # needs Claude closed: the app keeps its session list in memory and writes it back
  $sh = $P.sh; $sa = $P.sa
  $referenced = New-Object 'System.Collections.Generic.HashSet[string]'
  $sessS = "$sa\claude-code-sessions"; $damaged = 0
  foreach ($dir in $sessS, "$claudeDir\claude-code-sessions") {
    foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue) {
      $j = $null; try { $j = Read-Json $f.FullName } catch {}
      if (-not $j) {   # damaged, say all zeros after a crash: the app skips it too, so the old laptop's isn't brought in
        $damaged++; if ($dir -eq $sessS) { Remove-Item -LiteralPath $f.FullName -Force }; continue
      }
      foreach ($id in @($j.cliSessionId) + @($j.priorCliSessionIds)) { if ($id) { [void]$referenced.Add($id) } }
    }
  }
  if ($damaged) { $warnings.Add("Skipped $(Plural $damaged 'damaged session file') (unreadable, usually left by a crash). Claude skips them too.") }
  Merge-Transcripts $sh $referenced
  Merge-Sessions $sa
  Copy-Tree "$sh\.claude\projects" "$HomeDir\.claude\projects" 'Putting your chats in place...' @('/XD', 'memory') -Merge
  foreach ($d in $chatDirs) { if ($d -ne 'projects') { Copy-Tree "$sh\.claude\$d" "$HomeDir\.claude\$d" 'Putting your chats in place...' -Merge } }
  foreach ($d in $appChats) { Copy-Tree "$sa\$d" "$claudeDir\$d" "Putting the app's session list in place..." -Merge }
  foreach ($f in @(Get-Item -LiteralPath "$sh\.claude\history.jsonl" -Force -ErrorAction SilentlyContinue)) { Merge-History $f "$HomeDir\.claude\history.jsonl" }
  foreach ($f in @(Get-Item -LiteralPath "$sa\git-worktrees.json" -Force -ErrorAction SilentlyContinue)) { Merge-SettingsFile $f "$claudeDir\git-worktrees.json" }
  $cnt = $script:count
  Put '   [x] Your chats are in.' ok
  if ($cnt.new) { Put "   [x] Added from your old laptop: $(Plural $cnt.new 'session')." ok }
  if ($cnt.updated) { Put "   [x] Updated because the other laptop's copy was newer: $(Plural $cnt.updated 'session')." ok }
  if ($cnt.kept) { Put "   [x] Already up to date here, left as they are: $(Plural $cnt.kept 'session')." ok }
  if ($cnt.both) { Put "   [x] Used on BOTH laptops: $(Plural $cnt.both 'chat'). You get both copies, nothing lost." warn }
}
function Move-Sidebar($P) {   # a small database that can't be mixed: it comes in whole, and this PC's is saved first
  $lsS = "$($P.sa)\Local Storage"; $lsT = "$claudeDir\Local Storage"
  if (-not (Test-Path -LiteralPath $lsS)) { return }
  if (Test-Path -LiteralPath $lsT) { New-Item -ItemType Directory -Force $script:safety | Out-Null; Move-Item -LiteralPath $lsT (Join-Path $script:safety 'Local Storage'); $script:replaced++ }
  Copy-Tree $lsS $lsT 'Putting your sidebar layout in place...'
  Put '   [x] Sidebar layout is in.' ok
}
function Wait-ClaudeClosed {   # $true once Claude is closed, $false if the user skips
  Put '   Close Claude now, and the rest comes in right away.' title
  Put '   Quit it from its icon near the clock, or press C and I close it for you. S skips this for now.' dim
  Gap
  $t0 = Get-Date; $frame = 0
  while (Test-ClaudeOpen) {
    $key = ''
    if ($Test) { $key = Read-Line; if (-not $key) { $key = 'S' } }   # scripted test input; when it runs out, skip
    else { try { if ([Console]::KeyAvailable) { $key = [string][Console]::ReadKey($true).KeyChar } } catch {} }
    if ($key -eq 'S') { Gap; return $false }
    if ($key -eq 'C' -and -not (Stop-Claude)) { Put "`r   Claude didn't close. Quit it from its icon near the clock." warn }
    Show-Walk $frame 'Waiting for Claude to close...' $t0
    Start-Sleep -Milliseconds 350; $frame = 1 - $frame
  }
  if (-not $Test -and -not $quiet) { Write-Host ("`r" + (' ' * 70) + "`r") -NoNewline }
  Put '   [x] Claude is closed.' ok
  $true
}

function Invoke-MoveIn($P) {
  $want = @{}; foreach ($it in $P.items) { $want[$it.key] = [bool]$it.on }
  $projectsTicked = $P.projects.Count -and -not ($What.Count -and $What -notcontains 'projects')   # for the "copy these folders first" warning
  if (-not $want.projects) { foreach ($pr in $P.projects) { $pr.mode = 'none' } }
  $want.projects = [bool]@($P.projects | Where-Object { $_.mode -ne 'none' }).Count
  if (-not ($want.Values -contains $true)) { throw 'Nothing was ticked, so there is nothing to move in.' }
  $script:safety = Join-Path $HomeDir ".claude-moove-safety\$stamp"
  $script:replaced = 0; $script:projectsIn = 0
  $script:fileNotes = New-Object System.Collections.Generic.List[object]
  $script:choicesMade = New-Object System.Collections.Generic.List[object]
  $script:settled = @{}; $script:rel = @{}; $script:forkOf = @{}; $script:pending = @{}; $script:transcriptDir = @{}
  $script:count = @{ new = 0; updated = 0; kept = 0; both = 0 }
  $script:fromPc = if ($P.mf.computer) { [string]$P.mf.computer } else { 'other laptop' }
  $script:fromTag = $script:fromPc -replace '[^A-Za-z0-9]+', '-'
  foreach ($f in $P.files) { if ($f.group -and -not $f.fixed -and $P.groups.Contains($f.group)) { $f.choice = $P.groups[$f.group].choice } }
  if ($WhenClosed -and (Test-ClaudeOpen)) {
    Show-Top 'Close Claude, and the rest comes in.'
    if (-not (Wait-ClaudeClosed)) { Remove-Tree $P.work; $script:work = $null; Put '   Nothing more was changed. Run this again once Claude is closed.' dim; End-Wait; return }
  }
  $parts = @('instructions', 'settings', 'hooks', 'skills', 'plugins', 'memory' | Where-Object { $want[$_] })
  $later = $want.chats -or $want.sidebar
  $script:steps = @()
  if ($want.projects) { $script:steps += 'Your projects' }
  if ($parts.Count) { $script:steps += 'Settings, instructions and memory' }
  if ($later) { $script:steps += 'Chats and sidebar layout' }
  $s = 0; $waiting = @(); $open = Test-ClaudeOpen

  if ($want.projects) { $s++; Set-Step $s; Move-Projects $P }
  if ($parts.Count) {   # these are fine with Claude open
    $s++; Set-Step $s
    Move-Parts $P $want -SkipLive:($open -and $later)
    if ($want.memory) { Move-Memory $P }
    Put ('   [x] In: ' + (($parts | ForEach-Object { Get-Lower $_ }) -join ', ') + '.') ok
  }
  foreach ($c in $script:choicesMade) {
    $how = switch ($c.choice) { 'both' { 'kept both; the old laptop''s is next to it as ' + (Split-Path $c.otherCopy -Leaf) } 'combine' { "combined; the old laptop's settings won" } 'mine' { "kept this PC's" } 'theirs' { "took the old laptop's" } default { 'used the merged version' } }
    Put "   [x] $($c.label): $how." ok
  }
  if ($later) {   # these need Claude closed
    $s++; Set-Step $s
    if ((Test-ClaudeOpen) -and $interactive) { [void](Wait-ClaudeClosed) }
    if (Test-ClaudeOpen) {
      $waiting = @(@('chats', 'sidebar') | Where-Object { $want[$_] }) + @(if ($want.settings -and $open) { 'settings' })
      Put '   Claude is still open, so your chats and sidebar layout wait for now.' warn
    } else {
      if ($want.settings -and $open) { Move-Parts $P $want -LiveOnly }
      if ($want.chats) { Move-Chats $P }
      if ($want.sidebar) { Move-Sidebar $P }
    }
  }

  # Claude's one-time notes: chats continued on both laptops, and files kept in both versions
  if ($script:pending.Count -or $script:fileNotes.Count) {
    $pf = Join-Path $HomeDir '.claude\claude-moove\pending-merges.json'
    $all = [ordered]@{}
    try { foreach ($prop in (Read-Json $pf).PSObject.Properties) { $all[$prop.Name] = $prop.Value } } catch {}
    foreach ($k in $script:pending.Keys) { $all[$k] = $script:pending[$k] }
    if ($script:fileNotes.Count) { $all['*'] = @(@($all['*']) | Where-Object { $_ }) + $script:fileNotes.ToArray() }
    New-Item -ItemType Directory -Force (Split-Path $pf) | Out-Null
    [IO.File]::WriteAllText($pf, ($all | ConvertTo-Json -Depth 5), $utf8)
    $hook = Join-Path $HomeDir '.claude\hooks\claude-moove-merge.mjs'
    New-Item -ItemType Directory -Force (Split-Path $hook) | Out-Null
    Copy-Item -LiteralPath (Join-Path $engine 'claude-moove-merge.mjs') $hook -Force
    if (Get-Command node -ErrorAction SilentlyContinue) { & node $hook --install (Join-Path $HomeDir '.claude\settings.json') }
    else { $warnings.Add("Claude's one-time notes about what changed on both laptops need Node.js. Everything is still there; install Node.js and move in again to switch them on.") }
  }
  $waitFor = @(if ($projectsTicked) { $P.projects | Where-Object { -not $_.here -and $_.modes.Count -eq 1 -and $_.hasFiles } })   # only their Claude files came, and the folder isn't here
  if ($waitFor.Count -le 3) { foreach ($pr in $waitFor) { $warnings.Add("Copy the folder '$($pr.name)' from your old laptop to exactly: $($pr.path), then move in again for its $(Plural $pr.count 'Claude file').") } }
  else {
    $names = @($waitFor | ForEach-Object { $_.name })
    $shown = if ($names.Count -gt 6) { ($names[0..4] -join ', ') + ", and $($names.Count - 5) more" } else { $names -join ', ' }
    $warnings.Add("$($waitFor.Count) project folders aren't on this laptop: $shown. Copy them from your old laptop to the same place, for example $($waitFor[0].path), then move in again for their Claude files.")
  }
  $settled = Read-Marker; foreach ($k in $script:settled.Keys) { $settled[$k] = $script:settled[$k] }
  Update-Marker @{ lastUnpack = (Get-Date).ToString('o'); from = $script:fromPc; resolved = $settled; freshInstall = ($script:firstMoove -and $waiting.Count -gt 0) }
  Remove-Tree $P.work; $script:work = $null

  $opened = $false
  if ($waiting.Count -and -not $interactive -and -not $Test) {   # the Claude skill: a small window brings in the rest once Claude is closed
    Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Q (Join-Path $engine 'claude-moove.ps1')),
      '-Mode', 'unpack', '-From', (Q $P.src), '-What', ($waiting -join ','), '-WhenClosed',
      '-HomeDir', (Q $HomeDir), '-AppDataDir', (Q $AppDataDir), '-DesktopDir', (Q $DesktopDir), '-DocumentsDir', (Q $DocumentsDir))
    $opened = $true
  }
  $cnt = $script:count
  $final = @()
  if ($waiting.Count) {
    $final += "[!] Still to come: $(($waiting | ForEach-Object { Get-Lower $_ }) -join ', '). They need Claude closed."
    $final += $(if ($opened) { '    A small Claude Moove window is waiting: close Claude, and they come in right away.' } else { '    Close Claude and move in again; it only adds what is missing.' })
  } else { $final += "[x] You're moved in. Open Claude: your sessions are in the sidebar." }
  if ($script:projectsIn) { $final += "[x] $(Plural $script:projectsIn 'project') set up just like on your old laptop." }
  if ($cnt.both) { $final += "[x] Used on both laptops: $(Plural $cnt.both 'chat'). You have both: the one from here, and the one marked '(other laptop)'.", '    The first time you open either, Claude gets a one-time note about what happened in the other.' }
  if ($script:fileNotes.Count) { $final += "[x] Kept both versions of $(Plural $script:fileNotes.Count 'file') changed on both laptops. Next time you start Claude,", "    it offers to merge them. The old laptop's versions end in  .from-$($script:fromTag)" }
  if ($script:replaced) { $final += "    Anything replaced is saved in $($script:safety)" }
  if ($script:received) { $final += "    The folder that came over is on your Desktop ($(Split-Path $script:received -Parent | Split-Path -Leaf)). Delete it once all looks right." }
  foreach ($w in $warnings) { $final += "[!] $w" }
  $final += '', 'Next time you move, paste the same line into PowerShell and choose  1  (pack up):', "      $oneLiner"
  Show-Big -Bloom $final
  Write-Result ([ordered]@{
      ok = $true; folder = $P.src; from = $script:fromPc
      moved = @($P.items | Where-Object { $want[$_.key] -and $waiting -notcontains $_.key } | ForEach-Object { $_.key }); waiting = $waiting; finishWindow = $opened
      sessions = [ordered]@{ added = $cnt.new; updated = $cnt.updated; unchanged = $cnt.kept; usedOnBoth = $cnt.both }
      projects = @($P.projects | Where-Object { $_.mode -ne 'none' } | ForEach-Object { [ordered]@{ name = $_.name; path = $_.path; mode = $_.mode; wasHere = $_.here } })
      choices = $script:choicesMade.ToArray(); groups = @($P.groups.Values | Where-Object { $_.project.mode -ne 'none' } | ForEach-Object { [ordered]@{ id = "$($_.path)\*"; choice = $_.choice; files = $_.files.Count } })
      safetyFolder = $(if ($script:replaced) { $script:safety } else { $null }); warnings = @($warnings) })
  End-Wait
}

function Invoke-Unpack {
  $script:doing = 'moving in on this laptop'; $script:steps = $null
  Show-Top 'Looking for your packed stuff...'
  $src = Find-Source
  if (-not $src) { Put '   Nothing was changed.' dim; End-Wait; return }
  $P = Get-UnpackPlan $src
  $P.canReceive = $interactive -and -not $From -and -not $script:received -and ($src -ne $toolRoot)
  if ($Plan) { Write-Plan $P; return }
  $state = @{ msg = '' }
  while ($interactive -and -not $WhenClosed) {
    $P.installed = Test-Path -LiteralPath (Join-Path $claudeDir 'config.json'); $P.account = Get-AccountState $P.mf; $P.open = Test-ClaudeOpen
    Show-UnpackMenu $P $state
    $a = Read-Choice
    $shown = @(Get-ShownConflicts $P); $groups = @(Get-ShownGroups $P); $k = 0
    $ni = $P.items.Count; $nc = $shown.Count
    if ($a -eq '') { if ($P.installed) { break }; $state.msg = "Claude isn't installed yet: press D for the download page, open Claude once and sign in, then press Enter." }
    elseif ($a -eq 'Q') { Remove-Tree $P.work; $script:work = $null; Put '   Nothing was changed.' dim; End-Wait; return }
    elseif ([int]::TryParse($a, [ref]$k) -and $k -ge 1 -and $k -le $ni + $nc + $groups.Count) {
      if ($k -le $ni) {
        $it = $P.items[$k - 1]
        if ($it.key -eq 'projects') { Edit-Projects $P.projects 'Show-ProjectsIn' } else { $it.on = -not $it.on }
      } elseif ($k -le $ni + $nc) {
        $f = $shown[$k - $ni - 1]
        $opts = @(Get-Options $f)
        $f.choice = $opts[([array]::IndexOf($opts, $f.choice) + 1) % $opts.Count]
      } else { $g = $groups[$k - $ni - $nc - 1]; $g.choice = if ($g.choice -eq 'mine') { 'theirs' } else { 'mine' } }
    }
    elseif ($a -eq 'C' -and $P.open) { if (-not (Stop-Claude)) { $state.msg = "Claude didn't close. Quit it from its icon near the clock." } }
    elseif ($a -eq 'N' -and -not $P.node) { Install-Tool 'node'; $P.node = [bool](Get-Command node -ErrorAction SilentlyContinue) }
    elseif ($a -eq 'G' -and -not $script:hasGit) { Install-Tool 'git'; $script:hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue) }
    elseif ($a -eq 'D') { if (-not $Test) { Start-Process 'https://claude.ai/download' } }
    elseif ($a -eq 'A') { }
    elseif ($a -eq 'R' -and $P.canReceive) {
      try { $got = Receive-Folder; $P = Get-UnpackPlan $got } catch { $state.msg = $_.Exception.Message }
    }
    else { $state.msg = "I didn't get that one." }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $claudeDir 'config.json'))) { throw "Claude isn't installed on this laptop yet (or hasn't been opened once). Install it from claude.ai/download, open it once and sign in, then move in." }
  Invoke-MoveIn $P
}

function Install-Skill {   # copies the skill and this engine into ~/.claude/skills/claude-moove, so Claude can run moves
  $skill = Join-Path $toolRoot 'skills\claude-moove\SKILL.md'
  if (-not (Test-Path -LiteralPath $skill)) { throw "This copy of Claude Moove doesn't include the skill. Start it with the one-line command to get the latest." }
  $to = Join-Path $HomeDir '.claude\skills\claude-moove'
  New-Item -ItemType Directory -Force (Join-Path $to 'engine') | Out-Null
  Copy-Item -LiteralPath $skill $to -Force
  foreach ($f in 'claude-moove.ps1', 'claude-moove-merge.mjs', 'README.md') { Copy-Item -LiteralPath (Join-Path $engine $f) (Join-Path $to "engine\$f") -Force }
  Get-ChildItem -LiteralPath $toolRoot -Filter '*.cmd' | Copy-Item -Destination $to -Force
  Copy-One (Join-Path $toolRoot 'LICENSE') $to
  Show-Big -Bloom @(
    '[x] Claude can now do your moves for you.', '',
    'In Claude Code or the desktop app, start a new session and type  /claude-moove',
    'or just ask: "pack up my Claude stuff" or "move my Claude stuff in".',
    'Claude runs the same steps, and when a file changed on both laptops, it merges the two for you.')
  Write-Result ([ordered]@{ ok = $true; skill = $to })
  End-Wait
}

function Invoke-Menu {   # what the one-line command opens
  Show-Big @(
    "Hi! I move all your Claude stuff from one Windows laptop to another. What are we doing?", '',
    '   1   Pack up THIS laptop      (the one you are leaving)',
    '   2   Move in on THIS laptop   (the one you are moving to)',
    '   3   Let Claude do it         (adds Claude Moove to Claude as a skill)')
  switch (Read-Answer 'Type 1, 2 or 3 and press Enter:') {
    '1' { Invoke-Pack }
    '2' { Invoke-Unpack }
    '3' { Install-Skill }
    default { Put '   Nothing was changed. See you on moving day!' dim; End-Wait }
  }
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
  $fakeProjects = @(
    [ordered]@{ name = 'recipe-app'; kind = 'git'; mode = 'all'; modes = @('all', 'github', 'none'); count = 14; size = 2202010; big = $false; ahead = 2; claude = @(); sample = 'data\, .env, ...' },
    [ordered]@{ name = 'website'; kind = 'git'; mode = 'all'; modes = @('all', 'github', 'none'); count = 1; size = 900; big = $false; ahead = 0; claude = @('.claude\settings.local.json'); sample = '.claude\' },
    [ordered]@{ name = 'ml-experiments'; kind = 'git'; mode = 'github'; modes = @('all', 'github', 'none'); count = 1234; size = 891289600; big = $true; ahead = 0; claude = @(); sample = 'datasets\, runs\' },
    [ordered]@{ name = 'notes'; kind = 'local'; mode = 'all'; modes = @('all', 'claude', 'none'); count = 37; size = 47185920; big = $false; ahead = 0; claude = @('CLAUDE.md'); sample = 'drafts\, CLAUDE.md, ...' },
    [ordered]@{ name = 'Desktop'; kind = 'special'; mode = 'claude'; modes = @('claude', 'none'); count = 0; size = 0; big = $false; ahead = 0; claude = @('CLAUDE.md'); sample = '' },
    [ordered]@{ name = 'old-prototype'; kind = 'git'; mode = 'none'; modes = @('all', 'github', 'none'); count = 3; size = 4096; big = $false; ahead = 0; claude = @(); sample = 'scratch\' })

  Write-Host '@@SCREEN The first thing you see'
  Show-Big @(
    "Hi! I move all your Claude stuff from one Windows laptop to another. What are we doing?", '',
    '   1   Pack up THIS laptop      (the one you are leaving)',
    '   2   Move in on THIS laptop   (the one you are moving to)',
    '   3   Let Claude do it         (adds Claude Moove to Claude as a skill)')
  Wait-Enter 'Type 1, 2 or 3 and press Enter:'

  Write-Host '@@SCREEN Packing: pick what comes along, even with Claude still open'
  $script:doing = 'packing up this laptop'
  $items = @(
    [ordered]@{ key = 'chats'; on = $true; detail = '42 sessions, 120 chats' },
    [ordered]@{ key = 'memory'; on = $true; detail = 'notes Claude keeps, in 6 projects' },
    [ordered]@{ key = 'instructions'; on = $true; detail = 'your global CLAUDE.md, AGENTS.md' },
    [ordered]@{ key = 'settings'; on = $true; detail = 'settings.json, MCP servers, app settings' },
    [ordered]@{ key = 'hooks'; on = $false; detail = '3 hook files' },
    [ordered]@{ key = 'skills'; on = $true; detail = '4 skills, 2 commands, 1 agent' },
    [ordered]@{ key = 'plugins'; on = $true; detail = '5 plugins' },
    [ordered]@{ key = 'sidebar'; on = $true; detail = 'how your sidebar is organised' },
    [ordered]@{ key = 'projects'; on = $true; detail = '' })
  Show-PackMenu $items @{ open = $true; how = 'send'; msg = '' } $fakeProjects
  Put '   > ' title

  Write-Host '@@SCREEN Packing: pick your projects'
  Show-ProjectsOut $fakeProjects @{ msg = '' }
  Put '   > ' title

  Write-Host '@@SCREEN Sending it over the internet with a one-time code'
  $script:steps = 'Copy your Claude stuff', 'Zip it up', 'Make your transfer folder', 'Send it to the new laptop'
  Set-Step 4
  Put '   [x] Transfer folder ready.' ok
  Gap
  Put '   Your code:   ' plain -n; Put 'joy-buzz-tiger' pink
  Gap
  Put '   On the NEW laptop, open PowerShell and paste:' title
  Put "     $oneLiner" plain
  Put '   then choose  2  (move in) and type the code above when it asks.' plain
  Put '   Keep this window open until it says done.' dim
  Put '   The code works once: only type it on your own laptop.' dim
  Put "   If the new laptop can't connect, close this and carry the folder instead (it's on your Desktop)." dim
  Gap
  Put '   Sending to the new laptop...  47%, 12.4 MB/s  1:12' plain

  Write-Host '@@SCREEN Moving in: a packed folder is already on this laptop'
  $script:doing = 'moving in on this laptop'; $script:steps = $null
  Show-Top 'Looking for your packed stuff...'
  Show-Found 'E:\Claude Moove 2026-10-07 2054' 'OLD-LAPTOP' '2026-10-07 20:54' 2
  Gap; Put '   Your choice:' title

  Write-Host '@@SCREEN Moving in: pick what comes in, and settle what changed on both laptops'
  $script:doing = 'moving in on this laptop'; $script:steps = $null; $script:hasGit = $true
  $proj = [pscustomobject]@{ name = 'recipe-app'; mode = 'all' }
  $fake = { param($label, $cat, $choice, $newer) [pscustomobject]@{ label = $label; cat = $cat; state = 'conflict'; choice = $choice; newer = $newer; bothOk = $true; group = $null; project = $null } }
  $P = @{
    src = 'E:\Claude Moove 2026-01-01 1200'; mf = [pscustomobject]@{ computer = 'OLD-LAPTOP'; created = '2026-01-01T12:00:00' }
    livedIn = $true; account = 'same'; lsHere = $true; open = $true; node = $true; canReceive = $true
    pairs = @(@('C:\Users\Alex\Desktop', 'C:\Users\alex.lee\OneDrive\Desktop'), @('C:\Users\Alex', 'C:\Users\alex.lee'))
    items = @(
      [ordered]@{ key = 'chats'; on = $true; detail = '42 sessions, 120 chats' },
      [ordered]@{ key = 'memory'; on = $true; detail = 'notes Claude keeps, in 6 projects' },
      [ordered]@{ key = 'instructions'; on = $true; detail = 'your global CLAUDE.md, AGENTS.md' },
      [ordered]@{ key = 'settings'; on = $true; detail = 'settings.json, MCP servers, app settings' },
      [ordered]@{ key = 'skills'; on = $true; detail = '4 skills, 2 commands, 1 agent' },
      [ordered]@{ key = 'plugins'; on = $true; detail = '5 plugins' },
      [ordered]@{ key = 'sidebar'; on = $false; detail = '' },
      [ordered]@{ key = 'projects'; on = $true; detail = '' })
    projects = @(
      [pscustomobject]@{ name = 'recipe-app'; mode = 'all'; here = $true; kind = 'git' },
      [pscustomobject]@{ name = 'website'; mode = 'all'; here = $false; kind = 'git' },
      [pscustomobject]@{ name = 'notes'; mode = 'all'; here = $false; kind = 'local' },
      [pscustomobject]@{ name = 'ml-experiments'; mode = 'none'; here = $false; kind = 'git' })
    files = @(
      (& $fake 'CLAUDE.md (global)' 'instructions' 'both' 'theirs'),
      (& $fake 'settings.json (global)' 'settings' 'combine' 'theirs'))
    groups = [ordered]@{ 'C:\recipe-app' = [pscustomobject]@{ label = 'recipe-app: 3 other files'; choice = 'mine'; project = $proj
        files = @([pscustomobject]@{ rel = '.env' }, [pscustomobject]@{ rel = 'src\config.ts' }, [pscustomobject]@{ rel = 'data\seed.sql' }) } }
  }
  Show-UnpackMenu $P @{ msg = '' }
  Put '   > ' title

  Write-Host '@@SCREEN Moving in (projects set up, chats merged, nothing here lost)'
  $script:steps = 'Your projects', 'Settings, instructions and memory', 'Chats and sidebar layout'
  Set-Step 3
  Put '   [x] Claude is closed.' ok
  Put '   [x] Your chats are in.' ok
  Put '   [x] Added from your old laptop: 38 sessions.' ok
  Put "   [x] Updated because the other laptop's copy was newer: 3 sessions." ok
  Put '   [x] Used on BOTH laptops: 1 chat. You get both copies, nothing lost.' warn
  Put '   Putting your chats in place...  0:41' plain

  Write-Host '@@SCREEN The end'
  $script:steps = $null
  Show-Big -Bloom @(
    '[x] All packed: 42 sessions, 120 chat files, 900 MB.',
    '[x] Projects: recipe-app (GitHub + local files), website (GitHub + local files), notes (whole folder).',
    'Your transfer folder is on your Desktop:  Claude Moove 2026-01-01 1200',
    'WHAT NOW',
    ' 1. Copy that whole folder to a USB stick (or a cloud drive).',
    " 2. On the new laptop, open it and double-click  2 - UNPACK  (or paste the one line and choose 2)",
    'Keep that folder private: it holds your full chat history and your projects'' local files.')
  End-Wait
}

try {
  foreach ($w in $What) { if (-not $labels.Contains($w)) { throw "-What doesn't know '$w'. Use any of: $($labels.Keys -join ', ')" } }
  switch ($Mode) { 'menu' { Invoke-Menu } 'pack' { Invoke-Pack } 'unpack' { Invoke-Unpack } 'preview' { Invoke-Preview } }
  Remove-Tree $script:work
  exit 0
} catch {
  $msg = $_.Exception.Message
  if ($Test) { $msg += ' | ' + ($_.ScriptStackTrace -replace '\s*\r?\n\s*', ' < ') }   # where it broke, for test runs
  Remove-Tree $script:work
  if ($Json) { Write-Result ([ordered]@{ ok = $false; error = $msg; warnings = @($warnings) }) } else { Show-Fail $msg }
  exit 3
}
