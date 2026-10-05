<p align="center">
  <img src="docs/claude-moove.svg" width="720" alt="Pixel-art Clawd with happy eyes standing in a flower field with butterflies, sparkles and a sun, above the words CLAUDE MOOVE! in rainbow block letters">
</p>

<h3 align="center">New laptop? Your Claude chats are coming with you. 🌼</h3>

<p align="center">
  Move <b>every</b> chat, session, setting, hook, skill and memory to another Windows laptop with <b>two buttons</b>.<br>
  A friendly window walks you through everything, and Clawd keeps you company in a field of flowers.
</p>

<p align="center">
  <img alt="Windows 10 and 11" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4">
  <img alt="Nothing to install" src="https://img.shields.io/badge/install-nothing-7DC37D">
  <img alt="MIT license" src="https://img.shields.io/badge/license-MIT-F28CB8">
  <img alt="Unofficial community tool" src="https://img.shields.io/badge/Anthropic-unofficial-D77757">
</p>

---

## ✨ Why you'll like it

- 📦 **Two buttons, that's it.** Press PACK on the old laptop and UNPACK on the new one. Everything else is explained on screen.
- 🧠 **It thinks of everything.** It closes Claude for you and opens the download page if Claude isn't installed. It checks you're signed in to the same account, offers to install Node.js and Git, and downloads your projects back from GitHub.
- 🧭 **A different laptop is fine.** New Windows user name? Desktop moved into OneDrive? Every path is rewritten, so every session opens and every hook still works.
- 🔁 **Nothing gets lost, ever.** The newer copy always wins. If you used the same chat on both laptops, you keep both, and Claude gets a one-time note about what happened in the other.
- 🔒 **Private by design.** Nothing is uploaded anywhere and login tokens are never packed. Anything replaced is saved in a safety folder first.

## 🚚 How it works

<p align="center">
  <img src="docs/how-it-works.svg" width="720" alt="Pixel art: on the left a laptop showing a moving box labelled 1 PACK, in the middle Clawd carrying a box labelled carry one folder, on the right a laptop showing a pink heart labelled 2 UNPACK">
</p>

1. **Get it:** click **Code → Download ZIP** on this page, right-click the zip and choose **Extract All**.
2. **On the laptop you're leaving:** double-click **`1 - PACK (on the laptop you're leaving)`**. In about five minutes a `Claude Moove <date>` folder appears on your Desktop.
3. **Carry that folder** to the new laptop on a USB stick or a cloud drive. If it arrives zipped, right-click it and choose **Extract All**.
4. **On the new laptop:** open the folder and double-click **`2 - UNPACK (on the laptop you're moving to)`**. Follow the window. 🎉

UNPACK also leaves the buttons on your new Desktop, so the next move is just as easy.

> 💡 If Windows says *"Windows protected your PC"*, click **More info → Run anyway**. The buttons are plain scripts you can open and read.

## 👀 What you'll see

Clawd stays at the top the whole time. He walks while things are busy, and the little flower bed blooms as each step finishes.

<p align="center">
  <img src="docs/screen-pack.svg" width="700" alt="The PACK window at step 4 of 5, Zip it up: Clawd at the top, a blooming flower progress bar, finished steps ticked off, and the zip progress">
</p>

On the new laptop it fixes paths that don't match and merges your chats, telling you exactly what it did:

<p align="center">
  <img src="docs/screen-unpack.svg" width="700" alt="The UNPACK window at step 5 of 7: it rewrites the old user folder and Desktop paths to the new ones, adds 38 sessions, updates 3 that were newer on the other laptop, and keeps both copies of 1 chat used on both laptops">
</p>

## 📋 What moves

| Comes along | Stays behind |
|---|---|
| Every chat and session, from the desktop app's Code tab and from Claude Code, with titles, stars and archive state | Your login: you just sign in again |
| Your global `CLAUDE.md`, `~/AGENTS.md` if you keep one, `settings.json`, hooks, skills and plugins | Caches, logs and other temporary files |
| Claude's memory, edit history for rewinds, Cowork sessions and your sidebar layout | Your project folders themselves. They come back from GitHub, or you copy them over |

Your claude.ai chats are already online and show up as soon as you sign in.

## 🔁 Used both laptops? No problem

| What happened | What Claude Moove does |
|---|---|
| A chat is newer on one laptop | The newer copy wins |
| The same chat was continued on both | You keep both. The other one appears as "… (other laptop)", and the first time you open either, Claude gets a one-time note about what happened in the other |
| Settings or `CLAUDE.md` changed | The newer file wins. Anything replaced is saved in `~/.claude-moove-safety` first |

The exact rules are in [How it works](engine/README.md).

## 🧰 What you need

- Windows 10 or 11. It looks its best in Windows Terminal, the default on Windows 11.
- The Claude desktop app and/or Claude Code, signed in to the same account on both laptops.
- Nothing to install: it uses Windows' own PowerShell, robocopy and tar. Node.js is only needed for the one-time merge note (and for your own hooks, if they use it). UNPACK offers to install it for you.

## ❓ Questions

<details>
<summary><b>Does anything get uploaded?</b></summary>
No. Your data only goes wherever you carry the folder. Treat that folder like a diary, though: it holds your full chat history.
</details>

<details>
<summary><b>Can it overwrite something newer on my new laptop?</b></summary>
No. Chats and files are only ever replaced by newer copies. Settings that get replaced are saved in <code>~/.claude-moove-safety</code> first.
</details>

<details>
<summary><b>What about my project folders?</b></summary>
UNPACK offers to download them from GitHub into the right places. If a project had changes that weren't on GitHub yet, PACK warns you first, so you can commit them or copy the folder over yourself.
</details>

<details>
<summary><b>Mac or Linux?</b></summary>
Not yet. It's Windows only for now. Pull requests are welcome!
</details>

## ⚠️ Good to know

- Claude's internal file layout can change between versions. Do one trial unpack on the new laptop before you wipe the old one.
- Project folders aren't packed, so uncommitted work only comes along if you copy those folders yourself.

## 🛠️ Contributing

Issues and pull requests are very welcome. [How it works](engine/README.md) explains the merge rules and how to test safely without touching your real Claude data.

## 📄 License

[MIT](LICENSE). Use it, share it, make it even cuter.

<sub>Claude Moove is an unofficial community project. It is not made by, affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic.</sub>
