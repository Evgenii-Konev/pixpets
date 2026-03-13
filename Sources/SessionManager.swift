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

        // Parse all session files, grouped by PID
        struct Parsed {
            let session: Session
            let path: String
        }
        var byPID: [Int32: [Parsed]] = [:]

        for file in files where file.hasSuffix(".json") {
            let path = "\(sessionsDir)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let sf = try? JSONDecoder().decode(SessionFile.self, from: data) else { continue }

            let pid = Int32(sf.pid)

            // Check if process is still alive
            guard kill(pid, 0) == 0 else {
                try? fm.removeItem(atPath: path)
                continue
            }

            let agentType = sf.agent.flatMap { AgentType.detect(fromAgent: $0) } ?? .unknown
            let projectPath = sf.project ?? ""
            let updatedAt = sf.updated_at.map { Date(timeIntervalSince1970: Double($0)) } ?? Date()

            let session = Session(
                pid: pid,
                agentType: agentType,
                projectPath: projectPath,
                projectName: (projectPath as NSString).lastPathComponent.isEmpty ? "unknown" : (projectPath as NSString).lastPathComponent,
                status: SessionStatus(rawValue: sf.status) ?? .idle,
                sessionId: sf.session_id,
                updatedAt: updatedAt
            )

            byPID[pid, default: []].append(Parsed(session: session, path: path))
        }

        // Deduplicate: keep newest per PID, remove stale files
        var result: [Session] = []
        for (_, entries) in byPID {
            let sorted = entries.sorted { $0.session.updatedAt > $1.session.updatedAt }
            if let newest = sorted.first {
                result.append(newest.session)
            }
            // Clean up older duplicate files
            for stale in sorted.dropFirst() {
                try? fm.removeItem(atPath: stale.path)
            }
        }

        return result.sorted { $0.pid < $1.pid }
    }
}
