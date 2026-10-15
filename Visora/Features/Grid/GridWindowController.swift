import AppKit

final class GridWindowController: NSWindowController {
    private let viewController: GridViewController
    private var settings: AppSettings

    init(
        settings: AppSettings,
        thumbnailLoader: ThumbnailLoader,
        imageCache: ImageMemoryCache,
        onSelect: @escaping (URL) -> Void
    ) {
        self.settings = settings.normalized
        let localizer = Localizer(language: settings.language)
        self.viewController = GridViewController(
            settings: settings,
            thumbnailLoader: thumbnailLoader,
            imageCache: imageCache,
            onSelect: onSelect
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = localizer.string(.grid)
        window.minSize = NSSize(width: 520, height: 360)
        window.contentViewController = viewController
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(assets: [ImageAsset], currentURL: URL?) {
        viewController.apply(settings: settings)
        viewController.update(assets: assets, currentURL: currentURL)
        window?.title = Localizer(language: settings.language).gridTitle(count: assets.count)
    }

    func apply(settings: AppSettings) {
        self.settings = settings.normalized
        viewController.apply(settings: self.settings)
        window?.title = Localizer(language: self.settings.language).gridTitle(count: viewController.assetCount)
    }
}

private final class GridViewController: NSViewController {
    private let thumbnailLoader: ThumbnailLoader
    private let imageCache: ImageMemoryCache
    private let onSelect: (URL) -> Void
    private let rootView = GridContainerView()
    private let headerView = NSVisualEffectView()
    private let headerStack = NSStackView()
    private let thumbnailSizeLabel = NSTextField(labelWithString: "")
    private let thumbnailSizeValueLabel = NSTextField(labelWithString: "")
    private let thumbnailSizeSlider = NSSlider(value: Double(GridLayout.defaultScale), minValue: Double(GridLayout.minimumScale), maxValue: Double(GridLayout.maximumScale), target: nil, action: nil)
    private let scrollView = NSScrollView()
    private let gridView = NSGridView()
    private var settings: AppSettings
    private var thumbnailScale: CGFloat = GridLayout.defaultScale

    private var assets: [ImageAsset] = []
    private var currentURL: URL?
    private var selectedIndex: Int = 0
    /// 记录上次重建时的列数和缩放，避免 rebuild→layout→viewDidLayout→rebuild 的循环
    private var lastBuiltColumns: Int = 0
    private var lastBuiltScale: CGFloat = 0

    var assetCount: Int {
        assets.count
    }

    init(
        settings: AppSettings,
        thumbnailLoader: ThumbnailLoader,
        imageCache: ImageMemoryCache,
        onSelect: @escaping (URL) -> Void
    ) {
        self.settings = settings.normalized
        self.thumbnailLoader = thumbnailLoader
        self.imageCache = imageCache
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = rootView
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor(red: 0.06, green: 0.065, blue: 0.075, alpha: 1).cgColor
        rootView.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event)
        }

        configureHeader()
        configureGrid()

        view.addSubview(headerView)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 46),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gridView.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.widthAnchor, constant: -24)
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(rootView)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard !assets.isEmpty else { return }
        // 仅当列数或缩放真正变化时才重建，否则窗口尺寸变化就会触发死循环式 rebuild
        let columns = currentColumns
        if columns != lastBuiltColumns || thumbnailScale != lastBuiltScale {
            rebuildGrid()
        }
    }

    func update(assets: [ImageAsset], currentURL: URL?) {
        self.assets = assets
        self.currentURL = currentURL
        self.selectedIndex = assets.firstIndex(where: { $0.url == currentURL }) ?? 0
        rebuildGrid()
        scrollSelectionIntoView()
    }

    func apply(settings: AppSettings) {
        self.settings = settings.normalized
        if isViewLoaded {
            updateLocalizedUI()
            rebuildGrid()
        }
    }
}

private extension GridViewController {
    var localizer: Localizer {
        Localizer(language: settings.language)
    }

    var currentColumns: Int {
        GridLayout.columnCount(availableWidth: scrollView.contentSize.width - 24, scale: thumbnailScale)
    }

