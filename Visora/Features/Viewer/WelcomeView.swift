import AppKit

final class WelcomeView: NSView {
    var chooseImageHandler: (() -> Void)?
    var chooseFolderHandler: (() -> Void)?
    var openPreferencesHandler: (() -> Void)?
    var droppedURLHandler: ((URL) -> Void)?
    var openRecentItemHandler: ((RecentItem) -> Void)?
    var clearRecentItemsHandler: (() -> Void)?

    var localizer: Localizer = .default {
        didSet { reloadLocalizedCopy() }
    }

    private let dropCardView = WelcomeDropCardView()
    private let brandLogoView = AppIconView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let chooseImageButton = NSButton(title: "", target: nil, action: nil)
    private let chooseFolderButton = NSButton(title: "", target: nil, action: nil)
    private let preferencesButton = NSButton(title: "", target: nil, action: nil)
    private let shortcutsBadgeStack = NSStackView()
    private let recentSectionStack = NSStackView()
    private let recentHeaderLabel = NSTextField(labelWithString: "")
    private let clearRecentButton = NSButton(title: "", target: nil, action: nil)
    private let recentItemsScrollView = NSScrollView()
    private let recentItemsStack = NSStackView()
    private var recentItems: [RecentItem] = []
    private let centerStack = NSStackView()
    private var logoWidthConstraint: NSLayoutConstraint?
    private var logoHeightConstraint: NSLayoutConstraint?
    private var recentScrollHeightConstraint: NSLayoutConstraint?
    private var isDragHighlighting = false {
        didSet {
            dropCardView.isDropActive = isDragHighlighting
            needsDisplay = true
        }
    }

    override var mouseDownCanMoveWindow: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = BrandStyle.backgroundColor.cgColor
        configureSubviews()
        installLayout()
        registerForDraggedTypes([.fileURL])
        reloadLocalizedCopy()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func updateRecentItems(_ items: [RecentItem]) {
        recentItems = items
        reloadRecentItems()
    }

