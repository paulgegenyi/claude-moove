<p align="center">
  <img src="docs/claude-moove.svg" width="720" alt="Pixel-art Clawd standing in a flower field with butterflies and a sun, above the words CLAUDE MOOVE! in rainbow block letters">
</p>

# Claude Moove

**Move all your Claude stuff from one Windows laptop to another with two buttons.**

That means every chat and session from the Claude desktop app's Code tab and from Claude Code, plus your global `CLAUDE.md`, settings, hooks, skills, plugins and memory. You pack them on the old laptop and unpack them on the new one, and nothing gets lost. It doesn't matter if the new laptop has a different Windows user name or a Desktop that OneDrive moved: your sessions still open, and your hooks still point to the right place.

A friendly window walks you through every step and checks everything for you, with Clawd in a flower field keeping you company.

> **Unofficial.** Claude Moove is a community tool. It is not made by, affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic.

## How to use it

1. **Get it.** Click **Code → Download ZIP** on this page, then right-click the zip and choose **Extract All**.
2. **On the laptop you're leaving:** double-click **`1 - PACK (on the laptop you're leaving)`**.
   It closes Claude for you and warns you about projects with work that isn't on GitHub yet. After about five minutes there's a folder called `Claude Moove <date>` on your Desktop.
3. **Carry that folder** to the new laptop on a USB stick or a cloud drive. If it arrives as a zip, right-click it and choose **Extract All**.
4. **On the new laptop:** open the folder and double-click **`2 - UNPACK (on the laptop you're moving to)`**. It takes you through:
   - installing the Claude app if needed (it opens the download page)
   - checking you're signed in to the same account
   - closing Claude, then merging everything in
   - installing Node.js and Git if they're missing
   - downloading your project folders from GitHub into the right places

   It also leaves a copy of the buttons on the new Desktop, ready for your next move.

If Windows warns about running a downloaded file, choose **More info → Run anyway**. The buttons are plain scripts you can open and read.

## What moves

| Moves | Stays behind |
|---|---|
| Chats and sessions (Code tab and Claude Code), with titles, stars and archive state | Your login: you just sign in again |
| Global `CLAUDE.md`, `~/AGENTS.md` if you keep one, `settings.json`, hooks, skills, plugins | Caches, logs and other temporary files |
| Claude's memory, edit history, Cowork sessions, the sidebar layout | Your project folders themselves. They come back from GitHub, or you copy them |

Chat-tab conversations on claude.ai are stored online already and show up as soon as you sign in.

## Used on both laptops? Nothing is lost

- **One copy is newer:** the newer one wins.
- **The same chat was continued on both laptops:** you keep both, and the other laptop's version shows up as "… (other laptop)". The first time you open either one, Claude gets a one-time note about what happened in the other.
- **Settings and instruction files:** the newer one wins. Anything that gets replaced is saved first in `~/.claude-moove-safety`.

[How it works](engine/README.md) has the details.

## Requirements

- Windows 10 or 11. It looks best in Windows Terminal, the default on Windows 11.
- The Claude desktop app and/or Claude Code, signed in with the same account on both laptops.
- Nothing else to install: it uses Windows' built-in PowerShell, robocopy and tar. Node.js is only needed for the one-time merge note (and for your own hooks, if they use it).

## Privacy and safety

- Nothing is uploaded anywhere. Your data only goes where you carry the folder.
- The transfer folder contains your **full chat history**. Keep it private.
- Login tokens are never packed.
- Nothing is deleted. Existing files are only replaced by newer ones, and replaced settings are kept in a safety folder.

## Limits

- Windows only.
- Project folders aren't packed, so uncommitted work only comes along if you copy those folders yourself.
- Claude's internal file layout can change between versions. Do a trial unpack on the new laptop before you wipe the old one.

## Contributing

Issues and pull requests are welcome. [How it works](engine/README.md) explains the merge rules and how to test safely without touching your real Claude data.

## License

[MIT](LICENSE)
