---
name: claude-moove
description: Move everything Claude (chats and Code tab sessions, global CLAUDE.md, settings, hooks, skills, plugins, memory, and projects with the files GitHub doesn't have, like .env files and uncommitted work) from one Windows laptop to another with Claude Moove, and merge files that changed on both laptops instead of overwriting them. Use when the user wants to pack up their Claude stuff or projects for a new laptop, move in or import Claude data on a new or second PC, send their chats to another computer, or bring CLAUDE.md and chats together from two laptops.
argument-hint: "[pack | move in]"
---

# Claude Moove

Claude Moove carries everything Claude between Windows laptops, projects included. You run its engine without screens, let the user pick what comes along, and when a file changed on both laptops you read both versions and merge them, so the user doesn't have to.

## The engine

It is `${CLAUDE_SKILL_DIR}/engine/claude-moove.ps1` when installed as a personal skill, or `${CLAUDE_SKILL_DIR}/../../engine/claude-moove.ps1` when installed as the `moove` plugin. Use whichever exists, always like this:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<engine>" -Mode <pack|unpack> -Yes -Json [flags]
```

- `-Yes -Json`: no questions or screens, and it never closes Claude or installs anything. The last line of output is `MOOVE-JSON:{...}` with the result: `ok`, plus `error` when it failed, and `warnings`. Never run it without `-Yes -Json`, because the interactive screens wait for keys.
- `-Plan`: look only, change nothing. Works for pack and unpack.
- `-What <kinds>`: only these, comma-separated: `chats,memory,instructions,settings,hooks,skills,plugins,sidebar,projects`. The default is everything that applies. Hooks and plugins are separate from settings: leaving out `hooks` keeps their switches out of settings.json too.
- `-Projects "<name>=<mode>,..."`: per project (`*` means all). Pack modes: `all` (GitHub projects: GitHub + local files; other folders: the whole folder), `github` (downloaded again from GitHub, without local files), `claude` (only its Claude files), `none`. Move-in modes: `all`, `github`, `none`.
- Pack: `-Transfer usb` (default) makes a `Claude Moove <date>` folder on the Desktop. `-Transfer send` also sends it with croc and prints `MOOVE-CODE:<code>` as soon as the code exists, then waits until the other laptop has everything.
- Unpack: `-From "<folder>"` names the packed folder (otherwise it searches the Desktop, Downloads, Documents and plugged-in drives). `-ReceiveCode <code>` receives one with croc instead. `-Choices "<file.json>"` settles the files that changed on both laptops.

Both laptops need Claude Moove: this skill, or the one-line command `irm https://raw.githubusercontent.com/paulgegenyi/claude-moove/main/moove.ps1 | iex` in PowerShell.

## How projects travel

A project is any folder the user chatted in (the git repo's top folder when it's in one). For a GitHub project the new laptop downloads it again, gets back the commits that weren't pushed and the branch it was on, and then the old laptop's local files go on top: everything GitHub doesn't have (git-ignored files like `.env`, untracked files, uncommitted changes). Folders that aren't on GitHub come along whole. Rebuildable folders (node_modules, .venv, build output) never travel. Projects with more than 300 MB of local files start as `github` (or `claude`); their size shows as `overLimit`.

## Packing up (the laptop the user is leaving)

1. Run pack with `-Plan`. Tell the user briefly what can come along (`what`) and list the projects: name, what would happen (`mode`), local files and size (or "over 300 MB" when `overLimit`), a few names (`sample`), and commits not on GitHub. Ask which projects they want and how, and whether they want hooks, plugins and the rest, unless they already said "everything".
2. Ask how it should travel, if they haven't said: a folder they carry (USB stick, cloud drive), or sent over the internet with a one-time code. For sending, both laptops must be on at the same time, and croc's free relay allows 5 transfers an hour per internet connection; on a shared network (office, school, hotel) it can refuse. Then carrying is the way.
3. Run pack with their choices (`-What`, `-Projects`, `-Transfer`). To send, run it in the background and watch its output for `MOOVE-CODE:`. Give the user the code and tell them to start the move-in on the new laptop with it, then wait for the result. Sending needs croc 10 or newer; if a warning says it's missing, offer to install it (`winget install schollz.croc`) and run pack again.
4. Report what was packed, the folder and its size, and the projects. Go through `warnings`. `skipped: sidebar` means the sidebar layout (grouping and pins) stayed behind because Claude is open. It's cosmetic; every session still shows up. If they want it, they can quit Claude and pack again with the window (`1 - PACK` in the transfer folder).
5. Remind them the folder holds their full chat history and their projects' local files (like `.env` secrets): keep it private, and delete it once the new laptop is set up.

## Moving in (the new laptop)

1. Run unpack with `-Plan` (and `-From` or `-ReceiveCode` if needed). A received folder lands on the Desktop; use `-From` with its path (the plan's `folder`) from then on.
2. Tell the user briefly what the plan says:
   - where it came from, and whether this PC already has chats of its own (`livedIn`: they're kept, the rest merges in)
   - the account check, and any path changes
   - what comes in, and per project what happens (`here` means it's already on this PC; otherwise it's downloaded or copied, with its `files` and `commits`)

   Ask before downloading many projects.
3. For each entry in `conflicts`, read `mine` (this PC's file, in use) and `theirs` (a copy of the old laptop's version), then decide:
   - One contains everything the other has, or they say the same thing: choose that one (`mine` or `theirs`).
   - Each has something the other lacks: write a merged file into the review folder next to `theirs` and use its path. Keep every instruction from both, drop duplicates, keep this PC's wording where both say the same thing, and fix paths to this PC's. For JSON settings, combine the keys (union hooks, permissions and plugin lists) and keep it valid JSON.
   - They truly contradict each other: ask the user which way to go.
   - `both` keeps this PC's version in use and saves the old laptop's next to it as `<name>.from-<PC>`. Use it only if the user wants to merge later.

   Entries with a `group` are the other files of a project that's already here (code, `.env` and such). Settle them together with the group's id (`<project path>\*`): `mine` keeps this PC's copies, `theirs` takes the old laptop's. Read individual ones only if the user asks; secrets like `.env` usually stay `mine` unless the user says otherwise. Tell the user in one line per file or group what you'll do, and wait for a yes on anything that isn't obvious.
4. Write the choices as a JSON object, `{ "<id>": "mine" | "theirs" | "both" | "<path of merged file>" }`, using the ids exactly as given. Then run unpack with `-Yes -Json -From "<folder>" -Choices "<that file>"`, plus `-What` and `-Projects` if the user left anything out.
5. Report what came in:
   - sessions added, updated, unchanged and used on both laptops
   - the projects set up
   - the choices
   - the safety folder (everything replaced is saved there first)
   - `warnings`

   For a project that was already here, commits that weren't on GitHub arrive as `old-laptop/<branch>` branches: offer to merge them.
6. If `waiting` isn't empty, the chats and sidebar layout haven't come in yet, because Claude is open (you're running in it). With `finishWindow: true`, a small Claude Moove window opened and waits. Tell the user to quit Claude completely (right-click its icon near the clock, then Quit), and the rest comes in right away. Then they open Claude again. If that window isn't there, or `finishWindow` is false, they quit Claude and run the move-in again (`2 - UNPACK` in the transfer folder, or the one-line command then 2). It only adds what's missing.

## Good to know

- Nothing is lost on either side:
  - Chats are only replaced by longer versions of themselves.
  - A chat continued on both laptops is kept twice, and the other copy is titled "(other laptop)".
  - Replaced settings and files are saved in `~/.claude-moove-safety/<date>` first.
- Login tokens never travel; the user signs in on the new laptop with the same account.
- How it all works in detail: `engine/README.md` next to the engine.
