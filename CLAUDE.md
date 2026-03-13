# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pixpets is a native macOS menu bar app (Swift + AppKit, no third-party dependencies, minimum macOS 13). Each running AI coding agent session (Claude Code, Codex, Cursor CLI, OpenCode) appears as a small animated pixel character in a popover dropdown. The full spec lives in `docs/TASK.md`.

## Build & Run

```bash
swift build        # debug build
swift run          # build + run
swift build -c release  # release build
```

## Architecture

```
Sources/
  main.swift              → App entry, sets .accessory activation policy (no dock icon)
  AppDelegate.swift       → Creates MenuBarController + SessionManager
  SessionManager.swift    → Hybrid push/pull session detection (file watcher + 5s poll)
  MenuBarController.swift → Single NSStatusItem with popover, icon animation
  SessionsPopoverVC.swift → Popover with scrollable list of SessionRowView per session
  PixelCharacter.swift    → 18x18 pixel grids (idle/blink/walkA/walkB), bitmap renderer
  AgentType.swift         → Agent classification enum with colors
  Session.swift           → Session + SessionFile data models
  TerminalFocuser.swift   → Walks process tree to find parent .app, activates it
hooks/
  pixpets-hook.sh         → Claude Code hook script, writes session JSON on events
```

### Data Flow (Push Model)

```
Claude Code hook fires (PreToolUse/PostToolUse/Stop/SessionStart/SessionEnd)
  → pixpets-hook.sh writes ~/.pixpets/sessions/<session_id>.json
  → FSEvents watcher in SessionManager detects change
  → loadSessions() parses JSON, validates PIDs, deduplicates by PID
  → MenuBarController.sessionsDidUpdate() updates icon + popover
```

Hooks are configured globally in `~/.claude/settings.json` under the `hooks` key. The hook script receives JSON on stdin with `session_id`, `cwd`, `hook_event_name`.

### Session File Format

```json
{"pid": 1234, "status": "working", "project": "/path/to/project", "agent": "claude", "session_id": "uuid", "updated_at": 1710355000}
```

Status values: `working` (PreToolUse), `idle` (PostToolUse), `waiting` (Stop).

## Agent Color Map

- Claude Code: `#C96442` (terracotta)
- Codex: `#1A1A1A` (near black)
- Cursor CLI: `#4B6BFF` (blue)
- OpenCode: `#2DA44E` (green)
- Unknown: `#888888` (gray)

## Key Constraints

- No image assets — all pixel art drawn programmatically via NSBitmapImageRep
- No third-party dependencies
- Characters are 18x18 pixel grids, rendered at 2x (36x36 bitmap) for Retina
- Session detection is push-based (hooks) with pull fallback (5s poll for stale PID cleanup)
- Single menu bar icon with badge count, popover shows all sessions
- Terminal focusing walks process tree up to 10 levels to find parent .app bundle
