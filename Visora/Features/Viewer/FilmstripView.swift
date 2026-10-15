import AppKit

/// 底部胶卷条视图：横向显示当前文件夹的缩略图，点击可切换图片
final class FilmstripView: NSView {
    static let preferredHeight: CGFloat = 84

    var selectionHandler: ((URL) -> Void)?
    var hoverHandler: ((Bool) -> Void)?

    private let backgroundView = AdaptiveGlassSurfaceView(shape: .rounded(14), isInteractive: true)
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let thumbnailLoader: ThumbnailLoader

    private var assets: [ImageAsset] = []
    private var currentURL: URL?
    private var cells: [URL: FilmstripCell] = [:]

    init(thumbnailLoader: ThumbnailLoader) {
        self.thumbnailLoader = thumbnailLoader
        super.init(frame: .zero)
        wantsLayer = true
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// 更新数据。assets 列表变化时整体重建，仅当前选中变化时只刷新高亮，降低滚动抖动
    func update(assets: [ImageAsset], currentURL: URL?) {
        let assetsChanged = assets.map(\.url) != self.assets.map(\.url)
        self.assets = assets
        self.currentURL = currentURL

        if assetsChanged {
            rebuildCells()
        } else {
            refreshSelectionHighlight()
        }
        scrollCurrentSelectionIntoView()
    }
}

private extension FilmstripView {
    func configureSubviews() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.onMouseHoverChanged = { [weak self] isHovering in
            self?.hoverHandler?(isHovering)
        }
        addSubview(backgroundView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.scrollerStyle = .overlay

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        scrollView.documentView = stackView
        backgroundView.contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            // 锚定起点，宽度交给 intrinsicContentSize 撑开，超出 scrollView 宽度时横向滚动
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor)
        ])
    }

    func rebuildCells() {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        cells = [:]

        for asset in assets {
            let cell = FilmstripCell(asset: asset, isSelected: asset.url == currentURL) { [weak self] url in
                self?.selectionHandler?(url)
            }
            cells[asset.url] = cell
            stackView.addArrangedSubview(cell)

            if let cached = thumbnailLoader.cachedThumbnail(for: asset.url) {
                cell.setImage(cached)
            } else {
                thumbnailLoader.loadThumbnail(for: asset.url) { [weak cell] image in
                    cell?.setImage(image)
                }
            }
        }
    }

    func refreshSelectionHighlight() {
        for (url, cell) in cells {
            cell.isSelected = url == currentURL
        }
    }

    func scrollCurrentSelectionIntoView() {
        guard let currentURL, let cell = cells[currentURL] else { return }

        // 在下一个 runloop 滚动可以确保 stack 已完成布局，cell.frame 是稳定值
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let target = cell.convert(cell.bounds, to: self.scrollView.documentView).insetBy(dx: -40, dy: 0)
            self.scrollView.contentView.scrollToVisible(target)
            self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
        }
    }
}

private final class FilmstripCell: NSView {
    private let asset: ImageAsset
    private let onSelect: (URL) -> Void
    private let imageView = NSImageView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateHighlight() }
    }

    var isSelected: Bool {
        didSet { updateHighlight() }
    }

    init(asset: ImageAsset, isSelected: Bool, onSelect: @escaping (URL) -> Void) {
        self.asset = asset
        self.isSelected = isSelected
        self.onSelect = onSelect
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.28).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.preferredImageDynamicRange = .high
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        placeholderLabel.stringValue = asset.fileExtension.uppercased()
        placeholderLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        placeholderLabel.textColor = NSColor(white: 1, alpha: 0.55)
        placeholderLabel.alignment = .center
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 64),
            heightAnchor.constraint(equalToConstant: 64),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        toolTip = asset.fileName
        updateHighlight()
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

    func setImage(_ image: NSImage?) {
        imageView.image = image
        placeholderLabel.isHidden = image != nil
    }

    private func updateHighlight() {
        if isSelected {
            layer?.borderColor = BrandStyle.accentColor.cgColor
            layer?.borderWidth = 2.5
            alphaValue = 1.0
        } else if isHovered {
            layer?.borderColor = NSColor(white: 1, alpha: 0.35).cgColor
            layer?.borderWidth = 1.2
            alphaValue = 0.92
        } else {
            layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor
            layer?.borderWidth = 1
            alphaValue = 0.65
        }
    }

    override func mouseDown(with event: NSEvent) {
        onSelect(asset.url)
    }
}
