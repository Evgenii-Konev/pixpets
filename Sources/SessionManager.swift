import AppKit

protocol SessionManagerDelegate: AnyObject {
    func sessionsDidUpdate(_ sessions: [Session])
}

class SessionManager {
    weak var delegate: SessionManagerDelegate?
    private var pollTimer: Timer?
    private let sessionsDir: String
    private var fileWatcherSource: DispatchSourceFileSystemObject?

    init(delegate: SessionManagerDelegate) {
        self.delegate = delegate
        sessionsDir = NSHomeDirectory() + "/.pixpets/sessions"
        try? FileManager.default.createDirectory(atPath: sessionsDir, withIntermediateDirectories: true)
    }

    func startPolling() {
        // Initial read
        readSessionFiles()

        // Watch sessions directory for changes (push from hooks)
        startFileWatcher()

        // Poll every 1s to keep statuses responsive
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.readSessionFiles()
        }
    }

    // MARK: - File watcher (push-reactive)

    private func startFileWatcher() {
        let fd = open(sessionsDir, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .userInitiated)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.readSessionFiles()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatcherSource = source
    }

    // MARK: - Read session files

    private func readSessionFiles() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let sessions = self.loadSessions()
            DispatchQueue.main.async {
                self.delegate?.sessionsDidUpdate(sessions)
            }
        }
    }

    private func loadSessions() -> [Session] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: sessionsDir) else { return [] }

        struct Parsed {
            let session: Session
            let path: String
        }

        // Root sessions grouped by PID for dedup; sub-agents kept individually
        var rootsByPID: [Int32: [Parsed]] = [:]
        var subAgents: [Parsed] = []

        for file in files where file.hasSuffix(".json") {
            let path = "\(sessionsDir)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let sf = try? JSONDecoder().decode(SessionFile.self, from: data) else { continue }

            let pid = Int32(sf.pid)

            // Check if process is still alive (not dead or zombie)
            guard self.isProcessAlive(pid) else {
                try? fm.removeItem(atPath: path)
                continue
            }

            let agentType = sf.agent.flatMap { AgentType.detect(fromAgent: $0) } ?? .unknown
            let projectPath = sf.project ?? ""
            let updatedAt = sf.updated_at.map { Date(timeIntervalSince1970: Double($0)) } ?? Date()

            let interactive = sf.interactive ?? true
            var status = SessionStatus(rawValue: sf.status) ?? .idle
            // Non-interactive (-p) sessions never wait for user input
            if !interactive && status == .waiting {
                status = .working
            }

            let task: String? = sf.task.flatMap { $0.isEmpty ? nil : $0 }
            let parentPid: Int32? = sf.parent_pid.map { Int32($0) }

            let session = Session(
                pid: pid,
                agentType: agentType,
                projectPath: projectPath,
                projectName: (projectPath as NSString).lastPathComponent.isEmpty ? "unknown" : (projectPath as NSString).lastPathComponent,
                status: status,
                interactive: interactive,
                sessionId: sf.session_id,
                task: task,
                parentPid: parentPid,
                hostApp: sf.host_app,
                updatedAt: updatedAt
            )

            let parsed = Parsed(session: session, path: path)

            if parentPid != nil {
                // Sub-agent: don't deduplicate by PID (shares parent's PID)
                subAgents.append(parsed)
            } else {
                rootsByPID[pid, default: []].append(parsed)
            }
        }

        // Deduplicate root sessions: keep newest per PID, remove stale files
        var roots: [Session] = []
        for (_, entries) in rootsByPID {
            let sorted = entries.sorted { $0.session.updatedAt > $1.session.updatedAt }
            if let newest = sorted.first {
                roots.append(newest.session)
            }
            for stale in sorted.dropFirst() {
                try? fm.removeItem(atPath: stale.path)
            }
        }

        // Clean up orphaned sub-agents whose parent session file no longer exists
        let rootPIDs = Set(roots.map { $0.pid })
        var liveSubAgents: [Session] = []
        for sub in subAgents {
            let hasParent = sub.session.parentPid.map { rootPIDs.contains($0) } ?? false
            if !hasParent {
                // Parent session ended — clean up orphan
                try? fm.removeItem(atPath: sub.path)
            } else {
                liveSubAgents.append(sub.session)
            }
        }

        // Order: roots sorted by PID, sub-agents grouped under their parent
        let sortedRoots = roots.sorted { $0.pid < $1.pid }
        var ordered: [Session] = []
        for root in sortedRoots {
            ordered.append(root)
            let children = liveSubAgents
                .filter { $0.parentPid == root.pid }
                .sorted { ($0.sessionId ?? "") < ($1.sessionId ?? "") }
            ordered.append(contentsOf: children)
        }
        // Append orphaned sub-agents (parent already exited)
        let placedSessionIds = Set(ordered.compactMap { $0.sessionId })
        for s in liveSubAgents where !placedSessionIds.contains(s.sessionId ?? "") {
            ordered.append(s)
        }
        return ordered
    }

    // MARK: - Process liveness (zombie detection)

    private func isProcessAlive(_ pid: Int32) -> Bool {
        guard kill(pid, 0) == 0 else { return false }

        // Check for zombie state via ps
        let state = runPS("-p", "\(pid)", "-o", "state=")
        if state.isEmpty || state.hasPrefix("Z") { return false }

        // Check for orphaned ACP processes: walk parent chain looking for .app bundle.
        // If we reach PID 1 (init) without finding a .app, the process is orphaned
        // (its host app was reloaded/killed).
        var p = pid
        for _ in 0..<10 {
            let ppidStr = runPS("-p", "\(p)", "-o", "ppid=")
            guard let ppid = Int32(ppidStr), ppid > 1 else {
                // Reached init (PID 1) or invalid — orphaned
                return false
            }
            let comm = runPS("-p", "\(ppid)", "-o", "comm=")
            if comm.contains(".app") {
                return true  // Found host app — alive
            }
            p = ppid
        }
        // Exhausted walk without finding .app — could be terminal session (login shell → terminal)
        // For safety, consider alive
        return true
    }

    private func runPS(_ args: String...) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
