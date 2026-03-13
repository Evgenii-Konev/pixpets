import AppKit

enum AgentType: String, CaseIterable {
    case claude
    case codex
    case cursor
    case opencode
    case unknown

    var color: NSColor {
        switch self {
        case .claude:   return NSColor(red: 0xC9/255, green: 0x64/255, blue: 0x42/255, alpha: 1) // #C96442
        case .codex:    return NSColor(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1) // #1A1A1A
        case .cursor:   return NSColor(red: 0x4B/255, green: 0x6B/255, blue: 0xFF/255, alpha: 1) // #4B6BFF
        case .opencode: return NSColor(red: 0x2D/255, green: 0xA4/255, blue: 0x4E/255, alpha: 1) // #2DA44E
        case .unknown:  return NSColor(red: 0x88/255, green: 0x88/255, blue: 0x88/255, alpha: 1) // #888888
        }
    }

    var displayName: String {
        switch self {
        case .claude:   return "Claude Code"
        case .codex:    return "Codex"
        case .cursor:   return "Cursor CLI"
        case .opencode: return "OpenCode"
        case .unknown:  return "Unknown"
        }
    }

    /// Detect from agent name string in session JSON (push model)
    static func detect(fromAgent agent: String) -> AgentType? {
        switch agent.lowercased() {
        case "claude", "claude-code": return .claude
        case "codex":                 return .codex
        case "cursor":                return .cursor
        case "opencode":              return .opencode
        default:                      return nil
        }
    }

    /// Detect from process path (legacy poll model)
    static func detect(fromProcess processPath: String) -> AgentType? {
        if processPath.contains(".app/") { return nil }
        let binaryName = (processPath as NSString).lastPathComponent.lowercased()
        switch binaryName {
        case "claude":   return .claude
        case "codex":    return .codex
        case "opencode": return .opencode
        default:         return nil
        }
    }
}
