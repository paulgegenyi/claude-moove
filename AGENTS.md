# Notes for coding agents

Start with [README.md](README.md) (what Claude Moove does) and [engine/README.md](engine/README.md) (how it works, merge rules, testing).

- `engine/claude-moove.ps1` must run on Windows PowerShell 5.1 and stay plain ASCII. Build special characters from character codes, as the Clawd art does.
- The two `.cmd` buttons must keep CRLF line endings. `.gitattributes` stores them byte for byte.
- Never commit packed data (`claude-data.zip`, `manifest.json`) or anything personal: no real user names, paths, session titles or account IDs in code, docs or examples.
- Test screens with `-Mode preview`. Test packing and unpacking with `-Test`, pointing `-HomeDir`, `-AppDataDir`, `-DesktopDir` and `-DocumentsDir` at a throwaway folder. Never unpack into a real profile while testing.
- When behaviour changes, update `engine/README.md` in the same change.
- This is a public repo: commit messages plainly describe the change ("Add screenshots to the README"), with no chat wording, nicknames or jokes.
