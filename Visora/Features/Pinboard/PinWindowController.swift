import AppKit

final class PinWindowController: NSWindowController {
    init(image: NSImage, title: String, localizer: Localizer = .default) {
        let viewController = PinContainerViewController(contentViewController: PinImageViewController(image: image), localizer: localizer)
        let initialSize = PinWindowLayout.initialWindowSize(for: image.size)
        let window = Self.makeWindow(title: title, initialSize: initialSize, viewController: viewController)

        super.init(window: window)
    }

    init(text: String, title: String, localizer: Localizer = .default) {
        let viewController = PinContainerViewController(contentViewController: PinTextViewController(text: text), localizer: localizer)
        let initialSize = PinWindowLayout.initialTextWindowSize(characterCount: text.count)
        let window = Self.makeWindow(title: title, initialSize: initialSize, viewController: viewController)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private extension PinWindowController {
    static func makeWindow(title: String, initialSize: NSSize, viewController: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentViewController = viewController
        window.center()
        return window
    }
}

private final class PinContainerViewController: NSViewController {
    private let contentViewController: NSViewController
    private let localizer: Localizer
    private let contentHost = NSView()
    private let controlsPill = AdaptiveGlassSurfaceView(shape: .capsule, isInteractive: true)
    private let opacityLabel = NSTextField(labelWithString: "")
    private let lockButton = NSButton(title: "", target: nil, action: nil)
    private var isLocked = false

    init(contentViewController: NSViewController, localizer: Localizer) {
        self.contentViewController = contentViewController
        self.localizer = localizer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let rootView = PinHoverContainerView()
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 12
        rootView.layer?.cornerCurve = .continuous
        rootView.layer?.masksToBounds = true
        rootView.layer?.borderWidth = 1
        rootView.layer?.borderColor = NSColor(white: 1, alpha: 0.16).cgColor
        rootView.layer?.backgroundColor = NSColor(red: 0.035, green: 0.038, blue: 0.045, alpha: 1).cgColor
        rootView.hoverChangedHandler = { [weak self] hovering in
            self?.setControlsVisible(hovering)
        }
        view = rootView

        contentHost.translatesAutoresizingMaskIntoConstraints = false
        controlsPill.translatesAutoresizingMaskIntoConstraints = false
        controlsPill.alphaValue = 0

        configureControlsPill()

        view.addSubview(contentHost)
        view.addSubview(controlsPill)

        NSLayoutConstraint.activate([
            contentHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: view.topAnchor),
            contentHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            controlsPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlsPill.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            controlsPill.heightAnchor.constraint(equalToConstant: 32)
        ])

        embedContent()
        updateOpacityLabel()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateOpacityLabel()
    }
}

private extension PinContainerViewController {
    func embedContent() {
        addChild(contentViewController)
        let contentView = contentViewController.view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: contentHost.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])
    }

    func configureControlsPill() {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        opacityLabel.textColor = NSColor(white: 0.92, alpha: 0.95)
        opacityLabel.alignment = .center
        opacityLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true

        lockButton.target = self
        lockButton.action = #selector(toggleLockState)
        lockButton.bezelStyle = .inline
        lockButton.font = .systemFont(ofSize: 11, weight: .medium)
        updateLockButtonTitle()

        row.addArrangedSubview(makeControlButton(title: "−", action: #selector(decreaseOpacity)))
        row.addArrangedSubview(opacityLabel)
        row.addArrangedSubview(makeControlButton(title: "+", action: #selector(increaseOpacity)))
        row.addArrangedSubview(makeControlButton(title: localizer.string(.reset), action: #selector(resetOpacity)))
        row.addArrangedSubview(lockButton)

        controlsPill.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: controlsPill.contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: controlsPill.contentView.trailingAnchor),
            row.topAnchor.constraint(equalTo: controlsPill.contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: controlsPill.contentView.bottomAnchor)
        ])
    }

    func setControlsVisible(_ visible: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            controlsPill.animator().alphaValue = visible ? 1 : 0
        }
        view.window?.standardWindowButton(.closeButton)?.animator().alphaValue = visible ? 1 : 0
        view.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        view.window?.standardWindowButton(.zoomButton)?.isHidden = true
    }

    func makeControlButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .inline
        button.font = .systemFont(ofSize: 11, weight: .medium)
        return button
    }

    func setOpacity(_ value: CGFloat) {
        view.window?.alphaValue = PinWindowOpacity.clamped(value)
        updateOpacityLabel()
    }

    func updateOpacityLabel() {
        let opacity = view.window?.alphaValue ?? PinWindowOpacity.defaultValue
        opacityLabel.stringValue = PinWindowOpacity.percentText(for: opacity)
    }

    func updateLockButtonTitle() {
        lockButton.title = localizer.string(PinWindowLockState.buttonTitleKey(isLocked: isLocked))
    }

    @objc func decreaseOpacity() {
        setOpacity(PinWindowOpacity.adjusted(view.window?.alphaValue ?? PinWindowOpacity.defaultValue, delta: -PinWindowOpacity.step))
    }

    @objc func increaseOpacity() {
        setOpacity(PinWindowOpacity.adjusted(view.window?.alphaValue ?? PinWindowOpacity.defaultValue, delta: PinWindowOpacity.step))
    }

    @objc func resetOpacity() {
        setOpacity(PinWindowOpacity.defaultValue)
    }

    @objc func toggleLockState() {
        isLocked.toggle()
        if let window = view.window {
            PinWindowLockState.apply(isLocked: isLocked, to: window)
        }
        updateLockButtonTitle()
    }
}