    func configureHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.material = .hudWindow
        headerView.blendingMode = .withinWindow
        headerView.state = .active

        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10
        headerStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        thumbnailSizeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        thumbnailSizeValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        thumbnailSizeValueLabel.textColor = NSColor(white: 0.9, alpha: 0.92)
        thumbnailSizeValueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        thumbnailSizeSlider.target = self
        thumbnailSizeSlider.action = #selector(thumbnailSizeChanged)
        thumbnailSizeSlider.numberOfTickMarks = 9
        thumbnailSizeSlider.allowsTickMarkValuesOnly = false

        headerStack.addArrangedSubview(thumbnailSizeLabel)
        headerStack.addArrangedSubview(thumbnailSizeSlider)
        headerStack.addArrangedSubview(thumbnailSizeValueLabel)
        headerView.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            thumbnailSizeSlider.widthAnchor.constraint(equalToConstant: 180)
        ])

        updateLocalizedUI()
    }

    func configureGrid() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = gridView

        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.xPlacement = .leading
        gridView.yPlacement = .top
        gridView.rowSpacing = GridLayout.spacing
        gridView.columnSpacing = GridLayout.spacing
    }

    func updateLocalizedUI() {
        thumbnailSizeLabel.stringValue = localizer.string(.thumbnailSize)
        thumbnailSizeValueLabel.stringValue = "\(Int((thumbnailScale * 100).rounded()))%"
    }

    func rebuildGrid() {
        // 先收集所有现存 cell 的 contentView，removeRow 之后再 explicit removeFromSuperview，
        // 避免 NSGridView 在某些情况下不主动移除子视图导致重建后旧缩略图叠在新缩略图上
        var previousContentViews: [NSView] = []
        for rowIndex in 0..<gridView.numberOfRows {
            let row = gridView.row(at: rowIndex)
            for columnIndex in 0..<row.numberOfCells {
                if let contentView = row.cell(at: columnIndex).contentView {
                    previousContentViews.append(contentView)
                }
            }
        }
        while gridView.numberOfRows > 0 {
            gridView.removeRow(at: 0)
        }
        previousContentViews.forEach { $0.removeFromSuperview() }

        updateLocalizedUI()

        guard !assets.isEmpty else {
            gridView.addRow(with: [makeEmptyLabel()])
            lastBuiltColumns = 0
            lastBuiltScale = thumbnailScale
            return
        }

        let columns = currentColumns
        let rowCount = GridLayout.rowCount(itemCount: assets.count, columns: columns)
        for rowIndex in 0..<rowCount {
            var rowViews: [NSView] = []
            for columnIndex in 0..<columns {
                let assetIndex = rowIndex * columns + columnIndex
                if assetIndex < assets.count {
                    rowViews.append(makeCell(for: assets[assetIndex], index: assetIndex))
                } else {
                    rowViews.append(NSView())
                }
            }
            gridView.addRow(with: rowViews)
        }
        lastBuiltColumns = columns
        lastBuiltScale = thumbnailScale
    }

    func makeCell(for asset: ImageAsset, index: Int) -> NSView {
        let cell = GridThumbnailCell(
            asset: asset,
            isCurrent: asset.url == currentURL,
            isSelected: index == selectedIndex,
            scale: thumbnailScale,
            onSelect: { [weak self] url in
                self?.select(url: url)
            },
            onOpen: { [weak self] url in
                self?.onSelect(url)
            }
        )
        let size = GridLayout.cellSize(scale: thumbnailScale)
        cell.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.widthAnchor.constraint(equalToConstant: size.width),
            cell.heightAnchor.constraint(equalToConstant: size.height)
        ])

        loadThumbnail(for: asset, into: cell)
        return cell
    }

    func loadThumbnail(for asset: ImageAsset, into cell: GridThumbnailCell) {
        if let cachedThumb = thumbnailLoader.cachedThumbnail(for: asset.url) {
            cell.setImage(cachedThumb)
            return
        }
        if let cachedFull = imageCache.result(for: asset.url) {
            cell.setImage(cachedFull.image)
            return
        }

        thumbnailLoader.loadThumbnail(for: asset.url) { [weak cell] thumbnail in
            guard let thumbnail else { return }
            cell?.setImage(thumbnail)
        }
    }

    func makeEmptyLabel() -> NSTextField {
        let label = NSTextField(labelWithString: localizer.string(.noImages))
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = NSColor(white: 0.8, alpha: 0.8)
        return label
    }

    func select(url: URL) {
        guard let index = assets.firstIndex(where: { $0.url == url }) else { return }
        selectedIndex = index
        rebuildGrid()
        scrollSelectionIntoView()
    }

    func scrollSelectionIntoView() {
        let columns = currentColumns
        guard columns > 0, !assets.isEmpty else { return }
        let row = selectedIndex / columns
        guard row < gridView.numberOfRows else { return }
        let rowCell = gridView.cell(atColumnIndex: 0, rowIndex: row)
        guard let rowView = rowCell.contentView else { return }
        let rowFrame = rowView.frame
        scrollView.contentView.scrollToVisible(rowFrame.insetBy(dx: 0, dy: -GridLayout.spacing))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @objc func thumbnailSizeChanged() {
        thumbnailScale = GridLayout.clampedScale(CGFloat(thumbnailSizeSlider.doubleValue))
        updateLocalizedUI()
        rebuildGrid()
        scrollSelectionIntoView()
    }

    func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 123, 124, 125, 126:
            guard !assets.isEmpty else { return }
            selectedIndex = GridLayout.movedIndex(
                current: selectedIndex,
                keyCode: event.keyCode,
                itemCount: assets.count,
                columns: currentColumns
            )
            rebuildGrid()
            scrollSelectionIntoView()
        case 36, 76:
            guard assets.indices.contains(selectedIndex) else { return }
            onSelect(assets[selectedIndex].url)
        case 53:
            view.window?.performClose(nil)
        default:
            guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return }
            switch characters {
            case "+", "=":
                thumbnailScale = GridLayout.adjustedScale(thumbnailScale, delta: GridLayout.scaleStep)
            case "-":
                thumbnailScale = GridLayout.adjustedScale(thumbnailScale, delta: -GridLayout.scaleStep)
            case "g":
                view.window?.performClose(nil)
                return
            default:
                return
            }
            thumbnailSizeSlider.doubleValue = thumbnailScale
            updateLocalizedUI()
            rebuildGrid()
            scrollSelectionIntoView()
        }
    }
}

