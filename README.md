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

That's the whole move 🎉 Claude can even stay open while you do it.

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

## The little window

No wizard, no "press Enter to continue". You get one screen with everything ticked: type a number to change something, and press Enter to go. Clawd sits at the top the whole way, walking while things are busy.

<p align="center">
  <img src="docs/screen-pack.svg" width="700" alt="The PACK window: Clawd at the top, a ticked list of what comes along (chats and sessions, settings and instructions, memory, project Claude files; the sidebar layout waits until Claude is closed), a choice between sending with a code and carrying it on a pendrive, and a heads-up about a project with changes not on GitHub yet">
</p>

It does the fiddly parts for you:
- It works with Claude still open, and says what has to wait until Claude is closed. Press C and it closes Claude for you.
- It opens the download page if Claude isn't installed yet.
- It checks you're signed in to the same account.
- It offers to install Node.js and Git.
- It brings your projects back from GitHub.

When something changed on both laptops, like your `CLAUDE.md`, nothing gets overwritten blindly. Like git, it shows you, and you pick what to keep:

<p align="center">
  <img src="docs/screen-unpack.svg" width="700" alt="The UNPACK window: where the packed stuff came from, a note that this PC's own chats stay, the old and new user folder paths it fixes, a ticked list of what comes in, and three files changed on both laptops, each with a choice: keep both and let Claude merge them, take the old laptop's, or keep this PC's">
</p>

A new Windows user name, or a Desktop that OneDrive moved, is no problem. Every path gets rewritten, so your sessions open and your hooks keep working.

## Let Claude do it

Claude Moove is also a Claude skill. Claude runs the same move for you, and when a file changed on both laptops, it reads both versions and merges them, so you don't have to choose.

**Add it** in one of two ways:
- Start Claude Moove (see [Start it](#start-it)) and choose **3**.
- Or add it to Claude Code as a plugin:
  ```
  /plugin marketplace add paulgegenyi/claude-moove
  /plugin install moove@claude-moove
  ```

**Use it:** type `/claude-moove`, or just ask: *"pack up my Claude stuff for my new laptop"*, or *"move my Claude stuff in"*.

Claude is open while it works, so your chats and sidebar layout come in last. A small Claude Moove window waits, and they come in the moment you quit Claude.

## What comes along

| Comes along | Stays behind |
|---|---|
| Every chat and session, from the desktop app's Code tab and from Claude Code, with titles, stars and archive state | Your login: you just sign in again |
| Your global `CLAUDE.md`, `~/AGENTS.md` if you keep one, `settings.json`, hooks, skills and plugins | Caches, logs and other temporary files |
| Claude's memory, edit history for rewinds, Cowork sessions and your sidebar layout | Your project folders themselves. They come back from GitHub, or you copy them over |
| The Claude files in your projects that GitHub doesn't have, like a `CLAUDE.local.md` or `.claude/settings.local.json` | |

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

Anything replaced is saved in `~/.claude-moove-safety` first.

The exact rules are in [How it works](engine/README.md).

## What you need

- **Windows 10 or 11.** It looks its best in Windows Terminal, the default on Windows 11.
- **The Claude desktop app and/or Claude Code**, signed in to the same account on both laptops.
- **Nothing else.** It uses Windows' own PowerShell, robocopy and tar. Node.js is only needed for the one-time merge note (and for your own hooks, if they use it), and UNPACK offers to install it.
- **Sending over the internet** uses [croc](https://github.com/schollz/croc), a small, free, open-source tool. If you choose to send, Claude Moove installs it for you from Windows' own app catalogue.

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
A few things to know:
<ul>
<li>Both laptops need to be on at the same time.</li>
<li>Whoever types the code first gets the folder, so don't post it anywhere.</li>
<li>If croc's relay is ever down, the USB stick still works.</li>
</ul>
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
<summary><b>What about my project folders?</b></summary>
<br>
UNPACK offers to download them from GitHub into the right places. The Claude files in them that GitHub doesn't have come along by themselves. If a project has other changes that aren't on GitHub yet, PACK warns you, so you can commit them or copy the folder over yourself.
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

<img src="docs/clawd-small.svg" height="15" alt="Clawd"> &nbsp;**Clawd's tip:** do one trial unpack on the new laptop before you wipe the old one. Claude's internal files can change between versions, and it's nice to be sure.

Project folders aren't packed, only their Claude files, so other uncommitted work only comes along if you push it to GitHub or copy those folders yourself.

## Contributing

Issues and pull requests are very welcome. [How it works](engine/README.md) explains the merge rules and how to test safely without touching your real Claude data.

## License

[MIT](LICENSE). Use it, share it, make it even cuter.

<p align="center"><img src="docs/flower-divider.svg" width="720" alt=""></p>

<p align="center"><sub>Claude Moove is an unofficial community project. It is not made by, affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic.</sub></p>