    override func draw(_ dirtyRect: NSRect) {
        BrandStyle.backgroundColor.setFill()
        dirtyRect.fill()

        // 顶部中心极光光晕 + 右下角柔和暖色微光，赋予欢迎页呼吸感与深邃空间感
        let primaryCenter = NSPoint(x: bounds.midX, y: bounds.maxY * 0.72)
        let primaryColor = isDragHighlighting
            ? BrandStyle.accentColor.withAlphaComponent(0.20)
            : BrandStyle.accentColor.withAlphaComponent(0.11)
        if let primaryGlow = NSGradient(starting: primaryColor, ending: .clear) {
            primaryGlow.draw(
                fromCenter: primaryCenter,
                radius: 0,
                toCenter: primaryCenter,
                radius: max(bounds.width, bounds.height) * 0.56,
                options: []
            )
        }

        let secondaryCenter = NSPoint(x: bounds.midX * 1.35, y: bounds.maxY * 0.25)
        let secondaryColor = NSColor(calibratedRed: 0.24, green: 0.42, blue: 0.88, alpha: 0.08)
        if let secondaryGlow = NSGradient(starting: secondaryColor, ending: .clear) {
            secondaryGlow.draw(
                fromCenter: secondaryCenter,
                radius: 0,
                toCenter: secondaryCenter,
                radius: max(bounds.width, bounds.height) * 0.48,
                options: []
            )
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard Self.fileURL(from: sender) != nil else { return NSDragOperation() }
        animateDropHighlight(active: true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        animateDropHighlight(active: false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        animateDropHighlight(active: false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        animateDropHighlight(active: false)
        guard let url = Self.fileURL(from: sender) else { return false }
        droppedURLHandler?(url)
        return true
    }
}

private extension WelcomeView {
    func configureSubviews() {
        dropCardView.translatesAutoresizingMaskIntoConstraints = false
        brandLogoView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.97, alpha: 0.98)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = NSColor(white: 0.72, alpha: 0.86)
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 440

        shortcutsBadgeStack.translatesAutoresizingMaskIntoConstraints = false
        shortcutsBadgeStack.orientation = .horizontal
        shortcutsBadgeStack.alignment = .centerY
        shortcutsBadgeStack.spacing = 18

        recentHeaderLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        recentHeaderLabel.textColor = NSColor(white: 0.82, alpha: 0.9)

        clearRecentButton.translatesAutoresizingMaskIntoConstraints = false
        clearRecentButton.bezelStyle = .inline
        clearRecentButton.isBordered = false
        clearRecentButton.contentTintColor = NSColor(white: 0.7, alpha: 0.84)
        clearRecentButton.font = .systemFont(ofSize: 11, weight: .medium)
        clearRecentButton.target = self
        clearRecentButton.action = #selector(clearRecentButtonPressed)

        recentSectionStack.translatesAutoresizingMaskIntoConstraints = false
        recentSectionStack.orientation = .vertical
        recentSectionStack.alignment = .leading
        recentSectionStack.spacing = 10

        let recentHeaderRow = NSStackView(views: [recentHeaderLabel, NSView(), clearRecentButton])
        recentHeaderRow.orientation = .horizontal
        recentHeaderRow.alignment = .centerY
        recentHeaderRow.spacing = 8

        recentItemsStack.translatesAutoresizingMaskIntoConstraints = false
        recentItemsStack.orientation = .vertical
        recentItemsStack.alignment = .leading
        recentItemsStack.spacing = 6

        recentItemsScrollView.translatesAutoresizingMaskIntoConstraints = false
        recentItemsScrollView.drawsBackground = false
        recentItemsScrollView.borderType = .noBorder
        recentItemsScrollView.hasVerticalScroller = true
        recentItemsScrollView.autohidesScrollers = true
        recentItemsScrollView.documentView = recentItemsStack

        recentSectionStack.addArrangedSubview(recentHeaderRow)
        recentSectionStack.addArrangedSubview(recentItemsScrollView)

        styleAction(chooseImageButton, isPrimary: true)
        styleAction(chooseFolderButton, isPrimary: false)
        chooseImageButton.target = self
        chooseImageButton.action = #selector(chooseImageButtonPressed)
        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolderButtonPressed)

        preferencesButton.translatesAutoresizingMaskIntoConstraints = false
        preferencesButton.bezelStyle = .inline
        preferencesButton.isBordered = false
        preferencesButton.imagePosition = .imageLeading
        preferencesButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        preferencesButton.imageHugsTitle = true
        preferencesButton.font = .systemFont(ofSize: 12, weight: .medium)
        preferencesButton.contentTintColor = NSColor(white: 0.82, alpha: 0.9)
        preferencesButton.wantsLayer = true
        preferencesButton.layer?.cornerRadius = 8
        preferencesButton.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        preferencesButton.target = self
        preferencesButton.action = #selector(preferencesButtonPressed)
    }

    func installLayout() {
        let buttonRow = NSStackView(views: [chooseImageButton, chooseFolderButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 14
        buttonRow.alignment = .centerY
        buttonRow.detachesHiddenViews = true

        let dropContentStack = NSStackView(views: [brandLogoView, titleLabel, subtitleLabel, buttonRow])
        dropContentStack.translatesAutoresizingMaskIntoConstraints = false
        dropContentStack.orientation = .vertical
        dropContentStack.alignment = .centerX
        dropContentStack.spacing = 12
        dropContentStack.detachesHiddenViews = true
        dropContentStack.setCustomSpacing(18, after: brandLogoView)
        dropContentStack.setCustomSpacing(8, after: titleLabel)
        dropContentStack.setCustomSpacing(22, after: subtitleLabel)

        dropCardView.addSubview(dropContentStack)

        centerStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.orientation = .vertical
        centerStack.alignment = .centerX
        centerStack.spacing = 22
        centerStack.detachesHiddenViews = true
        centerStack.addArrangedSubview(dropCardView)
        centerStack.addArrangedSubview(recentSectionStack)

        addSubview(centerStack)
        addSubview(shortcutsBadgeStack)
        addSubview(preferencesButton)

        NSLayoutConstraint.activate([
            dropContentStack.leadingAnchor.constraint(equalTo: dropCardView.leadingAnchor, constant: 32),
            dropContentStack.trailingAnchor.constraint(equalTo: dropCardView.trailingAnchor, constant: -32),
            dropContentStack.topAnchor.constraint(equalTo: dropCardView.topAnchor, constant: 28),
            dropContentStack.bottomAnchor.constraint(equalTo: dropCardView.bottomAnchor, constant: -28),

            dropCardView.widthAnchor.constraint(equalTo: centerStack.widthAnchor),

            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            centerStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            centerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            centerStack.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 24),
            centerStack.bottomAnchor.constraint(lessThanOrEqualTo: shortcutsBadgeStack.topAnchor, constant: -18),
            centerStack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),

            recentItemsStack.widthAnchor.constraint(equalTo: recentItemsScrollView.contentView.widthAnchor),
            recentSectionStack.widthAnchor.constraint(equalTo: centerStack.widthAnchor),

            shortcutsBadgeStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            shortcutsBadgeStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            shortcutsBadgeStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            shortcutsBadgeStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),

            preferencesButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            preferencesButton.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            preferencesButton.heightAnchor.constraint(equalToConstant: 28),
            preferencesButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112)
        ])

        logoWidthConstraint = brandLogoView.widthAnchor.constraint(equalToConstant: BrandStyle.defaultLogoSize)
        logoHeightConstraint = brandLogoView.heightAnchor.constraint(equalToConstant: BrandStyle.defaultLogoSize)
        recentScrollHeightConstraint = recentItemsScrollView.heightAnchor.constraint(equalToConstant: 168)
        logoWidthConstraint?.isActive = true
        logoHeightConstraint?.isActive = true
        recentScrollHeightConstraint?.isActive = true
    }

