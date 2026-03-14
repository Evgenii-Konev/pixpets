import AppKit
import Foundation

// Handle --install-hooks before starting the app
if CommandLine.arguments.contains("--install-hooks") {
    installHooks()
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

    // Resolve symlinks to find the real binary location (swift run uses symlinks)
    let resolvedBinary = (CommandLine.arguments[0] as NSString).resolvingSymlinksInPath
    let repoHook = URL(fileURLWithPath: resolvedBinary)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("hooks/pixpets-hook.sh").path

    // Also check current working directory
    let cwdHook = fileManager.currentDirectoryPath + "/hooks/pixpets-hook.sh"

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

    // 2. Copy hook to ~/.pixpets/hooks/
    let hookDir = "\(home)/.pixpets/hooks"
    let destHook = "\(hookDir)/pixpets-hook.sh"

    do {
        try fileManager.createDirectory(atPath: hookDir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destHook) {
            try fileManager.removeItem(atPath: destHook)
        }
        try fileManager.copyItem(atPath: sourceHook, toPath: destHook)

        // Make executable
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try fileManager.setAttributes(attrs, ofItemAtPath: destHook)
        print("Installed hook: \(destHook)")
    } catch {
        print("Error installing hook: \(error.localizedDescription)")
        exit(1)
    }

    // 3. Update ~/.claude/settings.json
    let settingsPath = "\(home)/.claude/settings.json"
    updateClaudeSettings(settingsPath: settingsPath, hookPath: destHook)

    print("")
    print("PixPets hooks installed successfully!")
    print("Claude Code will now report sessions to PixPets.")
}

private func updateClaudeSettings(settingsPath: String, hookPath: String) {
    let fileManager = FileManager.default

    // Read existing settings or start fresh
    var settings: [String: Any]
    if let data = fileManager.contents(atPath: settingsPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        settings = json
    } else {
        settings = [:]
    }

    // Build the hook entry in Claude Code's expected format:
    // { hooks: [{ type: "command", command: "...", async: true }] }
    let hookEntry: [String: Any] = [
        "hooks": [
            [
                "type": "command",
                "command": hookPath,
                "async": true
            ]
        ]
    ]

    // Events to hook into
    let events = ["PreToolUse", "PostToolUse", "Stop", "SessionStart", "SessionEnd", "UserPromptSubmit"]

    // Get or create hooks dict
    var hooks = settings["hooks"] as? [String: Any] ?? [:]

    for event in events {
        var eventHooks = hooks[event] as? [[String: Any]] ?? []

        // Check if already installed (search inside nested hooks arrays)
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

    // Write back
    do {
        let dir = (settingsPath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath))
        print("Updated Claude settings: \(settingsPath)")
    } catch {
        print("Error updating Claude settings: \(error.localizedDescription)")
        print("You may need to manually add the hook to ~/.claude/settings.json")
    }
}
