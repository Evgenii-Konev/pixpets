import AppKit
import Foundation

let appVersion = "0.4.0"

// Install/update hooks on every launch
installHooks()

// If called with --install-hooks, exit after installation
if CommandLine.arguments.contains("--install-hooks") {
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()

// MARK: - Hook Installation

private func installHooks() {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser.path

    // 1. Find the hook script (bundled in .app Resources, or fallback to repo)
    let bundledHook = Bundle.main.resourcePath.map { "\($0)/pixpets-hook.sh" }
    let bundledPlugin = Bundle.main.resourcePath.map { "\($0)/pixpets-opencode-plugin.js" }

    // Resolve symlinks to find the real binary location (swift run uses symlinks)
    let resolvedBinary = (CommandLine.arguments[0] as NSString).resolvingSymlinksInPath
    let repoBase = URL(fileURLWithPath: resolvedBinary)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let repoHook = repoBase.appendingPathComponent("hooks/pixpets-hook.sh").path
    let repoPlugin = repoBase.appendingPathComponent("hooks/pixpets-opencode-plugin.js").path

    // Also check current working directory
    let cwdBase = fileManager.currentDirectoryPath
    let cwdHook = cwdBase + "/hooks/pixpets-hook.sh"
    let cwdPlugin = cwdBase + "/hooks/pixpets-opencode-plugin.js"

    let sourceHook: String
    if let bundled = bundledHook, fileManager.fileExists(atPath: bundled) {
        sourceHook = bundled
    } else if fileManager.fileExists(atPath: repoHook) {
        sourceHook = repoHook
    } else if fileManager.fileExists(atPath: cwdHook) {
        sourceHook = cwdHook
    } else {
        print("Error: Could not find pixpets-hook.sh")
        print("Run this command from the PixPets project directory, or use the installed .app.")
        exit(1)
    }

    let sourcePlugin: String?
    if let bundled = bundledPlugin, fileManager.fileExists(atPath: bundled) {
        sourcePlugin = bundled
    } else if fileManager.fileExists(atPath: repoPlugin) {
        sourcePlugin = repoPlugin
    } else if fileManager.fileExists(atPath: cwdPlugin) {
        sourcePlugin = cwdPlugin
    } else {
        sourcePlugin = nil
    }

    // 2. Copy hook to ~/.pixpets/hooks/
    let hookDir = "\(home)/.pixpets/hooks"
    let destHook = "\(hookDir)/pixpets-hook.sh"
    let destPlugin = "\(hookDir)/pixpets-opencode-plugin.js"

    do {
        try fileManager.createDirectory(atPath: hookDir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destHook) {
            try fileManager.removeItem(atPath: destHook)
        }
        try fileManager.copyItem(atPath: sourceHook, toPath: destHook)
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try fileManager.setAttributes(attrs, ofItemAtPath: destHook)

        if let src = sourcePlugin {
            if fileManager.fileExists(atPath: destPlugin) {
                try fileManager.removeItem(atPath: destPlugin)
            }
            try fileManager.copyItem(atPath: src, toPath: destPlugin)
        }
    } catch {
        print("Error installing hook: \(error.localizedDescription)")
        exit(1)
    }

    // 3. Install hooks for each agent
    print("Installing PixPets hooks...")
    print("")

    var installedCount = 0

    // --- Claude Code ---
    let claudeSettingsPath = "\(home)/.claude/settings.json"
    if fileManager.fileExists(atPath: "\(home)/.claude") {
        installClaudeHooks(settingsPath: claudeSettingsPath, hookPath: destHook)
        print("  \u{2713} Claude Code  \u{2014} hooks registered in ~/.claude/settings.json")
        installedCount += 1
    } else {
        print("  \u{2717} Claude Code  \u{2014} ~/.claude/ not found (install Claude Code first)")
    }

    // --- Cursor ---
    let cursorDir = "\(home)/.cursor"
    if fileManager.fileExists(atPath: cursorDir) {
        installCursorHooks(configDir: cursorDir, hookPath: destHook)
        print("  \u{2713} Cursor       \u{2014} hooks registered in ~/.cursor/hooks.json")
        installedCount += 1
    } else {
        print("  \u{2717} Cursor       \u{2014} ~/.cursor/ not found (install Cursor first)")
    }

    // --- Codex ---
    let codexDir = "\(home)/.codex"
    if fileManager.fileExists(atPath: codexDir) {
        installCodexHooks(configDir: codexDir, hookPath: destHook)
        print("  \u{2713} Codex        \u{2014} hooks registered in ~/.codex/hooks.json")
        installedCount += 1
    } else {
        print("  \u{2717} Codex        \u{2014} ~/.codex/ not found (install Codex CLI first)")
    }

    // --- OpenCode ---
    let opencodeDir = "\(home)/.config/opencode"
    if fileManager.fileExists(atPath: opencodeDir), sourcePlugin != nil {
        installOpenCodePlugin(configDir: opencodeDir, pluginSource: destPlugin)
        print("  \u{2713} OpenCode     \u{2014} plugin installed in ~/.config/opencode/plugins/")
        installedCount += 1
    } else if sourcePlugin == nil {
        print("  \u{2717} OpenCode     \u{2014} pixpets-opencode-plugin.js not found")
    } else {
        print("  \u{2717} OpenCode     \u{2014} ~/.config/opencode/ not found (install OpenCode first)")
    }

    print("")
    print("PixPets hooks installed for \(installedCount) agent\(installedCount == 1 ? "" : "s").")
}

// MARK: - Claude Code Hooks

private func installClaudeHooks(settingsPath: String, hookPath: String) {
    let fileManager = FileManager.default

    var settings: [String: Any]
    if let data = fileManager.contents(atPath: settingsPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        settings = json
    } else {
        settings = [:]
    }

    let hookEntry: [String: Any] = [
        "hooks": [
            [
                "type": "command",
                "command": hookPath,
                "async": true
            ]
        ]
    ]

    let events = ["PreToolUse", "PostToolUse", "Stop", "SessionStart", "SessionEnd", "UserPromptSubmit"]
    var hooks = settings["hooks"] as? [String: Any] ?? [:]

    for event in events {
        var eventHooks = hooks[event] as? [[String: Any]] ?? []
        let alreadyInstalled = eventHooks.contains { entry in
            if let innerHooks = entry["hooks"] as? [[String: Any]] {
                return innerHooks.contains { ($0["command"] as? String)?.contains("pixpets-hook") == true }
            }
            return (entry["command"] as? String)?.contains("pixpets-hook") == true
        }
        if !alreadyInstalled {
            eventHooks.append(hookEntry)
            hooks[event] = eventHooks
        }
    }

    settings["hooks"] = hooks

    do {
        let dir = (settingsPath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath))
    } catch {
        print("  Warning: Could not update Claude settings: \(error.localizedDescription)")
    }
}

