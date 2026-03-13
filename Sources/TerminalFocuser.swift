import AppKit

enum TerminalFocuser {
    static func focus(pid: Int32) {
        guard let appPath = findParentApp(pid: pid) else {
            let alert = NSAlert()
            alert.messageText = "Cannot detect terminal"
            alert.informativeText = "PID: \(pid)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
    }

    /// Walk up the process tree until we find a .app bundle
    private static func findParentApp(pid: Int32) -> String? {
        var current = pid
        // Walk up to 10 levels to avoid infinite loops
        for _ in 0..<10 {
            let ppid = getParentPID(current)
            guard ppid > 1 else { return nil }

            let comm = getProcessComm(ppid)
            // Check if the process path is inside a .app bundle
            if let appPath = extractAppPath(from: comm) {
                return appPath
            }
            current = ppid
        }
        return nil
    }

    /// Extract "/Applications/Foo.app" from a full binary path like
    /// "/Applications/Foo.app/Contents/MacOS/foo"
    private static func extractAppPath(from processPath: String) -> String? {
        guard let range = processPath.range(of: ".app") else { return nil }
        return String(processPath[..<range.upperBound])
    }

    private static func getParentPID(_ pid: Int32) -> Int32 {
        let output = runPS(["-p", "\(pid)", "-o", "ppid="])
        return Int32(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func getProcessComm(_ pid: Int32) -> String {
        return runPS(["-p", "\(pid)", "-o", "comm="]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runPS(_ args: [String]) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = args
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
