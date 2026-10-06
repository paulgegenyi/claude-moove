<p align="center">
  <img src="docs/claude-moove.svg" width="720" alt="Pixel-art Clawd with happy eyes standing in a flower field with butterflies, sparkles and a sun, above the words CLAUDE MOOVE! in rainbow block letters">
</p>

<h3 align="center">Your Claude chats are coming with you 🌼</h3>

<p align="center">
  Move every chat, session, setting, hook, skill and memory to a new Windows laptop with <b>one copy-paste</b>,<br>
  or let Claude do the whole move for you. Clawd keeps you company in a field of flowers.
</p>

<p align="center">
  <img alt="Windows 10 and 11" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4">
  <img alt="Nothing to install" src="https://img.shields.io/badge/install-nothing-7DC37D">
  <img alt="MIT license" src="https://img.shields.io/badge/license-MIT-F28CB8">
  <img alt="Unofficial community tool" src="https://img.shields.io/badge/Anthropic-unofficial-D77757">
</p>

<p align="center"><img src="docs/flower-divider.svg" width="720" alt=""></p>

## How it works

<p align="center">
  <img src="docs/how-it-works.svg" width="720" alt="Pixel art: on the left a laptop showing a moving box, labelled 1 PACK. In the middle Clawd carries a box, labelled send it or carry it. On the right a laptop shows a pink heart, labelled 2 UNPACK">
</p>

**On the laptop you're leaving,** start Claude Moove (see below) and choose **1** (pack up). Everything is ticked; untick what you'd rather leave behind and press Enter. A few minutes later it's all packed into a `Claude Moove <date>` folder on your Desktop. You can **send** that folder straight to the new laptop with a one-time code like `joy-buzz-tiger`, or carry it over on a pendrive.

**On the laptop you're moving to,** start it the same way and choose **2** (move in). If you carried the folder, it finds it by itself, on the Desktop, in Downloads or on a plugged-in pendrive. If you're sending, it asks for the code. Before anything changes, it shows you what comes in and anything that changed on both laptops.

That's the whole move 🎉 Claude can even stay open while you do it. Or skip the window altogether and [let Claude do it](#let-claude-do-it).

<p align="center">
  <img src="docs/screen-send.svg" width="700" alt="The PACK window at step 4 of 4, Send it to the new laptop: a one-time code in pink, joy-buzz-tiger, with the line to paste on the new laptop and the sending progress">
</p>

## Start it

Pick whichever you like. All three do exactly the same thing.

### CMD

Open **Command Prompt** (press Start, type `cmd`, press Enter) and paste:

```bat
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/paulgegenyi/claude-moove/main/moove.ps1 | iex"
```

### PowerShell

Open **PowerShell** (press Start, type `powershell`, press Enter) and paste:

```powershell
irm https://raw.githubusercontent.com/paulgegenyi/claude-moove/main/moove.ps1 | iex
```

### Manual