// MARK: - Cursor Hooks

private func installCursorHooks(configDir: String, hookPath: String) {
    let fileManager = FileManager.default
    let hooksPath = "\(configDir)/hooks.json"
    let command = "\(hookPath) --agent cursor"

    var config: [String: Any]
    if let data = fileManager.contents(atPath: hooksPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        config = json
    } else {
        config = [:]
    }

    config["version"] = 1

    let events = ["preToolUse", "postToolUse", "stop", "sessionStart", "sessionEnd", "beforeSubmitPrompt"]
    var hooks = config["hooks"] as? [String: Any] ?? [:]

    for event in events {
        var eventHooks = hooks[event] as? [[String: Any]] ?? []
        let alreadyInstalled = eventHooks.contains { entry in
            return (entry["command"] as? String)?.contains("pixpets-hook") == true
        }
        if !alreadyInstalled {
            let entry: [String: Any] = [
                "command": command,
                "type": "command",
                "timeout": 5
            ]
            eventHooks.append(entry)
            hooks[event] = eventHooks
        }
    }

    config["hooks"] = hooks

    do {
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: hooksPath))
    } catch {
        print("  Warning: Could not update Cursor hooks: \(error.localizedDescription)")
    }
}

// MARK: - Codex Hooks

private func installCodexHooks(configDir: String, hookPath: String) {
    let fileManager = FileManager.default
    let hooksPath = "\(configDir)/hooks.json"
    let configTomlPath = "\(configDir)/config.toml"
    let command = "\(hookPath) --agent codex"

    // 1. Enable codex_hooks feature flag in config.toml
    enableCodexHooksFeature(configTomlPath: configTomlPath)

    // 2. Install hooks.json (format: { "hooks": { "SessionStart": [...], "Stop": [...] } })
    var config: [String: Any]
    if let data = fileManager.contents(atPath: hooksPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        config = json
    } else {
        config = [:]
    }

    var hooks = config["hooks"] as? [String: Any] ?? [:]
    let events = ["SessionStart", "Stop"]

    for event in events {
        var eventHooks = hooks[event] as? [[String: Any]] ?? []
        let alreadyInstalled = eventHooks.contains { entry in
            if let innerHooks = entry["hooks"] as? [[String: Any]] {
                return innerHooks.contains { ($0["command"] as? String)?.contains("pixpets-hook") == true }
            }
            return (entry["command"] as? String)?.contains("pixpets-hook") == true
        }
        if !alreadyInstalled {
            let entry: [String: Any] = [
                "hooks": [
                    [
                        "type": "command",
                        "command": command
                    ]
                ]
            ]
            eventHooks.append(entry)
            hooks[event] = eventHooks
        }
    }

    config["hooks"] = hooks

    do {
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: hooksPath))
    } catch {
        print("  Warning: Could not update Codex hooks: \(error.localizedDescription)")
    }
}

private func enableCodexHooksFeature(configTomlPath: String) {
    let fileManager = FileManager.default
    var content: String
    if let data = fileManager.contents(atPath: configTomlPath),
       let str = String(data: data, encoding: .utf8) {
        content = str
    } else {
        content = ""
    }

    // Check if codex_hooks is already enabled
    if content.contains("codex_hooks") { return }

    // Add feature flag and suppress warning
    if content.contains("[features]") {
        content = content.replacingOccurrences(of: "[features]", with: "[features]\ncodex_hooks = true")
    } else {
        content += "\nsuppress_unstable_features_warning = true\n\n[features]\ncodex_hooks = true\n"
    }

    do {
        try content.write(toFile: configTomlPath, atomically: true, encoding: .utf8)
    } catch {
        print("  Warning: Could not enable codex_hooks feature: \(error.localizedDescription)")
    }
}

// MARK: - OpenCode Plugin

private func installOpenCodePlugin(configDir: String, pluginSource: String) {
    let fileManager = FileManager.default
    let pluginsDir = "\(configDir)/plugins"
    let destPlugin = "\(pluginsDir)/pixpets.js"

    do {
        try fileManager.createDirectory(atPath: pluginsDir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destPlugin) {
            try fileManager.removeItem(atPath: destPlugin)
        }
        try fileManager.copyItem(atPath: pluginSource, toPath: destPlugin)
    } catch {
        print("  Warning: Could not install OpenCode plugin: \(error.localizedDescription)")
    }
}