    func reloadLocalizedCopy() {
        titleLabel.stringValue = localizer.string(.welcomeTitle)
        subtitleLabel.stringValue = localizer.string(.welcomeSubtitle)
        chooseImageButton.title = localizer.string(.chooseFileButton)
        chooseFolderButton.title = localizer.string(.chooseFolderButton)
        preferencesButton.title = " " + localizer.string(.preferences)
        recentHeaderLabel.stringValue = localizer.string(.recentFilesAndFolders)
        clearRecentButton.title = localizer.string(.clearRecentItems)
        rebuildShortcutBadges()
        reloadRecentItems()
    }

    func rebuildShortcutBadges() {
        shortcutsBadgeStack.arrangedSubviews.forEach { view in
            shortcutsBadgeStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let items: [(String, String)] = [
            ("⌘O", localizer.string(.openImage).replacingOccurrences(of: "...", with: "")),
            ("⌘⇧O", localizer.string(.openFolder).replacingOccurrences(of: "...", with: "")),
            ("⌘⇧V", localizer.string(.pinClipboard))
        ]

        for (keys, title) in items {
            shortcutsBadgeStack.addArrangedSubview(Self.makeShortcutBadgeItem(keys: keys, title: title))
        }
    }

    static func makeShortcutBadgeItem(keys: String, title: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6

        let keycap = NSTextField(labelWithString: keys)
        keycap.font = .monospacedSystemFont(ofSize: 10.5, weight: .semibold)
        keycap.textColor = NSColor(white: 0.86, alpha: 0.92)
        keycap.alignment = .center

        let keycapBox = NSView()
        keycapBox.translatesAutoresizingMaskIntoConstraints = false
        keycapBox.wantsLayer = true
        keycapBox.layer?.cornerRadius = 5
        keycapBox.layer?.cornerCurve = .continuous
        keycapBox.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        keycapBox.layer?.borderWidth = 1
        keycapBox.layer?.borderColor = NSColor(white: 1, alpha: 0.14).cgColor
        keycap.translatesAutoresizingMaskIntoConstraints = false
        keycapBox.addSubview(keycap)

        NSLayoutConstraint.activate([
            keycap.leadingAnchor.constraint(equalTo: keycapBox.leadingAnchor, constant: 6),
            keycap.trailingAnchor.constraint(equalTo: keycapBox.trailingAnchor, constant: -6),
            keycap.topAnchor.constraint(equalTo: keycapBox.topAnchor, constant: 2),
            keycap.bottomAnchor.constraint(equalTo: keycapBox.bottomAnchor, constant: -2)
        ])

        let desc = NSTextField(labelWithString: title)
        desc.font = .systemFont(ofSize: 11, weight: .regular)
        desc.textColor = NSColor(white: 0.62, alpha: 0.85)

        row.addArrangedSubview(keycapBox)
        row.addArrangedSubview(desc)
        return row
    }

    func styleAction(_ button: NSButton, isPrimary: Bool) {
        button.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 26.0, *) {
            button.bezelStyle = .glass
        } else {
            button.bezelStyle = .rounded
        }
        button.controlSize = .large
        button.font = .systemFont(ofSize: 13, weight: .medium)
        if isPrimary {
            button.keyEquivalent = "\r"
            button.bezelColor = BrandStyle.accentColor
        }
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 148).isActive = true
    }

    func animateDropHighlight(active: Bool) {
        isDragHighlighting = active
    }

    @objc func chooseImageButtonPressed() {
        chooseImageHandler?()
    }

    @objc func chooseFolderButtonPressed() {
        chooseFolderHandler?()
    }

    @objc func preferencesButtonPressed() {
        openPreferencesHandler?()
    }

    @objc func clearRecentButtonPressed() {
        clearRecentItemsHandler?()
    }

    func reloadRecentItems() {
        recentItemsStack.arrangedSubviews.forEach { view in
            recentItemsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        recentSectionStack.isHidden = recentItems.isEmpty
        clearRecentButton.isHidden = recentItems.isEmpty

        for item in recentItems {
            let rowCard = RecentItemRowView(item: item) { [weak self] selected in
                self?.openRecentItemHandler?(selected)
            }
            rowCard.translatesAutoresizingMaskIntoConstraints = false
            recentItemsStack.addArrangedSubview(rowCard)
            rowCard.widthAnchor.constraint(equalTo: recentItemsStack.widthAnchor).isActive = true
        }

        updateAdaptiveMetrics()
    }

    func updateAdaptiveMetrics() {
        let compactHeight = bounds.height < 560
        let veryCompactHeight = bounds.height < 470

        let logoSize: CGFloat = veryCompactHeight ? 56 : (compactHeight ? 72 : BrandStyle.defaultLogoSize)
        logoWidthConstraint?.constant = logoSize
        logoHeightConstraint?.constant = logoSize

        subtitleLabel.isHidden = veryCompactHeight
        shortcutsBadgeStack.isHidden = bounds.height < 360

        let maxVisibleRecentItems = veryCompactHeight ? 2 : (compactHeight ? 3 : 4)
        let visibleCount = min(recentItems.count, maxVisibleRecentItems)
        let rowHeight: CGFloat = 42
        let contentHeight = CGFloat(max(visibleCount, 1)) * rowHeight + CGFloat(max(visibleCount - 1, 0)) * recentItemsStack.spacing
        recentScrollHeightConstraint?.constant = min(max(contentHeight, 42), compactHeight ? 132 : 186)
    }

    static func fileURL(from sender: NSDraggingInfo) -> URL? {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            return first
        }
        guard let value = pasteboard.string(forType: .fileURL) else { return nil }
        return URL(string: value)
    }
}

