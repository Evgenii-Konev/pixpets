# PixPets

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A native macOS menu bar app that gives your AI coding agents a life of their own. Each running agent session — Claude Code, Codex, Cursor CLI, OpenCode — appears as a small animated pixel character living in your menu bar.

<!-- screenshot -->

## Install

### Homebrew (recommended)

```bash
brew install --cask pixpets
```

After installing, launch PixPets and install the hooks:

```bash
pixpets --install-hooks
```

### Manual

Download the latest `.dmg` from [Releases](https://github.com/Evgenii-Konev/pixpets/releases), drag to Applications, and run `pixpets --install-hooks`.

## How it works

PixPets uses a push-based architecture:

1. A Claude Code hook fires on tool use events (`PreToolUse`, `PostToolUse`, `Stop`)
2. The hook writes a session JSON file to `~/.pixpets/sessions/`
3. An FSEvents watcher detects the change instantly
4. The menu bar icon updates — badge count shows active sessions, popover lists each agent with its status

Each agent gets its own pixel character with idle, blink, and walk animations — all drawn programmatically, no image assets.

## Supported agents

| Agent | Color |
|-------|-------|
| Claude Code | Terracotta `#C96442` |
| Codex | Near-black `#1A1A1A` |
| Cursor CLI | Blue `#4B6BFF` |
| OpenCode | Green `#2DA44E` |

## Development

```bash
swift build        # debug build
swift run          # build + run
swift build -c release
```

### Distribution

Requires `DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY` env vars for signing:

```bash
DEVELOPMENT_TEAM=... CODE_SIGN_IDENTITY=... make distribute
```

Skip notarization for local testing:

```bash
SKIP_NOTARIZE=1 DEVELOPMENT_TEAM=... CODE_SIGN_IDENTITY=... make distribute
```

## Architecture

```
Sources/
  main.swift              → App entry (no dock icon, menu bar only)
  AppDelegate.swift       → Creates MenuBarController + SessionManager
  SessionManager.swift    → Hybrid push/pull session detection
  MenuBarController.swift → NSStatusItem with popover, icon animation
  SessionsPopoverVC.swift → Scrollable list of sessions
  PixelCharacter.swift    → 18x18 pixel grids, bitmap renderer
  AgentType.swift         → Agent classification with colors
  Session.swift           → Data models
  TerminalFocuser.swift   → Click-to-focus terminal navigation
hooks/
  pixpets-hook.sh         → Claude Code hook, writes session JSON
```

## Contributing

Found a bug or have a feature idea? [Open an issue](https://github.com/Evgenii-Konev/pixpets/issues).

## License

[MIT](LICENSE) — Evgenii Konev