1. Download **[claude-moove.zip](https://github.com/paulgegenyi/claude-moove/releases/latest/download/claude-moove.zip)** (it's also under **Releases**, on the right of this page).
2. Right-click it and choose **Extract All**.
3. Double-click **`1 - PACK (on the laptop you're leaving)`** or **`2 - UNPACK (on the laptop you're moving to)`**.

For downloaded scripts, Windows may say *"Windows protected your PC"*. Click **More info → Run anyway**. CMD and PowerShell never trigger that warning.

> **Pendrive tip:** the packed folder comes with its own buttons. On the new laptop, open it on the stick and double-click `2 - UNPACK (on the laptop you're moving to)`. There's no warning, because the folder was made on your own laptop.

### Mac / Linux

Not yet: Claude Moove is Windows only for now. **Pull requests are welcome!** Have a look at [How it works](engine/README.md) to see what a Mac or Linux version would need to handle.

## Packing up

On the laptop you're leaving, choose **1** in the menu, or double-click `1 - PACK (on the laptop you're leaving)`. No wizard, no "press Enter to continue": you get one screen, and Clawd sits at the top the whole way.

<p align="center">
  <img src="docs/screen-pack.svg" width="700" alt="The PACK window: Clawd at the top, a ticked list of what comes along (chats and sessions, settings and instructions, memory, project Claude files; the sidebar layout waits until Claude is closed), a choice between sending with a code and carrying it on a pendrive, and a heads-up about a project with changes not on GitHub yet">
</p>

**What comes along.** Everything is ticked. Type a number and press Enter to tick or untick it.

| | What | What's in it |
|---|---|---|
| 1 | Chats and sessions | Every chat and session from the desktop app's Code tab and from Claude Code in the terminal, with titles, stars and archive state. Also edit history for rewinds, your prompt history and Cowork sessions |
| 2 | Settings and instructions | Your global `CLAUDE.md`, `~/AGENTS.md`, `settings.json`, hooks, skills, plugins, commands and agents, your MCP servers, and the desktop app's settings |
| 3 | Memory | The notes Claude keeps for each project |
| 4 | Project Claude files | The Claude files in your projects that GitHub doesn't have, like a `CLAUDE.md` you never committed. See [Your projects](#your-projects) |
| 5 | Sidebar layout | How your sessions are grouped and pinned in the app. This one needs Claude closed |

**How it travels.** Press **S** to send it over the internet with a one-time code, or **U** to carry it on a pendrive. See [Sending or carrying](#sending-or-carrying).

**Claude can stay open.** Only the sidebar layout needs Claude closed. Press **C** and Claude Moove closes it for you. Your chats are saved as you go, so nothing is lost.

**Heads-up for your projects.** If a project has work that isn't on GitHub yet, the screen tells you, so you can commit and push it first. Claude Moove carries your Claude files, not your code.

Press **Enter** to start, or **Q** to quit without changing anything. A few minutes later there's a `Claude Moove <date>` folder on your Desktop, with your data and both buttons inside. If you chose sending, the code comes next.

## Moving in

On the laptop you're moving to, choose **2** in the menu, or double-click `2 - UNPACK (on the laptop you're moving to)` in the folder you carried. Claude Moove looks for your packed stuff by itself: next to the button, on the Desktop, in Downloads or Documents, or on a plugged-in pendrive. If it finds nothing, it asks for the code from your old laptop. Nothing changes until you press Enter.

<p align="center">
  <img src="docs/screen-unpack.svg" width="700" alt="The UNPACK window: where the packed stuff came from, a note that this PC's own chats stay, the old and new user folder paths it fixes, a ticked list of what comes in, and three files changed on both laptops, each with a choice: keep both and let Claude merge them, take the old laptop's, or keep this PC's">
</p>

**At the top** it tells you:
- where your stuff came from
- whether this PC already has Claude chats of its own (they stay, and yours are merged in next to them)
- whether you're signed in to the same Claude account
- which folders have different paths here

A new Windows user name, or a Desktop that OneDrive moved, is no problem. Every path gets rewritten, so your sessions open and your hooks keep working.

**What comes in.** The same five kinds as when packing, plus **Download missing projects**: project folders that are on GitHub but not on this laptop get downloaded to the same place as on your old laptop. A PC with its own sidebar layout keeps it unless you tick it.

**Changed on both laptops.** When your `CLAUDE.md`, `AGENTS.md`, `settings.json` or a project's Claude file changed on both laptops, nothing gets overwritten blindly. Like git, it lists them and you pick what to keep. Type a file's number to switch between the choices:

| Choice | What happens |
|---|---|
| keep both, Claude merges them | This PC's stays in use, and the old laptop's is saved next to it, for example as `CLAUDE.from-OLD-LAPTOP.md`. The next time you start Claude, it tells you and offers to merge the two |
| keep this PC's | Nothing changes |
| take the old laptop's | The old laptop's replaces this PC's, which is saved first |

It suggests one for each file:
- **the old laptop's** when this PC's copy is just a fresh install's, or exactly what's on GitHub
- **both** for instruction files like `CLAUDE.md`
- **the newer one** for settings

Once you've settled a file, it doesn't ask about the same versions again.

**Other keys:**
- **C** closes Claude
- **N** and **G** install Node.js and Git
- **D** opens Claude's download page
- **A** checks the account again
- **R** receives with a code instead

**With Claude still open,** your settings, memory and project files come in right away. Then the window says *Close Claude now*, and the moment you do, your chats and sidebar layout come in. Press **C** to let Claude Moove close it, or **S** to skip for now. Moving in again later only adds what's missing.

At the end you see what came in. Anything replaced is saved in `~/.claude-moove-safety` first.

## Your projects

**What counts as a project?** Every folder you've had a Claude chat in, from the Code tab or from the terminal. If that folder is inside a git repository, the whole repository is the project, and a worktree counts as part of its repository. Your user folder, Claude's own folders and temporary folders don't count.

**Which files come along?** From each project:
- `CLAUDE.md` and `AGENTS.md` at the top, and `CLAUDE.local.md` if you keep one
- everything in its `.claude` folder: project settings, rules, commands, agents and skills, but not worktrees or lock files

**Only what GitHub doesn't have.** In a git repository, a file comes along only if GitHub doesn't have it as it is: never committed, git-ignored, or changed since your last commit. So if you keep your `CLAUDE.md` out of git, it still travels with you. If it's committed, it comes back with the project. In a folder without git, they all come along.

**On the new laptop** they go into the same project folder, with paths fixed. If the project isn't there yet, Claude Moove offers to download it from GitHub first. If it isn't on GitHub, Claude Moove tells you which folders to copy over. Their Claude files wait until then: move in again once the folder is there.

Your code itself doesn't travel. Push it to GitHub, or copy the folder.

## Let Claude do it

Claude Moove is also a **Claude skill**: a small instruction file that teaches Claude how to run the move for you. Claude goes through the same steps as the window. When a file changed on both laptops, it reads both versions and merges them, so you don't have to choose.

### Add it

You only need one of these:

| | How | You get |
|---|---|---|
| **From the menu** | Start Claude Moove (see [Start it](#start-it)) and choose **3** | The skill in your own Claude folder, as `/claude-moove`. It travels with you on your next move |
| **As a plugin** | In Claude Code, type `/plugin marketplace add paulgegenyi/claude-moove`, then `/plugin install moove@claude-moove` | The same skill, which you can update from `/plugin` |

Then start a new session.

### Use it

Type `/claude-moove`, or just ask:
- *"Pack up my Claude stuff, I'm moving to a new laptop."*
- *"Send my Claude stuff to my other PC."*
- *"Move my Claude stuff in from the USB stick."*

**When you pack up,** Claude asks whether you'll send or carry it, packs, and gives you the folder or the code. If a project has work that isn't on GitHub yet, it offers to commit and push it.

**When you move in,** Claude:
1. Looks first, changing nothing, and tells you what will come in: your chats, settings and projects, and any path changes.
2. Opens every file that changed on both laptops and reads both versions.
3. Merges them. It keeps every instruction from both, drops duplicates and fixes paths for this laptop. It asks you only when the two versions really disagree.
4. Moves everything in and tells you what changed. Anything replaced is saved first.
5. Hands your chats and sidebar layout to a small Claude Moove window. Those need Claude closed, and Claude can't close itself. Quit Claude when you're ready and they come in right away, then open Claude again.

## Sending or carrying

**Carrying:** copy the `Claude Moove <date>` folder to a pendrive or a cloud drive. On the new laptop, plug it in and start Claude Moove: it finds the folder by itself.

**Sending over the internet** uses [croc](https://github.com/schollz/croc), a small free tool that sends a folder end-to-end encrypted, matched by a one-time code like `joy-buzz-tiger`:
- Your old laptop shows the code. Type it on the new laptop, and the folder comes over. Both laptops need to be on at the same time.
- On the same Wi-Fi they connect directly. Otherwise they meet on croc's free relay, which passes the data along but can't read it.
- croc's relay allows 5 new transfers per hour from one internet address. A move needs one or two, but on a shared network (an office, a school, a hotel) it can be busy. If it is, wait a little, use your phone's hotspot, or carry the folder instead.
- If croc isn't installed, Claude Moove installs it for you from Windows' own app catalogue, after asking.

## What comes along

| Comes along | Stays behind |
|---|---|
| Every chat and session, from the desktop app's Code tab and from Claude Code, with titles, stars and archive state | Your login: you just sign in again |
| Your global `CLAUDE.md`, `~/AGENTS.md` if you keep one, `settings.json`, hooks, skills, plugins and MCP servers | Caches, logs and other temporary files |
| Claude's memory, edit history for rewinds, Cowork sessions and your sidebar layout | Your project folders themselves. They come back from GitHub, or you copy them over |
| The Claude files in your projects that GitHub doesn't have, like an uncommitted `CLAUDE.md` | Claude files GitHub already has: they come back with the project |

Your claude.ai chats already live online and show up as soon as you sign in.

## When both laptops changed

Nothing gets lost, even if you kept working on both laptops.

| What happened | What Claude Moove does |
|---|---|
| A chat is newer on one laptop | The newer copy wins |
| The same chat was continued on both | You keep both. The other one appears as "… (other laptop)", and the first time you open either, Claude gets a one-time note about what happened in the other |
| `CLAUDE.md`, `AGENTS.md`, `settings.json` or a project's Claude files changed on both | You choose: keep this PC's, take the old laptop's, or keep both, and Claude offers to merge them next time you start it. With the skill, Claude merges them right away |
| Other settings changed | The newer file wins |
| The new PC already has its own Claude chats | Nothing there is wiped: your chats are merged in next to its own, and it keeps its own sidebar layout unless you tick it |

Anything replaced is saved in `~/.claude-moove-safety` first. The exact rules are in [How it works](engine/README.md).

## What you need

- **Windows 10 or 11.** It looks its best in Windows Terminal, the default on Windows 11.
- **The Claude desktop app**, installed and opened once on the new laptop, and signed in to the same account on both laptops. Claude Code in the terminal comes along too.
- **Nothing else.** It uses Windows' own PowerShell, robocopy and tar. Node.js is only needed for Claude's one-time notes (and for your own hooks, if they use it), and moving in offers to install it.
- **To send over the internet:** [croc](https://github.com/schollz/croc), a small, free, open-source tool. Claude Moove installs it for you if you choose to send.

## Questions

<details>
<summary><b>Does anything get uploaded?</b></summary>
<br>
Only if you choose to send it over the internet, and then it's encrypted end to end (see the next question). If you carry it, your data only goes wherever you take the folder. Either way, treat that folder like a diary: it holds your full chat history.
</details>

<details>
<summary><b>Is sending over the internet safe?</b></summary>
<br>
Sending uses <a href="https://github.com/schollz/croc">croc</a>, which encrypts everything end to end with your one-time code:
<ul>
<li>Nothing is opened on either laptop for anyone to connect to. Both only reach out, directly if they're on the same Wi-Fi, otherwise through croc's free relay.</li>
<li>The relay passes the data along but can't read it.</li>
<li>Guessing the code isn't practical, because each attempt is a one-shot.</li>
</ul>
Whoever types the code first gets the folder, so don't post it anywhere.
</details>

<details>
<summary><b>Can it overwrite something newer on my new laptop?</b></summary>
<br>
No. Chats are only ever replaced by longer versions of themselves. When <code>CLAUDE.md</code>, <code>AGENTS.md</code>, <code>settings.json</code> or a project's Claude files changed on both laptops, you choose what to keep; other settings go to the newer copy. Anything replaced is saved in <code>~/.claude-moove-safety</code> first.
</details>

<details>
<summary><b>Do I have to close Claude?</b></summary>
<br>
No. Packing works with Claude open; only the sidebar layout needs it closed. When moving in, settings, memory and project files come in right away, and your chats and sidebar layout come in the moment you close Claude.
</details>

<details>
<summary><b>Is pasting a command safe?</b></summary>
<br>
It's the same way Claude Code's own Windows installer works. The line downloads Claude Moove from this page into <code>%LOCALAPPDATA%\Claude Moove</code> and opens its menu, and nothing else is installed. You can read <a href="moove.ps1">moove.ps1</a> first: it's about 25 lines. Because nothing goes through the browser, Windows doesn't show its "Windows protected your PC" warning.
</details>

<details>
<summary><b>Windows says "Windows protected your PC" when I double-click a button. Is that bad?</b></summary>
<br>
Windows says that about most scripts downloaded through a browser. Click <b>More info → Run anyway</b>, or start it from CMD or PowerShell instead, which never triggers it. The buttons are plain text files, so you can open them and read every line first.
</details>

<details>
<summary><b>Mac or Linux?</b></summary>
<br>
Not yet. It's Windows only for now, and pull requests are very welcome (see <a href="#mac--linux">Mac / Linux</a>).
</details>

## Good to know

<img src="docs/clawd-small.svg" height="15" alt="Clawd"> &nbsp;**Clawd's tip:** do one trial move-in on the new laptop before you wipe the old one. Claude's internal files can change between versions, and it's nice to be sure.

## Contributing

Issues and pull requests are very welcome. [How it works](engine/README.md) explains the merge rules and how to test safely without touching your real Claude data.

## License

[MIT](LICENSE). Use it, share it, make it even cuter.

<p align="center"><img src="docs/flower-divider.svg" width="720" alt=""></p>

<p align="center"><sub>Claude Moove is an unofficial community project. It is not made by, affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic.</sub></p>
