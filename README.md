<p align="center">
  <img src="docs/claude-moove.svg" width="720" alt="Pixel-art Clawd with happy eyes standing in a flower field with butterflies, sparkles and a sun, above the words CLAUDE MOOVE! in rainbow block letters">
</p>

<h3 align="center">Your Claude chats are coming with you.</h3>

<p align="center">
  Move every chat, session, setting, hook, skill and memory to a new Windows laptop with <b>two buttons</b>.<br>
  A friendly little window walks you through it, and Clawd keeps you company in a field of flowers.
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
  <img src="docs/how-it-works.svg" width="720" alt="Pixel art: on the left a laptop showing a moving box, labelled 1 PACK. In the middle Clawd carries a box, labelled carry one folder. On the right a laptop shows a pink heart, labelled 2 UNPACK">
</p>

1. **Get it.** Click **Code → Download ZIP** on this page, then right-click the zip and choose **Extract All**.
2. **Pack.** On the laptop you're leaving, double-click **`1 - PACK (on the laptop you're leaving)`**. About five minutes later, a `Claude Moove <date>` folder is waiting on your Desktop.
3. **Carry.** Take that folder to the new laptop on a USB stick or a cloud drive. If it arrives as a zip, right-click it and choose **Extract All**.
4. **Unpack.** On the new laptop, open the folder, double-click **`2 - UNPACK (on the laptop you're moving to)`** and follow along.

That's the whole move. UNPACK even leaves the two buttons on your new Desktop, so next time is just as easy.

## The little window

Clawd sits at the top the whole way. He walks while things are busy, and a tiny flower bed blooms as each step is done.

<p align="center">
  <img src="docs/screen-pack.svg" width="700" alt="The PACK window at step 4 of 5, Zip it up: Clawd at the top, a blooming flower progress bar, finished steps ticked off, and the zip progress">
</p>

It does the fiddly parts for you:
- It closes Claude.
- It opens the download page if Claude isn't installed yet.
- It checks you're signed in to the same account.
- It offers to install Node.js and Git.
- It brings your projects back from GitHub.

When something doesn't match, it fixes it and tells you exactly what it did:

<p align="center">
  <img src="docs/screen-unpack.svg" width="700" alt="The UNPACK window at step 5 of 7: it rewrites the old user folder and Desktop paths to the new ones, adds 38 sessions, updates 3 that were newer on the other laptop, and keeps both copies of 1 chat used on both laptops">
</p>

A new Windows user name, or a Desktop that OneDrive moved, is no problem. Every path gets rewritten, so your sessions open and your hooks keep working.

## What comes along

| Comes along | Stays behind |
|---|---|
| Every chat and session, from the desktop app's Code tab and from Claude Code, with titles, stars and archive state | Your login: you just sign in again |
| Your global `CLAUDE.md`, `~/AGENTS.md` if you keep one, `settings.json`, hooks, skills and plugins | Caches, logs and other temporary files |
| Claude's memory, edit history for rewinds, Cowork sessions and your sidebar layout | Your project folders themselves. They come back from GitHub, or you copy them over |

Your claude.ai chats already live online and show up as soon as you sign in.

## When both laptops changed

Nothing gets lost, even if you kept working on both laptops.

| What happened | What Claude Moove does |
|---|---|
| A chat is newer on one laptop | The newer copy wins |
| The same chat was continued on both | You keep both. The other one appears as "… (other laptop)", and the first time you open either, Claude gets a one-time note about what happened in the other |
| Settings or `CLAUDE.md` changed | The newer file wins. Anything replaced is saved in `~/.claude-moove-safety` first |

The exact rules are in [How it works](engine/README.md).

## What you need

- **Windows 10 or 11.** It looks its best in Windows Terminal, the default on Windows 11.
- **The Claude desktop app and/or Claude Code**, signed in to the same account on both laptops.
- **Nothing else.** It uses Windows' own PowerShell, robocopy and tar. Node.js is only needed for the one-time merge note (and for your own hooks, if they use it), and UNPACK offers to install it.

## Questions

<details>
<summary><b>Does anything get uploaded?</b></summary>
<br>
No. Your data only goes wherever you carry the folder. Treat that folder like a diary, though: it holds your full chat history.
</details>

<details>
<summary><b>Can it overwrite something newer on my new laptop?</b></summary>
<br>
No. Chats and files are only ever replaced by newer copies. Settings that get replaced are saved in <code>~/.claude-moove-safety</code> first.
</details>

<details>
<summary><b>What about my project folders?</b></summary>
<br>
UNPACK offers to download them from GitHub into the right places. If a project has changes that aren't on GitHub yet, PACK warns you, so you can commit them or copy the folder over yourself.
</details>

<details>
<summary><b>Windows says "Windows protected your PC". Is that bad?</b></summary>
<br>
Windows says that about most downloaded scripts. Click <b>More info → Run anyway</b>. The buttons are plain text files, so you can open them and read every line first.
</details>

<details>
<summary><b>Mac or Linux?</b></summary>
<br>
Not yet. It's Windows only for now, and pull requests are very welcome.
</details>

## Good to know

<img src="docs/clawd-small.svg" height="15" alt="Clawd"> &nbsp;**Clawd's tip:** do one trial unpack on the new laptop before you wipe the old one. Claude's internal files can change between versions, and it's nice to be sure.

Project folders aren't packed, so uncommitted work only comes along if you copy those folders yourself.

## Contributing

Issues and pull requests are very welcome. [How it works](engine/README.md) explains the merge rules and how to test safely without touching your real Claude data.

## License

[MIT](LICENSE). Use it, share it, make it even cuter.

<p align="center"><img src="docs/flower-divider.svg" width="720" alt=""></p>

<p align="center"><sub>Claude Moove is an unofficial community project. It is not made by, affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic.</sub></p>
