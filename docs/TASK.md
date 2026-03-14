# pixpets — macOS Menu Bar App

## Goal

Build a native macOS menu bar app called **pixpets**.

Each active AI coding agent session (Claude Code, Codex, OpenCode, Cursor CLI) appears as a small animated pixel character in the menu bar. Each character = one session.

---

## Tech Stack

- Swift + AppKit only
- No third-party dependencies
- Minimum macOS 13

---

## Pixel Character Design

Design an **original** pixel robot character. Do not copy or derive from any existing logo or brand asset.

Character requirements:
- Size: 18x18 pixels, drawn on a grid
- Shape: small blocky robot — square body, two legs, two eyes, optional small arms
- Must look original, not referencing Claude Code, OpenAI, or any other brand logo
- Transparent background
- Drawn programmatically in Swift using `NSBezierPath` or pixel array — no image assets

Each agent type has its own color:
- Claude Code → `#C96442` (terracotta)
- Codex → `#1A1A1A` (near black)
- Cursor CLI → `#4B6BFF` (blue)
- OpenCode → `#2DA44E` (green)
- Unknown → `#888888` (gray)

---

## Session Detection

Poll every 2 seconds using `ps aux`.

Look for processes:
- `claude` → Claude Code
- `codex` → Codex
- `cursor` → Cursor CLI
- `opencode` → OpenCode

For each found PID:
- Get working directory: `lsof -p PID | grep cwd`
- Extract project folder name from path

One `NSStatusItem` per PID. Remove item when process exits.

---

## Session Status via Hooks

Read status from `~/.pixpets/sessions/PID.json`.

File format:
```json
{"pid": 1234, "status": "working", "project": "/Users/me/myapp"}
```

Status values: `working`, `idle`, `waiting`

Create hook scripts that write this file. Install hooks to:
- Claude Code: `~/.claude/hooks/`
- Other agents: document hook paths in README

Hook events:
- `PreToolUse` → write `working`
- `PostToolUse` → write `idle`
- `Stop` (waiting for user) → write `waiting`

---

## Animation

Three animation states per character:

**idle** — character stands still, blinks every 3 seconds (swap eye pixels on/off)

**working** — character walks: shift left leg and right leg pixels alternately, 4fps

**waiting** — character stands still, `!` badge appears above head, pulses on/off every 1 second

Use `Timer` to drive animation frames. Draw each frame by redrawing the `NSView`.

---

## UI Behavior

**Hover (NSToolTip):**
```
Project: myapp
Path: /Users/me/projects/myapp
Agent: Claude Code
Status: working
```

**Status = waiting → show NSPopover:**
- Popover appears below the character automatically
- Text: `"Hey! Waiting for you 👀"`
- No close button — closes automatically when status changes to `idle` or `working`
- Only one popover visible at a time

**Click on character:**
Try to focus the terminal where this session runs.

1. Get PPID of the claude/codex/etc process
2. Find parent process name (`ps -p PPID -o comm=`)
3. Switch by terminal:
   - `iTerm2` → AppleScript: `tell application "iTerm2" to activate`, then find session by PID
   - `Ghostty` → `open -a "Ghostty"` + AppleScript activate
   - `Zed` → `open -a "Zed"`
   - `Cursor` → `open -a "Cursor"`
   - fallback → show `NSAlert` with project path

---

## App Behavior

- No Dock icon (`LSUIElement = true` in Info.plist)
- No main window
- App starts on login — generate a `LaunchAgent` plist at `~/Library/LaunchAgents/com.pixpets.app.plist` on first run, with opt-in prompt
- Right-click on any character → context menu:
  - "Open project in Finder"
  - "Copy project path"
  - separator
  - "Quit pixpets"

---

## File Structure

```
pixpets/
├── App/
│   ├── AppDelegate.swift
│   └── Info.plist
├── MenuBar/
│   ├── SessionManager.swift      # process polling, status file reading
│   ├── StatusItemController.swift # NSStatusItem per session
│   └── TerminalFocuser.swift     # click → focus terminal
├── Character/
│   ├── PixelCharacter.swift      # pixel grid definition, colors
│   └── CharacterView.swift       # NSView, animation loop
├── Hooks/
│   └── HookInstaller.swift       # writes hook scripts for each agent
└── README.md
```

---

## What to Build in v1

- [ ] Process polling and PID tracking
- [ ] Original pixel character, 3 animation states
- [ ] Agent color coding
- [ ] Status file reading from hooks
- [ ] Hover tooltip
- [ ] Waiting popover
- [ ] Click → focus terminal (iTerm2 + Ghostty priority)
- [ ] Right-click context menu
- [ ] No dock icon
- [ ] Hook installer for Claude Code

---

## Out of Scope for v1

- Settings UI
- Session history
- Remote/SSH sessions
- Homebrew Cask distribution (planned for later)
- Support for agents beyond the four listed

---

## Distribution (future)

Will distribute via Homebrew Cask: `brew install --cask pixpets`
Requires: Apple Developer ID signing + notarization + GitHub release with .dmg
