# Notes for coding agents

Start with [README.md](README.md) (what Claude Moove does) and [engine/README.md](engine/README.md) (how it works, merge rules, testing).

- `engine/claude-moove.ps1` must run on Windows PowerShell 5.1 and stay plain ASCII. Build special characters from character codes, as the Clawd art does.
- The two `.cmd` buttons must keep CRLF line endings. `.gitattributes` stores them byte for byte.
- Releases: set the same version in `.claude-plugin/plugin.json` (plugin users only get updates when it changes), tag `vX.Y.Z` and attach `claude-moove.zip`, built with `git archive` from the user-facing files only (the two buttons, `engine/`, `skills/`, `moove.ps1`, `LICENSE`, `README.md`), at the zip's root. Keep that asset name, so the README's `releases/latest/download/claude-moove.zip` link keeps working.
- The plugin is named `moove` because Claude Code refuses plugin names starting with `claude-`. Check `.claude-plugin/` with `claude plugin validate .` after changing it.
- `skills/claude-moove/SKILL.md` drives the engine through `-Yes -Json`. When a switch, a result field or the conflict choices change, update the skill in the same change.
- `moove.ps1` is piped into `iex` by users. Keep it short and readable, with no side effects beyond fetching into `%LOCALAPPDATA%\Claude Moove` and starting the engine. It must also work when run from a clone, passing its arguments through.
- Never commit packed data (`claude-data.zip`, `manifest.json`) or anything personal: no real user names, paths, session titles or account IDs in code, docs or examples.
- Test screens with `-Mode preview`. Test packing and unpacking with `-Test`, pointing `-HomeDir`, `-AppDataDir`, `-DesktopDir` and `-DocumentsDir` at a throwaway folder. Never unpack into a real profile while testing. In test runs a `test-claude-open` file in the fake `AppData\Roaming\Claude` stands for a running Claude, and the pick screens read typed answers from redirected input.
- PowerShell variable names ignore case, so a script variable can silently overwrite a parameter (`$script:what` would be `$What`). Check new names against the `param` block.
- When behaviour changes, update `engine/README.md` in the same change.
- This is a public repo: commit messages plainly describe the change ("Add screenshots to the README"), with no chat wording, nicknames or jokes.