private final class GridThumbnailCell: NSView {
    private let asset: ImageAsset
    private let onSelect: (URL) -> Void
    private let onOpen: (URL) -> Void
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(
        asset: ImageAsset,
        isCurrent: Bool,
        isSelected: Bool,
        scale: CGFloat,
        onSelect: @escaping (URL) -> Void,
        onOpen: @escaping (URL) -> Void
    ) {
        self.asset = asset
        self.onSelect = onSelect
        self.onOpen = onOpen
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = GridCellStyle.backgroundColor(isCurrent: isCurrent, isSelected: isSelected).cgColor
        layer?.borderColor = GridCellStyle.borderColor(isCurrent: isCurrent, isSelected: isSelected).cgColor
        layer?.borderWidth = isSelected ? 3 : (isCurrent ? 2 : 1)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.backgroundColor = NSColor(white: 0, alpha: 0.22).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = asset.fileName
        label.font = .systemFont(ofSize: max(10, 11 * scale), weight: .medium)
        label.textColor = NSColor(white: 0.9, alpha: 0.92)
        label.lineBreakMode = .byTruncatingMiddle
        label.alignment = .center

        addSubview(imageView)
        addSubview(label)

        let padding = max(8, 8 * scale)
        let imageHeight = max(102, GridLayout.cellSize(scale: scale).height - 52)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            imageView.heightAnchor.constraint(equalToConstant: imageHeight),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setImage(_ image: NSImage) {
        imageView.image = image
    }

    override func mouseDown(with event: NSEvent) {
        onSelect(asset.url)
        if event.clickCount == 2 {
            onOpen(asset.url)
        }
    }
}

private enum GridCellStyle {
    static func backgroundColor(isCurrent: Bool, isSelected: Bool) -> NSColor {
        if isSelected {
            return NSColor.controlAccentColor.withAlphaComponent(0.32)
        }
        if isCurrent {
            return NSColor.controlAccentColor.withAlphaComponent(0.18)
        }
        return NSColor(white: 1, alpha: 0.06)
    }

    static func borderColor(isCurrent: Bool, isSelected: Bool) -> NSColor {
        if isSelected {
            return NSColor.controlAccentColor.withAlphaComponent(0.98)
        }
        if isCurrent {
            return NSColor.controlAccentColor.withAlphaComponent(0.72)
        }
        return NSColor(white: 1, alpha: 0.10)
    }
}

private final class GridContainerView: NSView {
    var keyDownHandler: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        keyDownHandler?(event)
    }
}
