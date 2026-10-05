# How Claude Moove works

Start with the main [README](../README.md) for what Claude Moove does, how to use it, and what moves.

- **1 - PACK** (laptop you're leaving) makes `Claude Moove <date>` on the Desktop. It holds both buttons, this engine, the licence, `engine/claude-data.zip` and `engine/manifest.json`.
- **2 - UNPACK** (laptop you're moving to) restores that data and merges it with whatever is already there. It then leaves a copy of the buttons (without data) in `Claude Moove` on that Desktop for the next move.

## Files

| File | Job |
|---|---|
| `claude-moove.ps1` | Does all the work: `-Mode pack`, `unpack` or `preview` |
| `claude-moove-merge.mjs` | The one-time merge note hook, plus `--install [settings.json]` to register it |
| `manifest.json` (packed folders only) | Where things lived on the old laptop, the account, and the project folders with their GitHub links |
| `claude-data.zip` (packed folders only) | The data |

**Packed:** `~/.claude`, except caches, telemetry, live-process files and `.credentials.json`. Also `~/.claude.json`, `~/AGENTS.md`, and these items from `%APPDATA%\Claude`: `claude-code-sessions`, `local-agent-mode-sessions`, `scratch-workspaces`, `Local Storage` (only when Claude is closed), `claude_desktop_config.json` and `git-worktrees.json`.

## How unpack merges

- **Chats.** Transcript files only ever grow, so if one laptop's copy is the start of the other's, the longer one wins. If both grew differently, meaning the same chat was used on both laptops, both are kept. This laptop's copy stays as it is. The other is added as a separate chat with a new ID, and its Code tab entry is titled "... (other laptop)".
- **Merge note.** For each such pair, a note is saved in `~/.claude/claude-moove/pending-merges.json`, and `claude-moove-merge.mjs` is registered as a SessionStart hook. The first time either copy is opened, Claude gets the other copy's messages from after the split, and the user sees a short message. Each note is then deleted. With no notes waiting, the hook exits immediately.
- **Code tab session list.** Each entry follows its chat. If one side rewound or forked into a new chat file, the side that moved on from an untouched copy of the other counts as newer. Anything archived on either laptop stays archived.
- **Settings and instructions** (`settings.json`, `CLAUDE.md`, `AGENTS.md`, `.claude.json`, plugin lists, app preferences). The newer file wins, except on a laptop's first unpack, where the packed ones win because what's there is a fresh install. Every replaced file is saved first in `~/.claude-moove-safety/<date>/`.
- **Sidebar layout** (the app's Local Storage database). It is swapped whole and only for a newer one, with the old one moved to the safety folder.
- **Everything else** merges file by file, and never overwrites a newer file.
- `%APPDATA%\Claude\claude-moove-synced.json` marks a laptop that has packed or unpacked before.

## Paths that don't match

Unpack may find that the Windows user folder, Desktop (for example one moved into OneDrive), Documents or AppData differ from the old laptop's. If so, it rewrites old paths to new ones in:
- session lists and settings, including hook commands
- `CLAUDE.md`, `AGENTS.md` and plugin lists
- app preferences and pending notes
- the names of the transcript folders that Claude derives from each path (`C:\Users\Alex\Desktop\x` becomes `C--Users-Alex-Desktop-x`)

Matching is case-insensitive and never inside a longer name, so `Alex` doesn't match `Alexander` or `Alex.LAPTOP`.

## Checks along the way

- **PACK** closes Claude, then warns about project folders whose work isn't on GitHub yet.
- **UNPACK** checks that Claude is installed (opening the download page if not) and that you're signed in to the same account, then closes Claude. It offers to install Node.js and Git with winget and to `git clone` missing project folders into their new paths. Finally it lists anything still to copy by hand.

## Testing without touching real data

- **Screens only:** `powershell -File engine\claude-moove.ps1 -Mode preview` draws each screen once.
- **Unattended runs:** add `-Test`. Point `-HomeDir`, `-AppDataDir`, `-DesktopDir` and `-DocumentsDir` at a throwaway folder that contains `AppData\Roaming\Claude\config.json` with a `lastKnownAccountUuid`. Use `-OutDir` to choose where pack puts its folder. In test runs nothing is closed, opened, installed or downloaded.
- **Cases worth covering:**
  - a fresh laptop with a different user name and a OneDrive Desktop
  - a second unpack where one chat is newer on each side and one chat was continued on both
  - the merge hook, run by hand with a SessionStart input for each copy

## Known limits

- Windows only. The screens need a console that understands colour codes; Windows Terminal is best.
- Project folders are not packed. They come from GitHub, or you copy them yourself, which keeps uncommitted work.
- It relies on Claude's internal file layout, which can change between versions. Do a trial unpack before wiping the old laptop.
