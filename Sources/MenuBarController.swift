import AppKit

class MenuBarController: NSObject, SessionManagerDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var popoverVC: SessionsPopoverVC!
    private var animTimer: Timer?
    private var animFrame: Int = 0
    private var sessions: [Session] = []
    private var eventMonitor: Any?

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
        renderIcon()

        // Update popover size if visible
        if popover.isShown {
            popover.contentSize = popoverVC.preferredSize
        }
    }

    // MARK: - Icon

    private func renderIcon() {
        let grid = animFrame % 2 == 0 ? PixelCharacter.idle : PixelCharacter.blink

        // Use first session's color, or gray if none
        let color: NSColor
        if let first = sessions.first {
            color = first.agentType.color
        } else {
            color = AgentType.unknown.color
        }

        let image = PixelCharacter.render(grid: grid, color: color)
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