private final class PinHoverContainerView: NSView {
    var hoverChangedHandler: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        hoverChangedHandler?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hoverChangedHandler?(false)
    }
}

private final class PinImageViewController: NSViewController {
    private let image: NSImage
    private let imageView = NSImageView()

    init(image: NSImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.035, green: 0.038, blue: 0.045, alpha: 1).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.preferredImageDynamicRange = .high
        imageView.allowsCutCopyPaste = false

        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

private final class PinTextViewController: NSViewController {
    private let text: String
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    init(text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.035, green: 0.038, blue: 0.045, alpha: 1).cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true

        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = NSColor(white: 0.94, alpha: 0.96)
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 18, height: 16)

        scrollView.documentView = textView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

enum PinWindowLayout {
    static func initialWindowSize(for imageSize: NSSize, maxSize: NSSize = NSSize(width: 520, height: 420)) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: 360, height: 260)
        }

        let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height, 1)
        return NSSize(
            width: max(imageSize.width * scale, 220),
            height: max(imageSize.height * scale, 160)
        )
    }

    static func initialTextWindowSize(characterCount: Int, maxSize: NSSize = NSSize(width: 520, height: 420)) -> NSSize {
        let normalizedCount = max(characterCount, 1)
        let estimatedLines = CGFloat(min(max((normalizedCount / 56) + 1, 4), 18))
        let width = min(maxSize.width, max(320, CGFloat(min(normalizedCount, 64)) * 7.2))
        let height = min(maxSize.height, max(220, estimatedLines * 22 + 52))
        return NSSize(width: width, height: height)
    }
}

enum PinWindowOpacity {
    static let defaultValue: CGFloat = 1
    static let minimum: CGFloat = 0.35
    static let maximum: CGFloat = 1
    static let step: CGFloat = 0.1

    static func adjusted(_ value: CGFloat, delta: CGFloat) -> CGFloat {
        clamped(((value + delta) * 100).rounded() / 100)
    }

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }

    static func percentText(for value: CGFloat) -> String {
        "\(Int((clamped(value) * 100).rounded()))%"
    }
}

enum PinWindowLockState {
    static func buttonTitleKey(isLocked: Bool) -> Localizer.Key {
        isLocked ? .unlock : .lock
    }

    static func apply(isLocked: Bool, to window: NSWindow) {
        window.isMovable = !isLocked
        window.isMovableByWindowBackground = !isLocked
        if isLocked {
            window.styleMask.remove(.resizable)
        } else {
            window.styleMask.insert(.resizable)
        }
    }
}
