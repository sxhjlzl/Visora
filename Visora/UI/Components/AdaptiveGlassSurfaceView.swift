import AppKit

/// 统一封装 macOS 26/27+ 原生 Liquid Glass (`NSGlassEffectView` + `effectIsInteractive`)
/// 支持 `.regular` 与 `.clear` 两种折射风格，并在旧版 macOS 上自动回退为带 1px 镜面高光描边与立体阴影的 `NSVisualEffectView`
final class AdaptiveGlassSurfaceView: NSView {
    enum ShapeStyle {
        case capsule
        case rounded(CGFloat)
        case concentric(minimum: CGFloat)
    }

    enum GlassVariant {
        case regular
        case clear
    }

    let contentView = NSView()
    private let shapeStyle: ShapeStyle
    private let glassVariant: GlassVariant
    private let isInteractive: Bool
    private var glassView: NSView?
    private var fallbackEffectView: NSVisualEffectView?

    var onMouseHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    init(shape: ShapeStyle = .rounded(12), variant: GlassVariant = .regular, isInteractive: Bool = false) {
        self.shapeStyle = shape
        self.glassVariant = variant
        self.isInteractive = isInteractive
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        configureShadow()
        configureBackingSurface()
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
        onMouseHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseHoverChanged?(false)
    }

    override func layout() {
        super.layout()
        applyCornerGeometry()
    }
}

private extension AdaptiveGlassSurfaceView {
    func configureShadow() {
        let dropShadow = NSShadow()
        dropShadow.shadowColor = NSColor(white: 0, alpha: 0.42)
        dropShadow.shadowOffset = NSSize(width: 0, height: -4)
        dropShadow.shadowBlurRadius = 16
        shadow = dropShadow
    }

    func configureBackingSurface() {
        contentView.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.style = glassVariant == .clear ? .clear : .regular
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = isInteractive
            }
            glass.contentView = contentView
            addSubview(glass)
            glassView = glass

            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: trailingAnchor),
                glass.topAnchor.constraint(equalTo: topAnchor),
                glass.bottomAnchor.constraint(equalTo: bottomAnchor),
                contentView.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: glass.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
            ])
        } else {
            let effect = NSVisualEffectView()
            effect.translatesAutoresizingMaskIntoConstraints = false
            effect.material = .hudWindow
            effect.blendingMode = .withinWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.masksToBounds = true
            effect.layer?.borderWidth = 1
            effect.layer?.borderColor = NSColor(white: 1, alpha: 0.15).cgColor
            addSubview(effect)
            effect.addSubview(contentView)
            fallbackEffectView = effect

            NSLayoutConstraint.activate([
                effect.leadingAnchor.constraint(equalTo: leadingAnchor),
                effect.trailingAnchor.constraint(equalTo: trailingAnchor),
                effect.topAnchor.constraint(equalTo: topAnchor),
                effect.bottomAnchor.constraint(equalTo: bottomAnchor),
                contentView.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: effect.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
            ])
        }

        applyCornerGeometry()
    }

    func applyCornerGeometry() {
        let resolvedRadius: CGFloat
        switch shapeStyle {
        case .capsule:
            resolvedRadius = max(bounds.height / 2, 14)
        case .rounded(let r):
            resolvedRadius = r
        case .concentric(let minimum):
            resolvedRadius = max(minimum, 12)
        }

        if #available(macOS 26.0, *), let glass = glassView as? NSGlassEffectView {
            glass.cornerRadius = resolvedRadius
        }
        fallbackEffectView?.layer?.cornerRadius = resolvedRadius
        fallbackEffectView?.layer?.cornerCurve = .continuous
    }
}

/// 封装 macOS 26/27+ `NSGlassEffectContainerView`，对邻近的 Liquid Glass 视图进行批量渲染与流体边缘融合（Metaball 融合效果）
final class AdaptiveGlassClusterView: NSView {
    let contentView = NSView()
    private var containerView: NSView?

    init(spacing: CGFloat = 14) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *) {
            let cluster = NSGlassEffectContainerView()
            cluster.translatesAutoresizingMaskIntoConstraints = false
            cluster.spacing = spacing
            cluster.contentView = contentView
            addSubview(cluster)
            containerView = cluster

            NSLayoutConstraint.activate([
                cluster.leadingAnchor.constraint(equalTo: leadingAnchor),
                cluster.trailingAnchor.constraint(equalTo: trailingAnchor),
                cluster.topAnchor.constraint(equalTo: topAnchor),
                cluster.bottomAnchor.constraint(equalTo: bottomAnchor),
                contentView.leadingAnchor.constraint(equalTo: cluster.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: cluster.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: cluster.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: cluster.bottomAnchor)
            ])
        } else {
            addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit === self || hit === contentView || hit === containerView {
            return nil
        }
        return hit
    }
}

/// 带鼠标悬停胶囊高亮与激活态着色的工具栏按钮
final class ToolbarIconButton: NSButton {
    var isActiveState: Bool = false {
        didSet {
            updateVisualAppearance()
        }
    }

    private var isHovered = false {
        didSet {
            updateVisualAppearance()
        }
    }

    private var trackingArea: NSTrackingArea?

    init(symbolName: String, toolTip: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        self.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(config)
        self.bezelStyle = .texturedRounded
        self.isBordered = false
        self.imagePosition = .imageOnly
        self.toolTip = toolTip
        self.target = target
        self.action = action
        self.wantsLayer = true
        self.layer?.cornerRadius = 7
        self.layer?.cornerCurve = .continuous
        self.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 28)
        ])

        updateVisualAppearance()
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

    private func updateVisualAppearance() {
        if isActiveState {
            contentTintColor = BrandStyle.accentColor
            layer?.backgroundColor = BrandStyle.accentColor.withAlphaComponent(isHovered ? 0.24 : 0.16).cgColor
        } else if isHovered {
            contentTintColor = NSColor(white: 1.0, alpha: 0.98)
            layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.14).cgColor
        } else {
            contentTintColor = NSColor(white: 0.92, alpha: 0.90)
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
