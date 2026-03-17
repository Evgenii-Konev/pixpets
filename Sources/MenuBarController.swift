import AppKit

class MenuBarController: NSObject, SessionManagerDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var popoverVC: SessionsPopoverVC!
    private var animTimer: Timer?
    private var animFrame: Int = 0
    private var sessions: [Session] = []
    private var eventMonitor: Any?

    // Status stability tracking
    private enum IconState { case noSessions, allIdle, hasWaiting, hasWorking }
    private var stableState: IconState = .noSessions
    private var stateEnteredAt: Date = Date()
    private var stabilityTimer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        popoverVC = SessionsPopoverVC()
        super.init()

        popover.contentViewController = popoverVC
        popover.behavior = .transient
        popover.animates = true

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        renderIcon()
        startIconAnimation()
    }

    // MARK: - SessionManagerDelegate

    func sessionsDidUpdate(_ sessions: [Session]) {
        self.sessions = sessions
        popoverVC.update(sessions: sessions)

        // Track state stability
        let newState = computeState()
        if newState != stableState {
            stableState = newState
            stateEnteredAt = Date()

            // Schedule a re-render at exactly 2s so badge appears promptly
            stabilityTimer?.invalidate()
            stabilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.renderIcon()
            }
        }

        renderIcon()

        // Update popover size if visible
        if popover.isShown {
            popover.contentSize = popoverVC.preferredSize
        }
    }

    private func computeState() -> IconState {
        if sessions.isEmpty { return .noSessions }
        if sessions.contains(where: { $0.status == .waiting }) { return .hasWaiting }
        if sessions.contains(where: { $0.status == .working }) { return .hasWorking }
        return .allIdle
    }

    // MARK: - Icon

    private func computeIconColor() -> NSColor {
        if sessions.isEmpty {
            return AgentType.unknown.color
        }
        let hasActive = sessions.contains(where: { $0.status == .working || $0.status == .waiting })
        if !hasActive {
            return NSColor.white
        }
        // Gradient: green → orange → red based on session count
        let count = sessions.count
        if count <= 1 {
            return NSColor(srgbRed: 0.3, green: 0.79, blue: 0.3, alpha: 1.0)
        }
        let t = min(Double(count - 1) / 4.0, 1.0)
        let r: CGFloat = min(0.3 + t * 0.7, 1.0)
        let g: CGFloat = t < 0.5
            ? 0.79 - t * 0.58   // green → orange: 0.79 → 0.50
            : 0.50 - (t - 0.5) * 1.0  // orange → red: 0.50 → 0.0
        let b: CGFloat = 0.3 * (1.0 - t)
        return NSColor(srgbRed: r, green: max(g, 0), blue: b, alpha: 1.0)
    }

    private func renderIcon() {
        let grid = animFrame % 2 == 0 ? PixelCharacter.idle : PixelCharacter.blink
        let isStable = Date().timeIntervalSince(stateEnteredAt) >= 2.0

        let color = computeIconColor()

        // Choose badge
        let badge: [[Int]]?
        let badgeColor: NSColor
        if sessions.isEmpty {
            badge = nil; badgeColor = .clear
        } else if isStable && sessions.allSatisfy({ $0.status == .idle }) {
            badge = PixelCharacter.sleepZzz
            badgeColor = NSColor(srgbRed: 0.55, green: 0.75, blue: 1.0, alpha: 1.0)
        } else if isStable && sessions.contains(where: { $0.status == .waiting }) {
            badge = PixelCharacter.chatBubble
            badgeColor = .white
        } else {
            badge = nil; badgeColor = .clear
        }

        let image = PixelCharacter.renderWithBadge(
            grid: grid, color: color,
            badge: badge, badgeColor: badgeColor
        )
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly

        // Show count badge
        if sessions.count > 1 {
            statusItem.button?.title = "\(sessions.count)"
            statusItem.button?.imagePosition = .imageLeft
            statusItem.length = 42
        } else {
            statusItem.button?.title = ""
            statusItem.button?.imagePosition = .imageOnly
            statusItem.length = 26
        }
    }

    private func startIconAnimation() {
        animTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animFrame = 1
            self.renderIcon()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.animFrame = 0
                self.renderIcon()
            }
        }
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            popover.contentSize = popoverVC.preferredSize
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popoverVC.startAnimations()
            popoverVC.update(sessions: sessions)

            // Close on any click outside
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.close()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit pixpets", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}