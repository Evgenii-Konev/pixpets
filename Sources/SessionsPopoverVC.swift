import AppKit

class SessionsPopoverVC: NSViewController {
    private var sessions: [Session] = []
    private var rowViews: [SessionRowView] = []
    private let stackView = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No active agents")
    private let scrollView = NSScrollView()

    var preferredSize: NSSize {
        if sessions.isEmpty {
            return NSSize(width: 300, height: 60)
        }
        let h = min(CGFloat(sessions.count) * 64 + 16, 400)
        // Dynamic width based on longest text row
        let nameFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let detailFont = NSFont.systemFont(ofSize: 11)
        let maxTextWidth = sessions.map { s -> CGFloat in
            let nameW = (s.projectName as NSString).size(withAttributes: [.font: nameFont]).width
            let statusLabel: String
            switch s.status {
            case .idle:    statusLabel = "\(s.agentType.displayName)  💤 idle"
            case .working: statusLabel = "\(s.agentType.displayName)  ⚡ working"
            case .waiting: statusLabel = "\(s.agentType.displayName)  👋 waiting for input"
            }
            let detailW = (statusLabel as NSString).size(withAttributes: [.font: detailFont]).width
            return max(nameW, detailW)
        }.max() ?? 100
        // 8 (pad) + 36 (icon) + 10 (gap) + text + 8 (gap) + 120 (buttons) + 8 (pad)
        let w = max(320, min(ceil(maxTextWidth) + 190, 550))
        return NSSize(width: w, height: h)
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))

        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let docView = NSView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        docView.addSubview(stackView)

        scrollView.documentView = docView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scrollView)

        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: docView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: docView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        self.view = container
    }

    func update(sessions: [Session]) {
        self.sessions = sessions
        emptyLabel.isHidden = !sessions.isEmpty
        scrollView.isHidden = sessions.isEmpty

        // Rebuild rows
        for rv in rowViews { rv.removeFromSuperview() }
        rowViews.removeAll()

        for session in sessions {
            let row = SessionRowView(session: session)
            stackView.addArrangedSubview(row)
            rowViews.append(row)
        }
    }

    func startAnimations() {
        for rv in rowViews {
            rv.startAnimation()
        }
    }
}

// MARK: - Session Row View

class SessionRowView: NSView {
    private let session: Session
    private let charImageView = NSImageView()
    private var animTimer: Timer?
    private var animFrame: Int = 0

    init(session: Session) {
        self.session = session
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6

        // Character image
        charImageView.translatesAutoresizingMaskIntoConstraints = false
        charImageView.imageScaling = .scaleProportionallyUpOrDown
        let charImage = PixelCharacter.render(grid: PixelCharacter.idle, color: session.agentType.color, pixelSize: 3)
        charImageView.image = charImage
        addSubview(charImageView)

        // Project name
        let nameLabel = NSTextField(labelWithString: session.projectName)
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        // Agent + status
        let statusText: String
        switch session.status {
        case .idle:    statusText = "💤 idle"
        case .working: statusText = "⚡ working"
        case .waiting: statusText = "👋 waiting for input"
        }
        let detailLabel = NSTextField(labelWithString: "\(session.agentType.displayName)  \(statusText)")
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailLabel)

        // Action buttons
        let focusBtn = makeButton(title: "Focus", action: #selector(focusTerminal))
        let finderBtn = makeButton(title: "Finder", action: #selector(openInFinder))

        let btnStack = NSStackView(views: [focusBtn, finderBtn])
        btnStack.spacing = 4
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(btnStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),

            charImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            charImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            charImageView.widthAnchor.constraint(equalToConstant: 36),
            charImageView.heightAnchor.constraint(equalToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: charImageView.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: btnStack.leadingAnchor, constant: -8),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: btnStack.leadingAnchor, constant: -8),

            btnStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            btnStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Hover tracking
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .recessed
        btn.controlSize = .small
        btn.font = .systemFont(ofSize: 10)
        return btn
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    func startAnimation() {
        animTimer?.invalidate()

        switch session.status {
        case .idle:
            animTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.charImageView.image = PixelCharacter.render(
                    grid: PixelCharacter.blink, color: self.session.agentType.color, pixelSize: 3)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.charImageView.image = PixelCharacter.render(
                        grid: PixelCharacter.idle, color: self.session.agentType.color, pixelSize: 3)
                }
            }
        case .working:
            animTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.animFrame += 1
                let grid = self.animFrame % 2 == 0 ? PixelCharacter.walkA : PixelCharacter.walkB
                self.charImageView.image = PixelCharacter.render(
                    grid: grid, color: self.session.agentType.color, pixelSize: 3)
            }
        case .waiting:
            animTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.animFrame += 1
                let grid = self.animFrame % 2 == 0 ? PixelCharacter.idle : PixelCharacter.blink
                self.charImageView.image = PixelCharacter.render(
                    grid: grid, color: self.session.agentType.color, pixelSize: 3)
            }
        }
    }

    override func removeFromSuperview() {
        animTimer?.invalidate()
        super.removeFromSuperview()
    }

    // MARK: - Actions

    @objc private func focusTerminal() {
        TerminalFocuser.focus(pid: session.pid)
    }

    @objc private func openInFinder() {
        guard !session.projectPath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: session.projectPath))
    }
}