extension WelcomeView {
    override func layout() {
        super.layout()
        updateAdaptiveMetrics()
    }
}

/// 欢迎页中心虚线发光拖放卡片
private final class WelcomeDropCardView: NSView {
    var isDropActive = false {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let cardRect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)

        let fillColor = isDropActive
            ? BrandStyle.accentColor.withAlphaComponent(0.10)
            : NSColor(white: 1, alpha: 0.03)
        fillColor.setFill()
        path.fill()

        let strokeColor = isDropActive
            ? BrandStyle.accentColor.withAlphaComponent(0.85)
            : NSColor(white: 1, alpha: 0.13)
        strokeColor.setStroke()
        path.lineWidth = isDropActive ? 2.0 : 1.2
        let pattern: [CGFloat] = [6, 5]
        path.setLineDash(pattern, count: pattern.count, phase: 0)
        path.stroke()
    }
}

/// 带文件图标底座、文件名、父目录副标题及鼠标悬停高亮的「最近打开」卡片行
private final class RecentItemRowView: NSView {
    private let item: RecentItem
    private let onSelect: (RecentItem) -> Void
    private let chevronView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            updateAppearance()
        }
    }

    init(item: RecentItem, onSelect: @escaping (RecentItem) -> Void) {
        self.item = item
        self.onSelect = onSelect
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        configureSubviews()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        onSelect(item)
    }

    private func configureSubviews() {
        let iconBadge = NSView()
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.wantsLayer = true
        iconBadge.layer?.cornerRadius = 6
        iconBadge.layer?.backgroundColor = (item.kind == .folder
            ? NSColor(calibratedRed: 0.25, green: 0.56, blue: 0.96, alpha: 0.18)
            : BrandStyle.accentColor.withAlphaComponent(0.18)).cgColor

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: item.kind == .folder ? "folder.fill" : "photo.fill",
            accessibilityDescription: item.displayName
        )
        iconView.contentTintColor = item.kind == .folder
            ? NSColor(calibratedRed: 0.42, green: 0.70, blue: 1.0, alpha: 0.95)
            : BrandStyle.accentColor
        iconBadge.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: item.displayName)
        nameLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        nameLabel.textColor = NSColor(white: 0.94, alpha: 0.96)
        nameLabel.lineBreakMode = .byTruncatingMiddle

        let parentPath = (item.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        let pathLabel = NSTextField(labelWithString: parentPath)
        pathLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        pathLabel.textColor = NSColor(white: 0.58, alpha: 0.85)
        pathLabel.lineBreakMode = .byTruncatingHead

        let textStack = NSStackView(views: [nameLabel, pathLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronView.contentTintColor = NSColor(white: 0.72, alpha: 0.8)

        let rowStack = NSStackView(views: [iconBadge, textStack, NSView(), chevronView])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),
            iconBadge.widthAnchor.constraint(equalToConstant: 28),
            iconBadge.heightAnchor.constraint(equalToConstant: 28),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            rowStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        toolTip = item.url.path
    }

    private func updateAppearance() {
        layer?.backgroundColor = isHovered
            ? NSColor(white: 1, alpha: 0.09).cgColor
            : NSColor(white: 1, alpha: 0.03).cgColor
        chevronView.alphaValue = isHovered ? 0.95 : 0.25
    }
}
