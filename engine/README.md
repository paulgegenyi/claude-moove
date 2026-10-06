# How Claude Moove works

Start with the main [README](../README.md) for what Claude Moove does, how to use it, and what moves.

- **Pack** (laptop you're leaving) shows what can come along, then makes `Claude Moove <date>` on the Desktop. That folder holds both buttons, this engine, the licence, `engine/claude-data.zip` and `engine/manifest.json`. It can then send that folder straight to the new laptop (see [Sending over the internet](#sending-over-the-internet-croc)).
- **Unpack** (laptop you're moving to) shows what will come in and what changed on both laptops, then restores the data and merges it with whatever is already there.
- **The Claude skill** runs both without screens, and lets Claude merge files that changed on both laptops (see [Running it without screens](#running-it-without-screens-the-claude-skill)).

## Starting it

- **The one-liner** pipes `../moove.ps1` into `iex`. It downloads the repo's `main` branch zip with `Invoke-WebRequest` into `%LOCALAPPDATA%\Claude Moove`, replacing any older copy, then runs the engine with `-Mode menu`. Nothing passes through a browser, so the files carry no download mark and Windows shows no SmartScreen warning.
- **From a clone,** `powershell -ExecutionPolicy Bypass -File moove.ps1` uses that copy, and any arguments are passed through to the engine.
- **The menu** offers 1 pack up, 2 move in, 3 add the Claude skill. Choice 3 copies `../skills/claude-moove/SKILL.md`, this engine, the buttons and the licence into `~/.claude/skills/claude-moove`, where Claude Code finds it as `/claude-moove`.
- **The buttons** (`1 - PACK ...cmd`, `2 - UNPACK ...cmd`) run the engine directly. PACK copies them into every transfer folder: on a pendrive they're local files, so Windows doesn't flag them. Downloaded through a browser (the release's `claude-moove.zip`, or the repo zip), they do get flagged.
- **The plugin:** `../.claude-plugin/marketplace.json` makes this repo a plugin marketplace with one plugin, `moove` (the repo root). Names starting with `claude-` are reserved for Anthropic, hence `moove`. Its skill is `/moove:claude-moove`, or `/claude-moove` when nothing else has that name.
- **Where unpack finds its data,** in this order:
  1. `-From <folder>`
  2. next to its own engine (started from the transfer folder's button)
  3. a `Claude Moove*` folder with `engine\claude-data.zip`, directly or one level down, on the Desktop, in Downloads or Documents, or at the root of any other drive (pendrives); the newest one is used, and the pick screen offers R to receive one with a code instead
  4. a croc code typed by the user, or `-ReceiveCode`

## The pick screens

Both PACK and UNPACK open on one screen instead of a step-by-step wizard. Everything that applies is ticked. The user types a number to tick or untick it, or a letter for an action, and Enter starts. Q quits without changing anything.

| Kind (`-What` name) | What it covers | Needs Claude closed |
|---|---|---|
| Chats and sessions (`chats`) | `~/.claude/projects/*` without memory, `file-history`, `todos`, `plans`, `uploads`, `history.jsonl`; from `%APPDATA%\Claude`: `claude-code-sessions`, `local-agent-mode-sessions`, `scratch-workspaces`, `git-worktrees.json` | On unpack: the app keeps its session list in memory and writes it back |
| Settings and instructions (`settings`) | The rest of `~/.claude` (`CLAUDE.md`, `settings.json`, hooks, skills, plugins, commands, agents...), `~/.claude.json`, `~/AGENTS.md`, `claude_desktop_config.json` | On unpack, only `.claude.json` and `claude_desktop_config.json`, which a running Claude keeps rewriting |
| Memory (`memory`) | `~/.claude/projects/*/memory` | No |
| Project Claude files (`projects`) | See [Project Claude files](#project-claude-files) | No |
| Sidebar layout (`sidebar`) | `%APPDATA%\Claude\Local Storage` | Yes, on both sides: it's a database the app keeps locked |
| Download missing projects (`download`, unpack only) | `git clone` of project folders that aren't here, into their old (remapped) paths | No |

Never packed: caches, telemetry, live-process files (`sessions`, `session-env`, `shell-snapshots`, `daemon*`) and the login token (`.credentials.json`).

- **PACK actions:** C closes Claude (only the sidebar layout needs it), S or U chooses sending or carrying. It warns about project folders with work that isn't on GitHub yet.
- **UNPACK actions:** C closes Claude, N and G install Node.js and Git with winget, D opens Claude's download page, A checks the account again, R receives over the internet instead. A number after the kinds of data switches a file that changed on both laptops between its choices.
- **Claude open while moving in:** whatever doesn't need Claude closed comes in first. Then the window says "Close Claude now", waits, and brings in the rest the moment Claude is gone (C closes it, S skips; a later move-in only adds what's missing).

## Project Claude files

PACK looks at the project folders the Code tab sessions use (each session's folder, or the root of its git repo) for:
- `CLAUDE.md`, `CLAUDE.local.md` and `AGENTS.md` at the project root
- everything under `.claude/`, except `.claude/worktrees` (whole copies of the project) and files of 5 MB or more

In a git repo only files GitHub doesn't have are packed: untracked, ignored, or changed since the last commit. In other folders all of them are. They go into the zip under `projects/<n>/`, and `manifest.json` lists them per project (`claudeFiles`, `slot`).

UNPACK puts them into the project's folder on this laptop, with paths rewritten (see [Paths that don't match](#paths-that-dont-match)). If the folder isn't here, they wait: it says so, and a later move-in, after the project is downloaded or copied, brings them.

## How unpack merges

- **Chats.** Transcript files only ever grow, so if one laptop's copy is the start of the other's, the longer one wins. If both grew differently, meaning the same chat was used on both laptops, both are kept. This laptop's copy stays as it is. The other is added as a separate chat with a new ID, and its Code tab entry is titled "... (other laptop)".
- **Code tab session list.** Each entry follows its chat. If one side rewound or forked into a new chat file, the side that moved on from an untouched copy of the other counts as newer. Anything archived on either laptop stays archived.
- **Files people care about** (`~/.claude/CLAUDE.md`, `~/AGENTS.md`, `~/.claude/settings.json`, and every project Claude file). New ones are copied. One that exists on both sides and differs is never overwritten blindly; it gets a choice:
  - `mine`: keep this PC's.
  - `theirs`: take the old laptop's. This PC's is saved in the safety folder first.
  - `both`: keep this PC's in use and put the old laptop's next to it as `<name>.from-<old PC><ext>`. Claude gets a one-time note at the next session to offer merging them. Only offered where a spare copy changes nothing: instruction files and `.json`.
  - a merged file (only through `-Choices`): it replaces this PC's, which is saved first.

  The suggested choice: on a brand-new install, or for a project file whose copy here is exactly what's committed to git, `theirs`. Otherwise `both` for `.md` files that allow it, and the newer file for the rest. A difference that was settled once (the marker remembers the old laptop's version by hash) isn't asked about again.
- **Other settings** (`.claude.json`, plugin lists, app preferences, other files at the top of `~/.claude`). The newer file wins, except on a brand-new install, where the packed ones win because what's there is just the install's defaults. Every replaced file is saved first in `~/.claude-moove-safety/<date>/`.
- **Brand-new or lived-in.** A PC counts as lived-in when it already has more than one chat or Code tab session of its own. One doesn't count: it may be the chat running the Claude skill. A lived-in PC is only ever merged into, and the pick screen says so. A brand-new install (not lived-in, never packed or unpacked before) takes the packed settings and sidebar layout as they are. A move that is still waiting for Claude to close keeps counting as brand-new for its second run (`freshInstall` in the marker).
- **Sidebar layout** (the app's Local Storage database). It can't be mixed, so it comes in whole. It's ticked by default only on a brand-new install or a PC without one; ticking it on a lived-in PC replaces this PC's layout, which is moved to the safety folder first. Sessions all still show up either way; only grouping and pins are layout.
- **Everything else** merges file by file, and never overwrites a newer file.
- **Merge notes.** `~/.claude/claude-moove/pending-merges.json` holds one-time notes, and `claude-moove-merge.mjs` is registered as a SessionStart hook to deliver them:
  - for a chat continued on both laptops, keyed by its session ID: the first time either copy is opened, Claude gets the other copy's messages from after the split
  - for files kept in both versions, under `*`: the first session that starts gets the list and offers to merge them

  The user sees a short message, and each note is deleted once delivered. With no notes waiting, the hook exits immediately.
- `%APPDATA%\Claude\claude-moove-synced.json` marks a laptop that has packed or moved in before. It also remembers settled differences (`resolved`) and `freshInstall`.

## Paths that don't match

Unpack may find that the Windows user folder, Desktop (for example one moved into OneDrive), Documents or AppData differ from the old laptop's. If so, it rewrites old paths to new ones in:
- session lists and settings, including hook commands
- `CLAUDE.md`, `AGENTS.md` and plugin lists
- project Claude files (`.md` and `.json`)
- app preferences and pending notes
- the names of the transcript folders that Claude derives from each path (`C:\Users\Alex\Desktop\x` becomes `C--Users-Alex-Desktop-x`)

Matching is case-insensitive and never inside a longer name, so `Alex` doesn't match `Alexander` or `Alex.LAPTOP`.

## Running it without screens (the Claude skill)

`../skills/claude-moove/SKILL.md` tells Claude how to drive the engine. These switches make that possible:

| Switch | Does |
|---|---|
| `-Yes` | No questions: take the defaults. Never closes Claude or installs anything (croc included; a missing croc becomes a warning). |
| `-Json` | No screens. The result is one line, `MOOVE-JSON:{...}`, with `ok`, and `error` on failure. |
| `-What <kinds>` | Only these kinds, comma-separated: `chats,settings,memory,projects,sidebar,download`. |
| `-From <folder>` | Unpack: the transfer folder to use. |
| `-Plan` | Unpack: report what would happen and change nothing (implies `-Json`). Each file changed on both laptops is listed with its `id` (the path on this PC), `mine`, `theirs` (a copy of the old laptop's version, paths rewritten, under `%TEMP%\claude-moove-review\<date>`), `newer`, `suggested` and the allowed `choices`. Also `livedIn`, `freshInstall`, `account`, `paths`, `missingProjects` and `waitsForClaudeToClose`. |
| `-Choices <file>` | Unpack: a JSON object mapping a file's `id` to `mine`, `theirs`, `both` or the path of a merged file. Files left out get the suggested choice. |
| `-WhenClosed` | Unpack: skip the pick screen, wait until Claude is closed, then bring in `-What`. |

- Pack's result has `folder`, `mb`, `what` (what was packed), `skipped` (the sidebar layout when Claude was open) and `sent`. With `-Transfer send` it also prints `MOOVE-CODE:<code>` as soon as croc has a code.
- Unpack's result has `moved`, `waiting`, `sessions` (`added`, `updated`, `unchanged`, `usedOnBoth`), `choices`, `downloaded` and `safetyFolder`. While Claude is open (it is, when the skill runs) `waiting` lists the kinds that need it closed. The engine then opens a small window with `-WhenClosed` (`finishWindow: true`), which brings them in the moment the user quits Claude.

## Sending over the internet (croc)

The pack screen offers sending (S) or carrying (U). UNPACK receives when it can't find a packed folder, or when the user presses R (see [Starting it](#starting-it)).

- It uses [croc](https://github.com/schollz/croc) (MIT), version 10 or newer. If it's missing or too old, it is installed or upgraded with `winget` (`schollz.croc`), and only after the user agrees.
- The transfer is end to end encrypted with the one-time code (a password-authenticated key exchange), and neither laptop opens a port. On the same network the two connect directly. Otherwise they meet on one of croc's relays: the sender picks the fastest one, and that choice is baked into the code.
- **Send:** `croc --ignore-stdin --disable-clipboard --internal-dns send "<folder>"`. The code is read from the `getcroc.com/?code=` line croc prints. The window shows the code and the steps for the new laptop, then Clawd walks while it sends.
- **Receive:** `croc --ignore-stdin --yes --overwrite --internal-dns --out "<Desktop>\Claude Moove received <date>" <code>`.
  - The code must be letters, digits and dashes (5 to 64 characters), so it can never be read as a croc option.
  - On Windows croc takes the code as an argument; `CROC_SECRET` is ignored when receiving.
  - The attempt gives up after 2 minutes with no progress.
  - The received folder stays on the Desktop until the user deletes it.
- **Why `--internal-dns` comes first:** croc gives a relay lookup only about 1 second, and Windows' own lookup can take longer. If that first attempt fails, a second one uses Windows' lookup, for networks that block outside DNS.
- **One shot:** a sender that sees a failed attempt with its code may stop waiting, so a broken transfer means running PACK again for a fresh code.
- On failure, both sides show croc's last message, and the relay's "rate limited" answer gets its own "wait a minute" hint.

## Testing without touching real data

- **Screens only:** `powershell -File engine\claude-moove.ps1 -Mode preview` draws each screen once.
- **Unattended runs:** add `-Test`. Point `-HomeDir`, `-AppDataDir`, `-DesktopDir` and `-DocumentsDir` at a throwaway folder that contains `AppData\Roaming\Claude\config.json` with a `lastKnownAccountUuid`. Use `-OutDir` to choose where pack puts its folder.
  - Nothing is closed, opened or installed in test runs. Claude counts as open while `test-claude-open` exists in the fake `AppData\Roaming\Claude`; "closing" it deletes that file.
  - Pick screens read typed answers from redirected input, one per line (`'2', 'C', '' | powershell -File ...`), and an empty answer when the input runs out, which starts with the defaults.
  - Pack carries rather than sends unless you add `-Transfer send`; it then prints `MOOVE-CODE:<code>` for the test to pick up. Unpack takes that code through `-ReceiveCode`.
  - On failure the message also says where in the script it broke.
- **Cases worth covering:**
  - a fresh laptop with a different user name and a OneDrive Desktop
  - a second unpack where one chat is newer on each side and one chat was continued on both
  - the merge hook, run by hand with a SessionStart input for each copy, and for a file note with any session ID
  - sending: pack a tiny fake profile with `-Transfer send`, then unpack from a fresh copy of the tool (no data) with `-ReceiveCode` into another fake profile
  - a lived-in destination: its own chat, settings and sidebar layout must survive
  - project Claude files: committed-then-changed, ignored and untracked files in a git repo, a non-git folder, a `.claude/worktrees` copy that must stay behind, and a project missing on the new laptop
  - files changed on both laptops: `-Plan`, then `-Choices` with a merged file, `mine` and `both`, then a second `-Plan` that asks nothing
  - Claude open: the pick screen with C typed at the wait, and `-Yes` followed by a `-WhenClosed` run
  - the launcher from a clone (`moove.ps1 -Mode unpack -Test ...`), with a packed folder on the fake Desktop that unpack must find by itself; `-Mode menu -Test` must change nothing, and typing 3 must install the skill into the fake profile

## Files

| File | Job |
|---|---|
| `../moove.ps1` | The one-line launcher: fetch the latest copy (or use the clone), then open the menu |
| `claude-moove.ps1` | Does all the work: `-Mode menu`, `pack`, `unpack` or `preview` |
| `claude-moove-merge.mjs` | The one-time merge note hook, plus `--install [settings.json]` to register it |
| `../skills/claude-moove/SKILL.md` | The Claude skill: how Claude drives the engine and merges files changed on both laptops |
| `../.claude-plugin/` | `marketplace.json` and `plugin.json`, so the repo installs as the `moove` plugin |
| `manifest.json` (packed folders only) | Where things lived on the old laptop, the account, what was packed, and the project folders with their GitHub links and Claude files |
| `claude-data.zip` (packed folders only) | The data |

## Known limits

- Windows only. The screens need a console that understands colour codes; Windows Terminal is best.
- Project folders are not packed, only their Claude files. The folders come from GitHub, or you copy them yourself, which keeps uncommitted work.
- Only project Claude files at the root and under `.claude/` travel; a `CLAUDE.md` deeper inside a project doesn't.
- Moving in needs the Claude desktop app installed and opened once.
- The skill runs inside Claude, so it can't close it: the chats and sidebar layout come in through the small window once the user quits Claude, and the sidebar layout only packs from the window with Claude closed.
- It relies on Claude's internal file layout, which can change between versions. Do a trial unpack before wiping the old laptop.
