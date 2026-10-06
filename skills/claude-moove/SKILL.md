---
name: claude-moove
description: Move everything Claude (chats and Code tab sessions, global CLAUDE.md, settings, hooks, skills, plugins, memory, and project Claude files that aren't on GitHub) from one Windows laptop to another with Claude Moove, and merge files that changed on both laptops instead of overwriting them. Use when the user wants to pack up their Claude stuff for a new laptop, move in or import Claude data on a new or second PC, send their chats to another computer, or bring CLAUDE.md and chats together from two laptops.
argument-hint: "[pack | move in]"
---

# Claude Moove

Claude Moove carries everything Claude between Windows laptops. You run its engine without screens, and when a file changed on both laptops you read both versions and merge them, so the user doesn't have to.

## The engine

It is `${CLAUDE_SKILL_DIR}/engine/claude-moove.ps1` when installed as a personal skill, or `${CLAUDE_SKILL_DIR}/../../engine/claude-moove.ps1` when installed as the `moove` plugin. Use whichever exists, always like this:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<engine>" -Mode <pack|unpack> -Yes -Json [flags]
```

- `-Yes -Json`: no questions or screens, and it never closes Claude or installs anything. The last line of output is `MOOVE-JSON:{...}` with the result: `ok`, plus `error` when it failed, and `warnings`. Never run it without `-Yes -Json`, because the interactive screens wait for keys.
- `-What chats,settings,memory,projects,sidebar,download`: only these kinds of data. The default is everything that applies.
- Pack: `-Transfer usb` (default) makes a `Claude Moove <date>` folder on the Desktop. `-Transfer send` also sends it with croc and prints `MOOVE-CODE:<code>` as soon as the code exists, then waits until the other laptop has everything.
- Unpack: `-From "<folder>"` names the packed folder (otherwise it searches the Desktop, Downloads, Documents and plugged-in drives). `-ReceiveCode <code>` receives one with croc instead. `-Plan` only reports and changes nothing. `-Choices "<file.json>"` settles the files that changed on both laptops.

Both laptops need Claude Moove: this skill, or the one-line command `irm https://raw.githubusercontent.com/paulgegenyi/claude-moove/main/moove.ps1 | iex` in PowerShell.

## Packing up (the laptop the user is leaving)

1. If the user hasn't said, ask how it should travel: a folder they carry (USB stick, cloud drive), or sent over the internet with a one-time code (both laptops on at the same time).
2. Run pack. To send, run it in the background and watch its output for `MOOVE-CODE:`. Give the user the code and tell them to start the move-in on the new laptop with it, then wait for the result. Sending needs croc 10 or newer; if a warning says it's missing, offer to install it (`winget install schollz.croc`) and run pack again.
3. Report what was packed, the folder and its size. Go through `warnings`. For projects with work that isn't on GitHub yet, offer to commit and push it. `skipped: sidebar` means the sidebar layout (grouping and pins) stayed behind because Claude is open. It's cosmetic, since every session still shows up. If they want it, they can quit Claude and pack again with the window (`1 - PACK` in the transfer folder).
4. Remind them the folder holds their full chat history: keep it private, and delete it once the new laptop is set up.

## Moving in (the new laptop)

1. Run unpack with `-Plan` (and `-From` or `-ReceiveCode` if needed). A received folder lands on the Desktop; use `-From` with its path (the plan's `folder`) from then on.
2. Tell the user briefly what the plan says: where it came from, whether this PC already has chats of its own (`livedIn`: they're kept, the rest merges in), the account check, any path changes, what comes in, and `missingProjects`. Projects with `fromGitHub` are downloaded when `download` is in `-What`. Ask before downloading many.
3. For each entry in `conflicts`, read `mine` (this PC's file, in use) and `theirs` (a copy of the old laptop's version), then decide:
   - One contains everything the other has, or they say the same thing: choose that one (`mine` or `theirs`).
   - Each has something the other lacks: write a merged file into the review folder next to `theirs` and use its path. Keep every instruction from both, drop duplicates, keep this PC's wording where both say the same thing, and fix paths to this PC's. For JSON settings, combine the keys (union hooks, permissions and plugin lists) and keep it valid JSON.
   - They truly contradict each other: ask the user which way to go.
   - `both` keeps this PC's version in use and saves the old laptop's next to it as `<name>.from-<PC>`. Use it only if the user wants to merge later.
   Tell the user in one line per file what you'll do, and wait for a yes on anything that isn't obvious.
4. Write the choices as a JSON object, `{ "<conflict id>": "mine" | "theirs" | "both" | "<path of merged file>" }`, using the ids exactly as given. Then run unpack with `-Yes -Json -From "<folder>" -Choices "<that file>"`.
5. Report what came in: sessions added, updated, unchanged and used on both laptops, the choices, the safety folder (everything replaced is saved there first) and `warnings`.
6. If `waiting` isn't empty, the chats and sidebar layout haven't come in yet, because Claude is open (you're running in it). With `finishWindow: true`, a small Claude Moove window opened and waits. Tell the user to quit Claude completely (right-click its icon near the clock, then Quit), and the rest comes in right away. Then they open Claude again. If that window isn't there, or `finishWindow` is false, they quit Claude and run the move-in again (`2 - UNPACK` in the transfer folder, or the one-line command then 2). It only adds what's missing.

## Good to know

- Nothing is lost on either side. Chats are only replaced by longer versions of themselves. A chat continued on both laptops is kept twice, and the other copy is titled "(other laptop)". Replaced settings are saved in `~/.claude-moove-safety/<date>` first.
- Login tokens never travel; the user signs in on the new laptop with the same account.
- How it all works in detail: `engine/README.md` next to the engine.
