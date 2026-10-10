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
  3. a `Claude Moove*` folder with `engine\claude-data.zip`, directly or one level down, on the Desktop, in Downloads or Documents, or at the root of any other drive (pendrives). The newest one is offered first: the window says where it is and which laptop packed it when, then Enter uses it, R receives one with a code instead, and Q quits without changing anything. Runs without screens (`-Yes`, `-Json`) use it without asking. The pick screen also offers R.
  4. a croc code typed by the user, or `-ReceiveCode`

## The pick screens

Both PACK and UNPACK open on one screen instead of a step-by-step wizard. Everything that applies is ticked, and kinds with nothing in them don't show. The user types a number to tick or untick something, or a letter for an action, and Enter starts. Q quits without changing anything.

| Kind (`-What` name) | What it covers | Needs Claude closed |
|---|---|---|
| Chats and sessions (`chats`) | `~/.claude/projects/*` without memory, `file-history`, `todos`, `plans`, `uploads`, `history.jsonl`; from `%APPDATA%\Claude`: `claude-code-sessions`, `local-agent-mode-sessions`, `scratch-workspaces`, `git-worktrees.json` | On unpack: the app keeps its session list in memory and writes it back |
| Memory (`memory`) | `~/.claude/projects/*/memory` | No |
| Instructions (`instructions`) | `~/.claude/CLAUDE.md`, `~/AGENTS.md`, `~/.claude/rules` | No |
| Settings (`settings`) | `settings.json` (apart from the hooks' and plugins' switches), the rest of `~/.claude` (`settings.local.json`, scheduled tasks, ...), `~/.claude.json`, `claude_desktop_config.json` | On unpack, only `.claude.json` and `claude_desktop_config.json`, which a running Claude keeps rewriting |
| Hooks (`hooks`) | `~/.claude/hooks`, and `hooks` in `settings.json` | No |
| Skills, commands, agents (`skills`) | `~/.claude/skills`, `commands`, `agents`, `output-styles` | No |
| Plugins (`plugins`) | `~/.claude/plugins`, and `enabledPlugins` and `extraKnownMarketplaces` in `settings.json` | No |
| Sidebar layout (`sidebar`) | `%APPDATA%\Claude\Local Storage` | Yes, on both sides: it's a database the app keeps locked |
| Projects (`projects`) | See [Projects](#projects); its number opens the projects screen | No |

Never packed: caches, telemetry, live-process files (`sessions`, `session-env`, `shell-snapshots`, `daemon*`) and the login token (`.credentials.json`).

- **settings.json is put together per part.** PACK leaves out the switches of unticked parts (`hooks`, plugins), or packs only the ticked parts' switches when Settings is unticked. UNPACK builds two versions:
  - `theirs`: the rest of the file from the side Settings says, the hooks from the old laptop if Hooks is ticked (else this PC keeps its own), and the same for the plugin switches.
  - `combined`: the rest of the file combined (see [How unpack merges](#how-unpack-merges)). If Hooks is ticked, the old laptop's hooks come in as a whole set; this PC's stay only if the old laptop has none. If Plugins is ticked, the plugin switches and marketplaces are combined one by one.

  With Settings unticked but Hooks or Plugins ticked, those switches go into this PC's settings.json (saved first), combined the same way.
- **PACK actions:** C closes Claude (only the sidebar layout needs it), S or U chooses sending or carrying. The send line says both laptops must be on and croc's free relay allows 5 sends an hour per internet connection.
- **UNPACK actions:** C closes Claude, N and G install Node.js and Git with winget, D opens Claude's download page, A checks the account again, R receives over the internet instead. A number after the kinds of data switches a file (or a project's group of files) that changed on both laptops between its choices.
- **Claude open while moving in:** whatever doesn't need Claude closed comes in first. Then the window says "Close Claude now", waits, and brings in the rest the moment Claude is gone (C closes it, S skips; a later move-in only adds what's missing).

## Projects

**What counts as a project:** every folder a chat ran in. That's each Code tab session's folder (from `claude-code-sessions`) plus each terminal chat's, read from the `cwd` in the first lines of one transcript per `~/.claude/projects` folder. Inside a git repo, the project is the repo's top folder. A linked worktree (`--git-dir` differs from `--git-common-dir`) counts as its main checkout, so the app's `.claude/worktrees/*` sessions don't become projects of their own. Left out: the user folder itself, `~/.claude`, `%APPDATA%\Claude` (scratch workspaces) and `AppData\Local\Temp`. Folders that no longer exist are skipped.

**Kinds and choices** (the projects screen cycles a project's choice with its number; A sets all to their first choice, N to none):

| Kind | When | Choices (`-Projects` mode) |
|---|---|---|
| `git` | a git repo with an `origin` remote | GitHub + local files (`all`), GitHub only (`github`), left behind (`none`) |
| `local` | no git, or git without a remote | whole folder (`all`), Claude files only (`claude`), left behind (`none`) |
| `special` | the Desktop, Documents, Downloads or a drive root | Claude files only (`claude`), left behind (`none`); listed only if it has Claude files |

- **Local files** of a git project are what GitHub doesn't have: `git ls-files --others` (untracked), `--others --ignored` (git-ignored) and `--modified` (changed or deleted since the last commit). Whole untracked or ignored folders are copied in one go. Deleted files are listed in the manifest, so the new laptop deletes them too.
- **Commits that aren't on GitHub** (`git rev-list --branches --not --remotes`) travel as a git bundle of every local branch, `projects/<n>.bundle`, in both `all` and `github` modes. The manifest records the branch and commit the old laptop had checked out.
- **Never travels:** rebuildable folders (`node_modules`, `.venv`, `venv`, `__pycache__` and other caches, `.next`, `.nuxt`, `.gradle`, `.terraform`, `.vs`, `Pods` and the like; in git projects also `dist`, `build`, `target`, `coverage` and `out`), transfer folders (`Claude Moove*`), `.claude/worktrees`, and Claude's `.claude/*.lock` files. A whole-folder project leaves out other projects inside it.
- **Size:** files are counted only up to 300 MB per project, so the screen stays quick. A project over that starts as `github` (or `claude`), and the screen says "over 300 MB".
- **Claude files** (for `claude` mode): `CLAUDE.md`, `CLAUDE.local.md` and `AGENTS.md` at the root and everything under `.claude/` (no worktrees, lock files or files of 5 MB and over). In a git repo only those GitHub doesn't have.
- Files go into the zip under `projects/<n>/`; `manifest.json` describes each project (`kind`, `mode`, `remote`, `branch`, `head`, `slot`, `count`, `size`, `bundle`, `ahead`, `deleted`, `claudeFiles`).

**Moving in**, per project, to its old path with the new user folder (see [Paths that don't match](#paths-that-dont-match)):
- **Not here, GitHub project:** `git clone` (needs Git; test runs only clone remotes that are local folders), then `git fetch --update-head-ok <bundle> +refs/heads/*:refs/heads/*`, then `git checkout -f -B <branch> <head>` with `origin/<branch>` as its upstream if that exists, then the local files on top (they win: it's a fresh copy), then the deleted files removed. In `github` mode the local files and deletions are left out. If the bundle can't be fetched, it's saved in the safety folder.
- **Not here, other folder:** the whole folder is copied. If only Claude files came, they wait: the end screen names the folders to copy over (one by one up to three, else summed up in one line), and a later move-in brings them.
- **Already here:** new files are copied. Differences in Claude files (root instruction files and `.claude/`) are settled one by one, like global files. All other differing files of a project form one group with one choice: keep this PC's (the default) or take the old laptop's (suggested only when this PC's copies are all exactly what's committed). Commits that weren't on GitHub arrive as `old-laptop/<branch>` remote branches, never touching this PC's branches.

## How unpack merges

- **Chats.** Transcript files only ever grow, so if one laptop's copy is the start of the other's, the longer one wins. If both grew differently, meaning the same chat was used on both laptops, both are kept. This laptop's copy stays as it is. The other is added as a separate chat with a new ID, and its Code tab entry is titled "... (other laptop)".
- **Code tab session list.** Each entry follows its chat. If one side rewound or forked into a new chat file, the side that moved on from an untouched copy of the other counts as newer. Anything archived on either laptop stays archived. A session file that can't be read (all zeros after a crash, say) is skipped, as the app does, with a warning: the old laptop's isn't brought in, a damaged one here is replaced by the old laptop's copy if it has one, and a damaged archive list counts as empty.
- **Files people care about** (`~/.claude/CLAUDE.md`, `~/AGENTS.md`, `~/.claude/settings.json`, and the files of projects already here). New ones are copied. One that exists on both sides and differs is never overwritten blindly; it gets a choice:
  - `combine` (settings.json only): the combined version, described below. This PC's is saved in the safety folder first.
  - `mine`: keep this PC's.
  - `theirs`: take the old laptop's exactly. This PC's is saved in the safety folder first.
  - `both`: keep this PC's in use and put the old laptop's next to it as `<name>.from-<old PC><ext>`. Claude gets a one-time note at the next session to offer merging them. Only offered where a spare copy changes nothing: global files, and project `.md`, `.json` and `.env*` files outside `.claude/commands`, `agents`, `skills`, `rules` and `output-styles`.
  - a merged file (only through `-Choices`): it replaces this PC's, which is saved first.

  The suggested choice: `combine` for settings.json. On a brand-new install (global files only), or for a project file whose copy here is exactly what's committed to git, `theirs`. Otherwise `both` for `.md` files that allow it, and the newer file for the rest. A file that already matches either version counts as the same. A difference that was settled once (the marker remembers the old laptop's version by hash; for settings.json the file as packed, before it's put together) isn't asked about again.
- **Combining a JSON settings file.** The old laptop wins wherever both have the same setting, and whatever only this PC has stays:
  - Objects are combined key by key, at every level: each folder in `.claude.json`'s `projects`, each MCP server, each plugin.
  - Lists that are sets hold both laptops' entries, each once, the old laptop's first: `allow`, `deny`, `ask`, `additionalDirectories`, `allowedTools`, `enabledMcpjsonServers`, `disabledMcpjsonServers`, `starred-local-code-sessions` and `launchPreviewAllowedOrigins`. Any other list depends on its order (an MCP server's `args`, say), so it comes whole from the old laptop.
  - A `has...` flag that's true here stays true, so a folder trusted here stays trusted and finished onboarding stays finished.
  - This PC's own keys never come from the old laptop, and are left out when this PC has none. In `.claude.json`: `userID`, `machineID`, `anonymousId`, `oauthAccount`, `installMethod`, `autoUpdates`, `autoUpdatesProtectedForNative`, `firstStartTime` and `migrationVersion` (how far this PC's Claude has updated the file). In `claude_desktop_config.json`: `preferences.remoteToolsDeviceName` and `preferences.chromeExtension`.
  - Files are read into case-sensitive dictionaries, because `ConvertFrom-Json` refuses a `.claude.json` that holds two folders whose names differ only in case (Claude writes those). They are written back with two-space indents and only the escapes JSON needs, so the result matches what Claude writes. Hidden and read-only files are written too, and keep those attributes.
  - Known limits: the reader turns half an emoji on its own (already a broken character) into the replacement character, and whole numbers beyond about 7.9e28 lose precision.
- **Other settings** (`.claude.json`, plugin lists, app preferences, `git-worktrees.json`, other `.json` files at the top of `~/.claude`) are combined without asking, also on a brand-new install. The marker remembers each old-laptop version once it's combined, so a later move-in from the same pack leaves alone whatever changed here since. The newer copy wins instead (on a brand-new install the packed one) for a file that isn't JSON, can't be read as JSON, or whose top-level `version` differs between the laptops (two formats of the same file). Every replaced file is saved first in `~/.claude-moove-safety/<date>/`.
- **A settings.json this PC can't read** (a comment or a stray comma, say) is never combined or added to: with Settings ticked it's kept or replaced whole (the choice offers `mine`, `theirs` and `both`), with only Hooks or Plugins ticked it's left as it is, and either way a warning says so. settings.json is put together again just before it's written, so changes made while the move waited for Claude to close aren't lost.
- **Prompt history** (`history.jsonl`): both laptops' lines, each once, in time order.
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
- project files that are `.md`, `.json` or `.jsonl`
- app preferences and pending notes
- the names of the transcript folders that Claude derives from each path (`C:\Users\Alex\Desktop\x` becomes `C--Users-Alex-Desktop-x`)

Matching is case-insensitive and never inside a longer name, so `Alex` doesn't match `Alexander` or `Alex.LAPTOP`.

## Running it without screens (the Claude skill)

`../skills/claude-moove/SKILL.md` tells Claude how to drive the engine. These switches make that possible:

| Switch | Does |
|---|---|
| `-Yes` | No questions: take the defaults. Never closes Claude or installs anything (croc included; a missing croc becomes a warning). |
| `-Json` | No screens. The result is one line, `MOOVE-JSON:{...}`, with `ok`, and `error` on failure. |
| `-What <kinds>` | Only these kinds, comma-separated: `chats,memory,instructions,settings,hooks,skills,plugins,sidebar,projects`. |
| `-Projects <list>` | Per project, `name=mode` (or a path instead of the name; `*` for all), comma-separated. Pack modes: `all`, `github`, `claude`, `none`. Move-in modes: `all`, `github`, `none`. |
| `-From <folder>` | Unpack: the transfer folder to use. |
| `-Plan` | Look only and change nothing (implies `-Json`). Pack: `what` (each kind with `on` and `detail`) and `projects` (`kind`, `mode`, `modes`, `localFiles`, `size`, `overLimit`, `sample`, `claudeFiles`, `commitsNotOnGitHub`). Unpack: each file changed on both laptops with its `id` (the path on this PC), `mine`, `theirs` (a copy of the old laptop's version, paths rewritten, under `%TEMP%\claude-moove-review\<date>`), `combined` (for settings.json, a copy of the combined version), `newer`, `suggested`, the allowed `choices` and its `group`; `groups` (`<project path>\*`, `suggested`); `projects` (`here`, `kind`, `mode`, `modes`, `files`, `size`, `commits`); also `livedIn`, `freshInstall`, `account`, `paths` and `waitsForClaudeToClose`. |
| `-Choices <file>` | Unpack: a JSON object mapping a file's `id` to one of its `choices` (`combine`, `mine`, `theirs`, `both`) or the path of a merged file, and a group's `<project path>\*` to `mine` or `theirs`. Anything left out gets the suggested choice. |
| `-WhenClosed` | Unpack: skip the pick screen, wait until Claude is closed, then bring in `-What`. |

- Pack's result has `folder`, `mb`, `what` (what was packed), `skipped` (the sidebar layout when Claude was open), `projects` (`mode`, `files`, `size`, `commits`) and `sent`. With `-Transfer send` it also prints `MOOVE-CODE:<code>` as soon as croc has a code.
- Unpack's result has `moved`, `waiting`, `sessions` (`added`, `updated`, `unchanged`, `usedOnBoth`), `projects`, `choices`, `groups` and `safetyFolder`. While Claude is open (it is, when the skill runs) `waiting` lists the kinds that need it closed. The engine then opens a small window with `-WhenClosed` (`finishWindow: true`), which brings them in the moment the user quits Claude.

## Sending over the internet (croc)

The pack screen offers sending (S) or carrying (U). UNPACK receives when it can't find a packed folder, or when the user presses R (see [Starting it](#starting-it)).

- It uses [croc](https://github.com/schollz/croc) (MIT), version 10 or newer. If it's missing or too old, it is installed or upgraded with `winget` (`schollz.croc`), and only after the user agrees.
- The transfer is end to end encrypted with the one-time code (a password-authenticated key exchange), and neither laptop opens a port. On the same network the two connect directly. Otherwise they meet on one of croc's relays: the sender picks the fastest one, and that choice is baked into the code.
- **croc's free relays allow five new transfers per hour from one internet address** (croc's own README). A move needs one or two, but many test runs, or many people behind one address (offices, schools, hotels), hit it: the relay then answers "relay admission rate limited". The receiving window says so plainly and suggests waiting, a phone hotspot, or carrying the folder; the sending window says to carry the folder if the new laptop can't connect.
- **Send:** `croc --ignore-stdin --disable-clipboard --internal-dns send "<folder>"`. The code is read from the `getcroc.com/?code=` line croc prints. The window shows the code and the steps for the new laptop, then Clawd walks with a status read from croc's output:
  - "Getting the folder ready" while croc fingerprints the files (its `Hashing` lines, at disk speed; nothing has left the laptop yet)
  - "Waiting for the new laptop to type the code" from then on
  - "Sending to the new laptop" only after croc names both ends of the connection (`Sending (<this laptop>-><new laptop>)`), with the current file's percentage and speed. The packed zip is nearly all of the folder, so its percentage is the one that matters.
- **Receive:** `croc --ignore-stdin --yes --overwrite --internal-dns --out "<Desktop>\Claude Moove received <date>" <code>`.
  - The code must be letters, digits and dashes (5 to 64 characters), so it can never be read as a croc option.
  - On Windows croc takes the code as an argument; `CROC_SECRET` is ignored when receiving.
  - The attempt gives up after 2 minutes with no progress.
  - The received folder stays on the Desktop until the user deletes it.
- **Why `--internal-dns` comes first:** croc gives a relay lookup only about 1 second, and Windows' own lookup can take longer. If that first attempt fails, a second one uses Windows' lookup, for networks that block outside DNS.
- **One shot:** a sender that sees a failed attempt with its code may stop waiting, so a broken transfer means running PACK again for a fresh code.
- **Testing it** without the public relays: start `croc relay --host 127.0.0.1 --ports 9109,9110,9111,9112,9113` and set `CROC_RELAY=127.0.0.1:9109` and `CROC_PASS=pass123` for both test runs.

## Testing without touching real data

- **Screens only:** `powershell -File engine\claude-moove.ps1 -Mode preview` draws each screen once.
- **Unattended runs:** add `-Test`. Point `-HomeDir`, `-AppDataDir`, `-DesktopDir` and `-DocumentsDir` at a throwaway folder that contains `AppData\Roaming\Claude\config.json` with a `lastKnownAccountUuid`. Use `-OutDir` to choose where pack puts its folder.
  - Nothing is closed, opened or installed in test runs. Claude counts as open while `test-claude-open` exists in the fake `AppData\Roaming\Claude`; "closing" it deletes that file.
  - Pick screens read typed answers from redirected input, one per line (`'2', 'C', '' | powershell -File ...`), and an empty answer when the input runs out, which starts with the defaults.
  - Projects are only cloned when their remote is a local folder, so a bare repo (`git init --bare`) stands in for GitHub.
  - Pack carries rather than sends unless you add `-Transfer send`; it then prints `MOOVE-CODE:<code>` for the test to pick up. Unpack takes that code through `-ReceiveCode`.
  - On failure the message also says where in the script it broke.
- **Cases worth covering:**
  - a fresh laptop with a different user name and a OneDrive Desktop
  - a second unpack where one chat is newer on each side and one chat was continued on both
  - the merge hook, run by hand with a SessionStart input for each copy, and for a file note with any session ID
  - sending: pack a tiny fake profile with `-Transfer send`, then unpack from a fresh copy of the tool (no data) with `-ReceiveCode` into another fake profile
  - a lived-in destination: its own chat, settings and sidebar layout must survive
  - the parts of settings.json: packing without hooks and plugins, moving in Settings without Hooks (this PC's hooks stay), only Hooks (added to this PC's settings), and everything when there are no plugins at all
  - the sending window and a real send: `../tools/test-sending.ps1` checks the status line against croc's output for each stage, then sends a fake laptop's folder to another through a private croc relay on this PC
  - a packed folder already on the new laptop: `../tools/test-found-folder.ps1` checks that move-in asks first, and that Q, R and Enter do what they say
  - combining settings: `../tools/test-settings-merge.ps1` packs a fake laptop and moves it onto a lived-in PC and a brand-new one, and tries `theirs` and `mine`. It checks plugin switches, trusted folders, folder names that differ only in case, this PC's IDs, prompt history, app preferences and `-Plan`, and that a second move-in changes nothing
  - which folders are projects: a terminal-only chat, a session inside a git worktree (its repo is the project), chats in a temp folder and in the user folder (not projects), the Desktop (Claude files only)
  - a GitHub project through a bare repo: unpushed commits on two branches, the checked-out branch, an ignored `.env`, an untracked and a changed file, a deleted file, `node_modules` and `dist` left behind; then the same project already on the new laptop with its own `.env` (group choice), `<project>\*` = theirs, and `-Projects app=github`
  - folders without GitHub: copied whole without `node_modules`, and only their Claude files (four of them summed up in one warning)
  - files changed on both laptops: `-Plan`, then `-Choices` with a merged file, `mine` and `both`, then a second `-Plan` that asks nothing
  - Claude open: the pick screen with C typed at the wait, and `-Yes` followed by a `-WhenClosed` run
  - the pick screens driven by typed input, including the projects screen
  - the launcher from a clone (`moove.ps1 -Mode unpack -Test ...`), with a packed folder on the fake Desktop that unpack must find by itself; `-Mode menu -Test` must change nothing, and typing 3 must install the skill into the fake profile

## Files

| File | Job |
|---|---|
| `../moove.ps1` | The one-line launcher: fetch the latest copy (or use the clone), then open the menu |
| `claude-moove.ps1` | Does all the work: `-Mode menu`, `pack`, `unpack` or `preview` |
| `claude-moove-merge.mjs` | The one-time merge note hook, plus `--install [settings.json]` to register it |
| `../tools/test-*.ps1` | Tests on fake laptops: sending, a folder found on the new laptop, combined settings, damaged session files (see [Testing](#testing-without-touching-real-data)) |
| `../skills/claude-moove/SKILL.md` | The Claude skill: how Claude drives the engine and merges files changed on both laptops |
| `../.claude-plugin/` | `marketplace.json` and `plugin.json`, so the repo installs as the `moove` plugin |
| `manifest.json` (packed folders only) | Where things lived on the old laptop, the account, what was packed, and each project: its kind, choice, GitHub link, branch and commit |
| `claude-data.zip` (packed folders only) | The data, with each project's files under `projects/<n>` and its unpushed commits as `projects/<n>.bundle` |

## Known limits

- Windows only. The screens need a console that understands colour codes; Windows Terminal is best.
- Moving in needs the Claude desktop app installed and opened once.
- The skill runs inside Claude, so it can't close it: the chats and sidebar layout come in through the small window once the user quits Claude, and the sidebar layout only packs from the window with Claude closed.
- Git submodules aren't fetched when a project is downloaded (run `git submodule update --init` afterwards). File names git can only print quoted (control characters and such) stay behind.
- Files deeper than Windows' 260-character path limit are left out of the size count, though robocopy still copies them.
- It relies on Claude's internal file layout, which can change between versions. Do a trial unpack before wiping the old laptop.
