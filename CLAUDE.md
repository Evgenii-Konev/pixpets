# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pixpets is a native macOS menu bar app (Swift + AppKit, no third-party dependencies, minimum macOS 13). Each running AI coding agent session (Claude Code, Codex, Cursor CLI, OpenCode) appears as a small animated pixel character in the menu bar. The full spec lives in `docs/TASK.md`.

## Build & Run

```bash
# Build
swift build

# Run
swift run

# Build release
swift build -c release
```

If/when an Xcode project is added instead of SPM:

```bash
xcodebuild -scheme pixpets -configuration Debug build
```

## Architecture

```
App/              → AppDelegate, Info.plist (LSUIElement=true, no dock icon)
MenuBar/          → SessionManager (polls `ps aux` every 2s, reads ~/.pixpets/sessions/PID.json)
                    StatusItemController (one NSStatusItem per detected PID)
                    TerminalFocuser (click → AppleScript to focus iTerm2/Ghostty/Zed/Cursor)
Character/        → PixelCharacter (18x18 pixel grid, drawn programmatically via NSBezierPath)
                    CharacterView (NSView with Timer-driven animation: idle/working/waiting)
Hooks/            → HookInstaller (writes hook scripts to ~/.claude/hooks/ etc.)
```

Key data flow: `SessionManager` polls processes → creates/removes `StatusItemController` instances → each controller owns a `CharacterView` → `CharacterView` reads status from `~/.pixpets/sessions/PID.json` and animates accordingly.

## Agent Color Map

- Claude Code: `#C96442` (terracotta)
- Codex: `#1A1A1A` (near black)
- Cursor CLI: `#4B6BFF` (blue)
- OpenCode: `#2DA44E` (green)
- Unknown: `#888888` (gray)

## Key Constraints

- No image assets — all pixel art is drawn programmatically
- No third-party dependencies
- Characters are 18x18 pixel grids with transparent backgrounds
- Session detection uses `ps aux` polling (2s interval) + `lsof -p PID` for working directory
- Status hook files at `~/.pixpets/sessions/PID.json` with values: `working`, `idle`, `waiting`
