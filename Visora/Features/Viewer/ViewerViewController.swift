import AppKit
import Vision

final class ViewerViewController: NSViewController, NSSearchFieldDelegate {
    var openURLHandler: ((URL) -> Void)?
    var gridRequestHandler: (([ImageAsset], URL?) -> Void)?
    var pinRequestHandler: ((NSImage, String) -> Void)?
    var chooseImageHandler: (() -> Void)?
    var chooseFolderHandler: (() -> Void)?
    var openPreferencesHandler: (() -> Void)?
    var openRecentItemHandler: ((RecentItem) -> Void)?
    var clearRecentItemsHandler: (() -> Void)?

    private let decoder: ImageIODecoder
    private let imageCache: ImageMemoryCache
    private let thumbnailLoader: ThumbnailLoader
    private let canvasView = ImageCanvasView()
    private let welcomeView = WelcomeView()
    private let glassCluster = AdaptiveGlassClusterView(spacing: 14)
    private let topInfoBar = AdaptiveGlassSurfaceView(shape: .capsule, variant: .clear, isInteractive: false)
    private let topInfoLabel = NSTextField(labelWithString: "")
    private let filterBar = AdaptiveGlassSurfaceView(shape: .capsule, variant: .regular, isInteractive: true)
    private let filterSearchField = NSSearchField()
    private let bottomToolbar = AdaptiveGlassSurfaceView(shape: .capsule, variant: .regular, isInteractive: true)
    private let bottomToolbarStack = NSStackView()
    private let leadingToolGroup = NSStackView()
    private let centerToolGroup = NSStackView()
    private let trailingToolGroup = NSStackView()
    private let zoomLabel = NSTextField(labelWithString: "")
    private let pageLabel = NSTextField(labelWithString: "")
    private let toastContainer = AdaptiveGlassSurfaceView(shape: .capsule, variant: .clear, isInteractive: false)
    private let toastLabel = NSTextField(labelWithString: "")
    private let infoPanel = AdaptiveGlassSurfaceView(shape: .concentric(minimum: 16), variant: .regular, isInteractive: true)
    private let infoStack = NSStackView()
    private let infoScrollView = NSScrollView()
    private let ocrPanel = AdaptiveGlassSurfaceView(shape: .concentric(minimum: 16), variant: .regular, isInteractive: true)
    private let ocrTitleLabel = NSTextField(labelWithString: "")
    private let ocrCopyButton = NSButton(title: "", target: nil, action: nil)
    private let ocrCloseButton = NSButton()
    private let ocrScrollView = NSScrollView()
    private let ocrTextView = NSTextView()
    private lazy var filmstripView = FilmstripView(thumbnailLoader: thumbnailLoader)

    private var slideshowToolbarButton: ToolbarIconButton?
    private var infoToolbarButton: ToolbarIconButton?
    private var ocrToolbarButton: ToolbarIconButton?
    private var immersiveToolbarButton: ToolbarIconButton?
    private var backgroundToolbarButton: ToolbarIconButton?
    private var hoveredChromeCount = 0

    private var allAssets: [ImageAsset] = []
    private var assets: [ImageAsset] = []
    private var filterQuery: String = ""
    private var currentIndex: Int = 0
    private var currentImage: NSImage?
    private var currentMetadata: ImageMetadata?
    private var pendingDecodeURL: URL?
    private var chromeHideWorkItem: DispatchWorkItem?
    private var toastHideWorkItem: DispatchWorkItem?
    private var isImmersiveChromeEnabled = false
    /// 胶卷条的会话级开关：默认跟随偏好设置，按 T 临时反转，apply(settings:) 会重置回偏好
    private var isFilmstripUserVisible = AppSettings.defaults.showFilmstrip
    private var settings = AppSettings.defaults
    private var slideshowTimer: Timer?
    private var isSlideshowRunning = false
    private var rotationQuarterTurnsByURL: [URL: Int] = [:]
    private var flipStateByURL: [URL: (horizontal: Bool, vertical: Bool)] = [:]
    // Preserve section visibility across images so the metadata panel behaves like a tool, not per-image state.
    private var collapsedMetadataSectionIDs: Set<String> = []
    private var localizer: Localizer {
        Localizer(language: settings.language)
    }

    var currentDisplayedURL: URL? {
        currentAssetURL ?? pendingDecodeURL
    }

    init(decoder: ImageIODecoder, imageCache: ImageMemoryCache, thumbnailLoader: ThumbnailLoader) {
        self.decoder = decoder
        self.imageCache = imageCache
        self.thumbnailLoader = thumbnailLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: NSSize(width: 1280, height: 840)))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.04, green: 0.045, blue: 0.055, alpha: 1).cgColor

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.localizer = localizer
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.localizer = localizer
        topInfoBar.translatesAutoresizingMaskIntoConstraints = false
        topInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        filterSearchField.translatesAutoresizingMaskIntoConstraints = false
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        bottomToolbarStack.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoScrollView.translatesAutoresizingMaskIntoConstraints = false
        ocrPanel.translatesAutoresizingMaskIntoConstraints = false
        ocrTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        ocrCopyButton.translatesAutoresizingMaskIntoConstraints = false
        ocrCloseButton.translatesAutoresizingMaskIntoConstraints = false
        ocrScrollView.translatesAutoresizingMaskIntoConstraints = false
        filmstripView.translatesAutoresizingMaskIntoConstraints = false
        // 初始可见度跟随 bottomToolbar，让 isHidden 单一控制显示/隐藏，避免出现 isHidden=false 但 alpha=0 的不可见态
        filmstripView.alphaValue = 1
        filmstripView.isHidden = true
        filmstripView.selectionHandler = { [weak self] url in
            self?.jumpToImage(at: url)
        }
        filmstripView.hoverHandler = { [weak self] isHovering in
            self?.handleChromeHoverChanged(isHovering)
        }

        configureTopInfoBar()
        configureFilterBar()
        configureBottomToolbar()
        configureToastLabel()
        configureInfoPanel()
        configureOCRPanel()
        wireChromeHoverTracking()

        view.addSubview(canvasView)
        view.addSubview(welcomeView)
        view.addSubview(glassCluster)
        glassCluster.contentView.addSubview(topInfoBar)
        glassCluster.contentView.addSubview(filterBar)
        glassCluster.contentView.addSubview(filmstripView)
        glassCluster.contentView.addSubview(bottomToolbar)
        glassCluster.contentView.addSubview(toastContainer)
        glassCluster.contentView.addSubview(infoPanel)
        glassCluster.contentView.addSubview(ocrPanel)

        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            welcomeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            welcomeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            welcomeView.topAnchor.constraint(equalTo: view.topAnchor),
            welcomeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            glassCluster.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glassCluster.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glassCluster.topAnchor.constraint(equalTo: view.topAnchor),
            glassCluster.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topInfoBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topInfoBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            topInfoBar.heightAnchor.constraint(equalToConstant: 30),
            topInfoBar.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.86),

            topInfoLabel.leadingAnchor.constraint(equalTo: topInfoBar.contentView.leadingAnchor, constant: 16),
            topInfoLabel.trailingAnchor.constraint(equalTo: topInfoBar.contentView.trailingAnchor, constant: -16),
            topInfoLabel.centerYAnchor.constraint(equalTo: topInfoBar.contentView.centerYAnchor),

            filterBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            filterBar.topAnchor.constraint(equalTo: topInfoBar.bottomAnchor, constant: 8),
            filterBar.widthAnchor.constraint(equalToConstant: 280),
            filterBar.heightAnchor.constraint(equalToConstant: 34),

            filterSearchField.leadingAnchor.constraint(equalTo: filterBar.contentView.leadingAnchor, constant: 10),
            filterSearchField.trailingAnchor.constraint(equalTo: filterBar.contentView.trailingAnchor, constant: -10),
            filterSearchField.centerYAnchor.constraint(equalTo: filterBar.contentView.centerYAnchor),

            bottomToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 44),

            bottomToolbarStack.leadingAnchor.constraint(equalTo: bottomToolbar.contentView.leadingAnchor, constant: 12),
            bottomToolbarStack.trailingAnchor.constraint(equalTo: bottomToolbar.contentView.trailingAnchor, constant: -12),
            bottomToolbarStack.topAnchor.constraint(equalTo: bottomToolbar.contentView.topAnchor, constant: 4),
            bottomToolbarStack.bottomAnchor.constraint(equalTo: bottomToolbar.contentView.bottomAnchor, constant: -4),

            // 直接撑满窗口宽度（左右留白 16），内部 scrollView 横向滚动；
            // 之前用 centerX + greaterThanOrEqual 会让 filmstripView 宽度坍缩到 0 看不见
            filmstripView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filmstripView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filmstripView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -12),
            filmstripView.heightAnchor.constraint(equalToConstant: FilmstripView.preferredHeight),

            toastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastContainer.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -14),
            toastContainer.heightAnchor.constraint(equalToConstant: 32),

            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.contentView.leadingAnchor, constant: 16),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.contentView.trailingAnchor, constant: -16),
            toastLabel.centerYAnchor.constraint(equalTo: toastContainer.contentView.centerYAnchor),

            infoPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            infoPanel.topAnchor.constraint(equalTo: topInfoBar.bottomAnchor, constant: 12),
            infoPanel.widthAnchor.constraint(equalToConstant: 360),
            infoPanel.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -12),

            ocrPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            ocrPanel.topAnchor.constraint(equalTo: topInfoBar.bottomAnchor, constant: 12),
            ocrPanel.widthAnchor.constraint(equalToConstant: 360),
            ocrPanel.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -12)
        ])

        wireWelcomeView()
        updateEmptyStateVisibility(animated: false)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(canvasView)
        canvasView.commandHandler = { [weak self] command in
            self?.handle(command)
        }
        canvasView.openURLHandler = { [weak self] url in
            self?.openURLHandler?(url)
        }
        canvasView.zoomChangedHandler = { [weak self] in
            self?.updateStatus()
        }
        canvasView.interactionHandler = { [weak self] in
            self?.showChromeTemporarily()
        }
        setImmersiveChrome(settings.startImmersiveChrome, showFeedback: false)
        showChromeTemporarily()
    }

    func setSession(assets: [ImageAsset], currentURL: URL, decodedImage: NSImage, metadata: ImageMetadata) {
        pendingDecodeURL = nil
        self.allAssets = assets
        self.assets = filteredAssets(from: assets, query: filterQuery)
        if self.assets.isEmpty {
            self.filterQuery = ""
            self.filterSearchField.stringValue = ""
            self.assets = assets
        }
        self.currentIndex = self.assets.firstIndex(where: { $0.url == currentURL }) ?? 0
        self.currentImage = decodedImage
        self.currentMetadata = metadata
        let rotationQuarterTurns = rotationQuarterTurnsByURL[currentURL] ?? 0
        let flipState = flipStateByURL[currentURL] ?? (false, false)
        let animatedImage = imageCache.result(for: currentURL)?.animatedImage
        canvasView.setRotationQuarterTurns(rotationQuarterTurns)
        canvasView.setFlip(horizontal: flipState.horizontal, vertical: flipState.vertical)
        canvasView.setImage(
            decodedImage,
            animatedImage: animatedImage,
            longImageMode: shouldUseLongImageMode(
                image: decodedImage,
                metadata: metadata,
                rotationQuarterTurns: rotationQuarterTurns
            )
        )
        imageCache.store(
            ImageDecodeResult(image: decodedImage, metadata: metadata, animatedImage: animatedImage),
            for: currentURL
        )
        updateEmptyStateVisibility(animated: true)
        updateStatus()
        updateInfoPanel()
        refreshFilmstrip()
        preloadNearbyImages()
    }

    func reloadFolderAssets(_ updatedAssets: [ImageAsset]) {
        let previousURL = currentAssetURL ?? pendingDecodeURL
        allAssets = updatedAssets
        assets = filteredAssets(from: updatedAssets, query: filterQuery)

        guard !assets.isEmpty else {
            if !filterQuery.isEmpty, !updatedAssets.isEmpty {
                filterQuery = ""
                filterSearchField.stringValue = ""
                assets = updatedAssets
            } else {
                pendingDecodeURL = nil
                currentImage = nil
                currentMetadata = nil
                canvasView.clearImage()
                updateEmptyStateVisibility(animated: true)
                refreshFilmstrip()
                updateInfoPanel()
                return
            }
            return
        }

        if let previousURL, let existingIndex = assets.firstIndex(where: { $0.url == previousURL }) {
            currentIndex = existingIndex
            updateStatus()
            refreshFilmstrip()
            preloadNearbyImages()
        } else {
            let nextIndex = min(currentIndex, assets.count - 1)
            showImage(at: nextIndex)
        }
    }

    func setLoading(assets: [ImageAsset], currentURL: URL) {
        pendingDecodeURL = currentURL
        self.allAssets = assets
        self.assets = filteredAssets(from: assets, query: filterQuery)
        if self.assets.isEmpty {
            self.assets = assets
        }
        self.currentIndex = self.assets.firstIndex(where: { $0.url == currentURL }) ?? 0
        currentImage = nil
        currentMetadata = nil
        canvasView.clearImage()
        updateEmptyStateVisibility(animated: true)
        topInfoLabel.stringValue = localizer.loading(currentURL.lastPathComponent)
        updateInfoPanel()
        refreshFilmstrip()
        showChromeTemporarily()
    }

    func showOpenError(for url: URL) {
        pendingDecodeURL = nil
        currentImage = nil
        currentMetadata = nil
        canvasView.clearImage()
        updateEmptyStateVisibility(animated: true)
        showToast(localizer.unableToOpen(url.lastPathComponent))
    }

    func apply(settings: AppSettings) {
        self.settings = settings.normalized
        // 应用偏好后取消会话级覆盖，让胶卷条回到设置中的预期状态
        self.isFilmstripUserVisible = self.settings.showFilmstrip

        if isViewLoaded {
            canvasView.localizer = localizer
            welcomeView.localizer = localizer
            filterSearchField.placeholderString = localizer.string(.filterPlaceholder)
            ocrTitleLabel.stringValue = localizer.string(.ocrPanelTitle)
            ocrCopyButton.title = " " + localizer.string(.copyAllText)
            reloadToolbarButtons()
            setImmersiveChrome(self.settings.startImmersiveChrome, showFeedback: false)
            if let currentImage {
                let rotationQuarterTurns = currentAssetURL.flatMap { rotationQuarterTurnsByURL[$0] } ?? 0
                let flipState = currentAssetURL.flatMap { flipStateByURL[$0] } ?? (false, false)
                canvasView.setRotationQuarterTurns(rotationQuarterTurns)
                canvasView.setFlip(horizontal: flipState.horizontal, vertical: flipState.vertical)
                canvasView.setImage(
                    currentImage,
                    animatedImage: currentAnimatedImage,
                    longImageMode: shouldUseLongImageMode(
                        image: currentImage,
                        metadata: currentMetadata,
                        rotationQuarterTurns: rotationQuarterTurns
                    )
                )
                updateStatus()
            }
            updateEmptyStateVisibility(animated: false)
            updateInfoPanel()
            refreshFilmstrip()
            if isSlideshowRunning {
                scheduleSlideshowTimer()
            }
            showChromeTemporarily()
        }
    }

    func updateRecentItems(_ items: [RecentItem]) {
        guard isViewLoaded else { return }
        welcomeView.updateRecentItems(items)
    }

    func perform(_ command: ViewerCommand) {
        handle(command)
    }
}

private extension ViewerViewController {
    func configureTopInfoBar() {
        topInfoBar.alphaValue = 0

        topInfoLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        topInfoLabel.textColor = NSColor(white: 0.94, alpha: 0.96)
        topInfoLabel.alignment = .center
        topInfoLabel.lineBreakMode = .byTruncatingMiddle
        topInfoLabel.maximumNumberOfLines = 1
        topInfoLabel.cell?.usesSingleLineMode = true
        topInfoBar.contentView.addSubview(topInfoLabel)
    }

    func configureFilterBar() {
        filterBar.identifier = NSUserInterfaceItemIdentifier("imageFilterBar")
        filterBar.isHidden = true

        filterSearchField.placeholderString = localizer.string(.filterPlaceholder)
        filterSearchField.font = .systemFont(ofSize: 12)
        filterSearchField.sendsSearchStringImmediately = true
        filterSearchField.delegate = self
        filterBar.contentView.addSubview(filterSearchField)
    }

    func configureBottomToolbar() {
        bottomToolbar.identifier = NSUserInterfaceItemIdentifier("bottomToolbar")
        bottomToolbar.alphaValue = 0

        bottomToolbar.contentView.addSubview(bottomToolbarStack)
        bottomToolbarStack.orientation = .horizontal
        bottomToolbarStack.alignment = .centerY
        bottomToolbarStack.spacing = 12
        bottomToolbarStack.distribution = .fill

        for group in [leadingToolGroup, centerToolGroup, trailingToolGroup] {
            group.orientation = .horizontal
            group.alignment = .centerY
            group.spacing = 4
            group.translatesAutoresizingMaskIntoConstraints = false
            group.setContentHuggingPriority(.required, for: .horizontal)
            group.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        zoomLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        zoomLabel.textColor = NSColor(white: 0.92, alpha: 0.92)
        zoomLabel.alignment = .center
        zoomLabel.widthAnchor.constraint(equalToConstant: 46).isActive = true

        pageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        pageLabel.textColor = NSColor(white: 0.92, alpha: 0.92)
        pageLabel.alignment = .center
        pageLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true

        bottomToolbarStack.addArrangedSubview(leadingToolGroup)
        bottomToolbarStack.addArrangedSubview(makeToolbarSeparator())
        bottomToolbarStack.addArrangedSubview(centerToolGroup)
        bottomToolbarStack.addArrangedSubview(makeToolbarSeparator())
        bottomToolbarStack.addArrangedSubview(trailingToolGroup)
        bottomToolbarStack.setContentHuggingPriority(.required, for: .horizontal)
        bottomToolbarStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        reloadToolbarButtons()
    }

    func configureToastLabel() {
        toastContainer.alphaValue = 0
        toastLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        toastLabel.textColor = NSColor(white: 0.96, alpha: 0.98)
        toastLabel.drawsBackground = false
        toastLabel.isBordered = false
        toastLabel.alignment = .center
        toastLabel.lineBreakMode = .byTruncatingMiddle
        toastContainer.contentView.addSubview(toastLabel)
    }

    func configureInfoPanel() {
        infoPanel.identifier = NSUserInterfaceItemIdentifier("imageInfoPanel")
        infoPanel.isHidden = true

        infoScrollView.drawsBackground = false
        infoScrollView.hasVerticalScroller = true
        infoScrollView.borderType = .noBorder

        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 12
        infoStack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        infoScrollView.documentView = infoStack
        infoPanel.contentView.addSubview(infoScrollView)

        NSLayoutConstraint.activate([
            infoScrollView.leadingAnchor.constraint(equalTo: infoPanel.contentView.leadingAnchor),
            infoScrollView.trailingAnchor.constraint(equalTo: infoPanel.contentView.trailingAnchor),
            infoScrollView.topAnchor.constraint(equalTo: infoPanel.contentView.topAnchor),
            infoScrollView.bottomAnchor.constraint(equalTo: infoPanel.contentView.bottomAnchor),
            infoStack.widthAnchor.constraint(equalTo: infoScrollView.widthAnchor)
        ])
    }

    func configureOCRPanel() {
        ocrPanel.identifier = NSUserInterfaceItemIdentifier("imageOCRPanel")
        ocrPanel.isHidden = true

        ocrTitleLabel.stringValue = localizer.string(.ocrPanelTitle)
        ocrTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        ocrTitleLabel.textColor = NSColor(white: 0.96, alpha: 0.98)

        ocrCopyButton.title = " " + localizer.string(.copyAllText)
        ocrCopyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: localizer.string(.copyAllText))
        ocrCopyButton.imagePosition = .imageLeading
        if #available(macOS 26.0, *) {
            ocrCopyButton.bezelStyle = .glass
        } else {
            ocrCopyButton.bezelStyle = .inline
        }
        ocrCopyButton.font = .systemFont(ofSize: 11.5, weight: .medium)
        ocrCopyButton.target = self
        ocrCopyButton.action = #selector(copyOCRTextButtonPressed)

        ocrCloseButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: localizer.string(.close))
        ocrCloseButton.bezelStyle = .inline
        ocrCloseButton.isBordered = false
        ocrCloseButton.imagePosition = .imageOnly
        ocrCloseButton.contentTintColor = NSColor(white: 0.78, alpha: 0.85)
        ocrCloseButton.target = self
        ocrCloseButton.action = #selector(closeOCRPanelButtonPressed)

        let headerRow = NSStackView(views: [ocrTitleLabel, NSView(), ocrCopyButton, ocrCloseButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor

        ocrScrollView.drawsBackground = false
        ocrScrollView.borderType = .noBorder
        ocrScrollView.hasVerticalScroller = true
        ocrScrollView.autohidesScrollers = true

        ocrTextView.isEditable = false
        ocrTextView.isSelectable = true
        ocrTextView.drawsBackground = false
        ocrTextView.textColor = NSColor(white: 0.95, alpha: 0.98)
        ocrTextView.font = .systemFont(ofSize: 13, weight: .regular)
        ocrTextView.textContainerInset = NSSize(width: 14, height: 12)
        ocrTextView.isVerticallyResizable = true
        ocrTextView.isHorizontallyResizable = false
        ocrTextView.autoresizingMask = [.width]
        ocrTextView.textContainer?.widthTracksTextView = true

        ocrScrollView.documentView = ocrTextView

        ocrPanel.contentView.addSubview(headerRow)
        ocrPanel.contentView.addSubview(divider)
        ocrPanel.contentView.addSubview(ocrScrollView)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: ocrPanel.contentView.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: ocrPanel.contentView.trailingAnchor, constant: -14),
            headerRow.topAnchor.constraint(equalTo: ocrPanel.contentView.topAnchor, constant: 12),
            headerRow.heightAnchor.constraint(equalToConstant: 28),

            divider.leadingAnchor.constraint(equalTo: ocrPanel.contentView.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: ocrPanel.contentView.trailingAnchor, constant: -14),
            divider.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),
            divider.heightAnchor.constraint(equalToConstant: 1),

            ocrScrollView.leadingAnchor.constraint(equalTo: ocrPanel.contentView.leadingAnchor),
            ocrScrollView.trailingAnchor.constraint(equalTo: ocrPanel.contentView.trailingAnchor),
            ocrScrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            ocrScrollView.bottomAnchor.constraint(equalTo: ocrPanel.contentView.bottomAnchor)
        ])
    }

    func wireChromeHoverTracking() {
        let chromeSurfaces: [AdaptiveGlassSurfaceView] = [topInfoBar, filterBar, bottomToolbar, infoPanel, ocrPanel]
        for surface in chromeSurfaces {
            surface.onMouseHoverChanged = { [weak self] isHovering in
                self?.handleChromeHoverChanged(isHovering)
            }
        }
    }

    func handleChromeHoverChanged(_ isHovering: Bool) {
        hoveredChromeCount = max(0, hoveredChromeCount + (isHovering ? 1 : -1))
        if hoveredChromeCount > 0 {
            chromeHideWorkItem?.cancel()
            NSCursor.setHiddenUntilMouseMoves(false)
            showChromeTemporarily()
        } else {
            showChromeTemporarily()
        }
    }

    func wireWelcomeView() {
        welcomeView.chooseImageHandler = { [weak self] in
            self?.chooseImageHandler?()
        }
        welcomeView.chooseFolderHandler = { [weak self] in
            self?.chooseFolderHandler?()
        }
        welcomeView.openPreferencesHandler = { [weak self] in
            self?.openPreferencesHandler?()
        }
        welcomeView.openRecentItemHandler = { [weak self] item in
            self?.openRecentItemHandler?(item)
        }
        welcomeView.clearRecentItemsHandler = { [weak self] in
            self?.clearRecentItemsHandler?()
        }
        welcomeView.droppedURLHandler = { [weak self] url in
            self?.openURLHandler?(url)
        }
    }

    var isShowingWelcomeState: Bool {
        currentImage == nil && pendingDecodeURL == nil
    }

    func updateEmptyStateVisibility(animated: Bool) {
        let showWelcome = isShowingWelcomeState
        welcomeView.isHidden = !showWelcome

        // When the welcome surface is on screen the chrome would just clutter the canvas, so we suppress it.
        let hideChrome = showWelcome
        let chromeViews: [NSView] = [topInfoBar, bottomToolbar, filmstripView]
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                for chrome in chromeViews {
                    chrome.animator().alphaValue = hideChrome ? 0 : chrome.alphaValue
                }
            }
        } else {
            for chrome in chromeViews where hideChrome {
                chrome.alphaValue = 0
            }
        }

        if showWelcome {
            updateCanvasContentInsets()
            infoPanel.isHidden = true
            ocrPanel.isHidden = true
            filterBar.isHidden = true
            view.window?.title = "Visora"
        }
    }

    /// 单张图片或会话级关闭时都不展示胶卷条
    func refreshFilmstrip() {
        let shouldDisplay = isFilmstripUserVisible && assets.count > 1 && !isShowingWelcomeState
        filmstripView.isHidden = !shouldDisplay
        updateCanvasContentInsets()
        if shouldDisplay {
            filmstripView.update(assets: assets, currentURL: assets[safe: currentIndex]?.url)
            // 与底部工具栏的可见度保持一致：chrome 显示时它跟着显示，chrome 已经 auto-hide 时不要突然冒出来
            filmstripView.alphaValue = bottomToolbar.alphaValue
        }
    }

    func updateCanvasContentInsets() {
        guard !isShowingWelcomeState else {
            canvasView.contentInsets = NSEdgeInsetsZero
            return
        }

        canvasView.contentInsets = NSEdgeInsets(
            top: ViewerChromeLayout.topInsetWhenInfoBarVisible,
            left: 0,
            bottom: filmstripView.isHidden
                ? ViewerChromeLayout.bottomInsetWhenToolbarOnly
                : ViewerChromeLayout.bottomInsetWhenFilmstripVisible,
            right: 0
        )
    }

    func toggleFilmstrip() {
        guard assets.count > 1 else {
            showToast(localizer.string(.noFolderImages))
            return
        }
        isFilmstripUserVisible.toggle()
        refreshFilmstrip()
        if !filmstripView.isHidden {
            // 用户主动呼出时立即可见，避开 chrome 当前可能正在淡出的 alpha
            filmstripView.alphaValue = 1
            showChromeTemporarily()
        }
        showToast(localizer.string(isFilmstripUserVisible ? .filmstripShown : .filmstripHidden))
    }

    /// 胶卷条点击后跳转到对应图片，跟键盘翻页走同一条路径以保持加载/缓存策略一致
    func jumpToImage(at url: URL) {
        guard let targetIndex = assets.firstIndex(where: { $0.url == url }) else { return }
        guard targetIndex != currentIndex || currentImage == nil else { return }
        showImage(at: targetIndex)
    }

    func handle(_ command: ViewerCommand) {
        switch command {
        case .nextImage:
            showImage(at: currentIndex + 1)
        case .previousImage:
            showImage(at: currentIndex - 1)
        case .zoomIn:
            canvasView.zoom(by: 1.15)
            updateStatus()
        case .zoomOut:
            canvasView.zoom(by: 1 / 1.15)
            updateStatus()
        case .fitToWindow:
            canvasView.fitToWindow()
            updateStatus()
        case .actualSize:
            canvasView.showActualSize()
            updateStatus()
        case .jumpToTop:
            canvasView.jumpToTop()
            updateStatus()
        case .jumpToBottom:
            canvasView.jumpToBottom()
            updateStatus()
        case .closeWindow:
            stopSlideshow(showFeedback: false)
            view.window?.performClose(nil)
        case .toggleFullscreen:
            view.window?.toggleFullScreen(nil)
        case .toggleInfoPanel:
            guard !isShowingWelcomeState else { return }
            infoPanel.isHidden.toggle()
            if !infoPanel.isHidden {
                ocrPanel.isHidden = true
            }
            syncToolbarActiveStates()
            showChromeTemporarily()
        case .toggleImmersiveChrome:
            toggleImmersiveChrome()
        case .toggleSlideshow:
            toggleSlideshow()
        case .toggleGrid:
            showGrid()
        case .toggleFilmstrip:
            toggleFilmstrip()
        case .rotateLeft:
            rotateCurrentImage(by: -1)
        case .rotateRight:
            rotateCurrentImage(by: 1)
        case .flipHorizontal:
            flipCurrentImage(horizontal: true, vertical: false)
        case .flipVertical:
            flipCurrentImage(horizontal: false, vertical: true)
        case .cycleCanvasBackground:
            cycleCanvasBackground()
        case .togglePixelatedInterpolation:
            togglePixelatedInterpolation()
        case .toggleZoomLock:
            toggleZoomLock()
        case .toggleFilterBar:
            toggleFilterBar()
        case .copyImageBitmap:
            copyCurrentImageBitmap()
        case .recognizeText:
            recognizeCurrentImageText()
        case .saveTransformedImage:
            saveCurrentTransformedImage()
        case .revealInFinder:
            revealCurrentImageInFinder()
        case .copyFile:
            copyCurrentImageFile()
        case .copyFilePath:
            copyCurrentImagePath()
        case .moveToTrash:
            moveCurrentImageToTrash()
        case .pinCurrentImage:
            pinCurrentImage()
        }
    }

    func showImage(at index: Int) {
        guard !assets.isEmpty else { return }
        let wrappedIndex = (index + assets.count) % assets.count
        let asset = assets[wrappedIndex]
        currentIndex = wrappedIndex
        currentMetadata = nil
        pendingDecodeURL = asset.url

        if let cached = imageCache.result(for: asset.url) {
            pendingDecodeURL = nil
            currentImage = cached.image
            currentMetadata = cached.metadata
            let rotationQuarterTurns = rotationQuarterTurnsByURL[asset.url] ?? 0
            let flipState = flipStateByURL[asset.url] ?? (false, false)
            canvasView.setRotationQuarterTurns(rotationQuarterTurns)
            canvasView.setFlip(horizontal: flipState.horizontal, vertical: flipState.vertical)
            canvasView.setImage(
                cached.image,
                animatedImage: cached.animatedImage,
                longImageMode: shouldUseLongImageMode(
                    image: cached.image,
                    metadata: cached.metadata,
                    rotationQuarterTurns: rotationQuarterTurns
                )
            )
            view.window?.title = asset.fileName
            updateEmptyStateVisibility(animated: true)
            updateStatus()
            updateInfoPanel()
            refreshFilmstrip()
            showChromeTemporarily()
            preloadNearbyImages()
            return
        }

        topInfoLabel.stringValue = localizer.loading(asset.fileName)
        updateInfoPanel()
        showChromeTemporarily()

        DispatchQueue.global(qos: .userInitiated).async { [weak self, decoder, imageCache] in
            let result = Result { try decoder.decode(asset.url) }
            if case .success(let decoded) = result {
                imageCache.store(decoded, for: asset.url)
            }
            DispatchQueue.main.async {
                guard let self, self.pendingDecodeURL == asset.url else { return }
                self.pendingDecodeURL = nil

                switch result {
                case .success(let decoded):
                    self.currentImage = decoded.image
                    self.currentMetadata = decoded.metadata
                    let rotationQuarterTurns = self.rotationQuarterTurnsByURL[asset.url] ?? 0
                    let flipState = self.flipStateByURL[asset.url] ?? (false, false)
                    self.canvasView.setRotationQuarterTurns(rotationQuarterTurns)
                    self.canvasView.setFlip(horizontal: flipState.horizontal, vertical: flipState.vertical)
                    self.canvasView.setImage(
                        decoded.image,
                        animatedImage: decoded.animatedImage,
                        longImageMode: self.shouldUseLongImageMode(
                            image: decoded.image,
                            metadata: decoded.metadata,
                            rotationQuarterTurns: rotationQuarterTurns
                        )
                    )
                    self.view.window?.title = asset.fileName
                    self.updateEmptyStateVisibility(animated: true)
                    self.updateStatus()
                    self.updateInfoPanel()
                    self.refreshFilmstrip()
                    self.showChromeTemporarily()
                    self.preloadNearbyImages()
                case .failure:
                    self.showToast(self.localizer.unableToOpen(asset.fileName))
                }
            }
        }
    }

    func updateStatus() {
        topInfoLabel.stringValue = composeTopInfoText()
        zoomLabel.stringValue = "\(Int(canvasView.zoomScale * 100))%"
        pageLabel.stringValue = assets.isEmpty ? "0 / 0" : "\(currentIndex + 1) / \(assets.count)"
        showChromeTemporarily()
    }

    // 顶部信息条按 Picview 习惯展示 “文件名 | 像素 | 大小 | 页码 | 缩放 | 模式”
    func composeTopInfoText() -> String {
        var parts: [String] = []

        if let fileName = assets[safe: currentIndex]?.fileName ?? currentMetadata?.fileName {
            parts.append(fileName)
        }

        if let metadata = currentMetadata,
           let width = metadata.pixelWidth,
           let height = metadata.pixelHeight {
            parts.append("\(width) × \(height)")
        } else if let image = currentImage {
            parts.append("\(Int(image.size.width)) × \(Int(image.size.height))")
        }

        if let size = currentMetadata?.fileSize, size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }

        if !assets.isEmpty {
            parts.append("\(currentIndex + 1) / \(assets.count)")
        }

        parts.append("\(Int(canvasView.zoomScale * 100))%")

        if let currentImage,
           shouldUseLongImageMode(
            image: currentImage,
            metadata: currentMetadata,
            rotationQuarterTurns: currentAssetURL.flatMap { rotationQuarterTurnsByURL[$0] } ?? 0
           ) {
            parts.append(localizer.string(.longImageMode))
        }

        if isSlideshowRunning {
            parts.append(localizer.string(.slideshow))
        }

        if canvasView.isZoomLocked {
            parts.append(localizer.string(.zoomLockedBadge))
        }

        return parts.joined(separator: "  |  ")
    }

    func updateInfoPanel() {
        infoStack.arrangedSubviews.forEach { view in
            infoStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard let currentMetadata else {
            infoStack.addArrangedSubview(makeMetadataPlaceholder())
            return
        }

        if let currentImage, let histogram = ImageHistogram.compute(from: currentImage) {
            infoStack.addArrangedSubview(makeHistogramSectionView(histogram))
        }

        for section in currentMetadata.sections(language: settings.language) {
            infoStack.addArrangedSubview(makeMetadataSectionView(section))
        }
    }

    func makeHistogramSectionView(_ histogram: ImageHistogram) -> NSStackView {
        let sectionID = "histogram"
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.widthAnchor.constraint(equalToConstant: 320).isActive = true

        let header = makeMetadataSectionHeader(
            MetadataSection(id: sectionID, title: localizer.string(.histogram), rows: [])
        )
        stack.addArrangedSubview(header)

        if !collapsedMetadataSectionIDs.contains(sectionID) {
            let histogramView = HistogramView()
            histogramView.histogram = histogram
            histogramView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                histogramView.widthAnchor.constraint(equalToConstant: 320),
                histogramView.heightAnchor.constraint(equalToConstant: 76)
            ])
            stack.addArrangedSubview(histogramView)
        }

        return stack
    }

    func showToast(_ message: String) {
        toastHideWorkItem?.cancel()
        toastLabel.stringValue = message
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            toastContainer.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.toastContainer.animator().alphaValue = 0
            }
        }
        toastHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
        showChromeTemporarily()
    }

    func preloadNearbyImages() {
        guard assets.count > 1 else { return }
        let neighborIndexes = [
            (currentIndex - 1 + assets.count) % assets.count,
            (currentIndex + 1) % assets.count
        ]

        for index in Set(neighborIndexes) {
            let url = assets[index].url
            guard imageCache.result(for: url) == nil else { continue }

            DispatchQueue.global(qos: .utility).async { [decoder, imageCache] in
                guard imageCache.result(for: url) == nil,
                      let result = try? decoder.decode(url) else {
                    return
                }
                imageCache.store(result, for: url)
            }
        }
    }

    func shouldUseLongImageMode(image: NSImage, metadata: ImageMetadata?, rotationQuarterTurns: Int) -> Bool {
        guard settings.enableLongImageMode else { return false }

        var width = CGFloat(metadata?.pixelWidth ?? Int(image.size.width))
        var height = CGFloat(metadata?.pixelHeight ?? Int(image.size.height))
        if !rotationQuarterTurns.isMultiple(of: 2) {
            swap(&width, &height)
        }
        guard width > 0 else { return false }

        return height / width >= 2.2
    }

    func makeToolbarButton(symbolName: String, toolTip: String, action: Selector) -> ToolbarIconButton {
        ToolbarIconButton(symbolName: symbolName, toolTip: toolTip, target: self, action: action)
    }

    func syncToolbarActiveStates() {
        slideshowToolbarButton?.isActiveState = isSlideshowRunning
        infoToolbarButton?.isActiveState = !infoPanel.isHidden
        ocrToolbarButton?.isActiveState = !ocrPanel.isHidden
        immersiveToolbarButton?.isActiveState = isImmersiveChromeEnabled
        backgroundToolbarButton?.isActiveState = canvasView.backgroundStyle != .dark
    }

    func makeToolbarSeparator() -> NSView {
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(white: 1, alpha: 0.14).cgColor
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 18)
        ])
        return separator
    }

    func makeMetadataPlaceholder() -> NSTextField {
        let label = NSTextField(labelWithString: localizer.string(.noMetadataLoaded))
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor(white: 0.86, alpha: 0.85)
        return label
    }

    func makeMetadataSectionView(_ section: MetadataSection) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.widthAnchor.constraint(equalToConstant: 320).isActive = true

        stack.addArrangedSubview(makeMetadataSectionHeader(section))

        if !collapsedMetadataSectionIDs.contains(section.id) {
            for row in section.rows {
                stack.addArrangedSubview(makeMetadataRowView(row))
            }
        }

        return stack
    }

    func makeMetadataSectionHeader(_ section: MetadataSection) -> NSButton {
        let button = NSButton(title: section.title, target: self, action: #selector(toggleMetadataSection(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(section.id)
        button.bezelStyle = .inline
        button.isBordered = false
        button.contentTintColor = NSColor(white: 0.98, alpha: 0.96)
        button.image = NSImage(
            systemSymbolName: collapsedMetadataSectionIDs.contains(section.id) ? "chevron.right" : "chevron.down",
            accessibilityDescription: section.title
        )
        button.imagePosition = .imageLeading
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.alignment = .left
        return button
    }

    func makeMetadataRowView(_ row: MetadataRow) -> NSStackView {
        let label = NSTextField(labelWithString: row.label)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor(white: 0.72, alpha: 0.9)
        label.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let value = NSTextField(labelWithString: row.value)
        value.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        value.textColor = NSColor(white: 0.94, alpha: 0.96)
        value.lineBreakMode = .byTruncatingMiddle
        value.maximumNumberOfLines = 2

        let rowView = NSStackView(views: [label, value])
        rowView.orientation = .horizontal
        rowView.alignment = .top
        rowView.spacing = 8
        return rowView
    }

    func showChromeTemporarily() {
        chromeHideWorkItem?.cancel()

        // The empty state has its own UI affordances, so the floating chrome stays hidden there.
        guard !isShowingWelcomeState else { return }

        let filmstripVisible = !filmstripView.isHidden

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            topInfoBar.animator().alphaValue = 1
            bottomToolbar.animator().alphaValue = 1
            if filmstripVisible {
                filmstripView.animator().alphaValue = 1
            }
        }

        guard settings.autoHideChrome, hoveredChromeCount == 0, filterBar.isHidden, ocrPanel.isHidden else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.hoveredChromeCount == 0, self.filterBar.isHidden, self.ocrPanel.isHidden else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                self.topInfoBar.animator().alphaValue = 0
                self.bottomToolbar.animator().alphaValue = 0
                if !self.filmstripView.isHidden {
                    self.filmstripView.animator().alphaValue = 0
                }
            }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
        chromeHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }

    func toggleImmersiveChrome() {
        setImmersiveChrome(!isImmersiveChromeEnabled, showFeedback: true)
    }

    func toggleSlideshow() {
        if isSlideshowRunning {
            stopSlideshow(showFeedback: true)
        } else {
            startSlideshow()
        }
    }

    func startSlideshow() {
        guard assets.count > 1 else {
            showToast(localizer.string(.slideshowNeedTwoImages))
            return
        }

        isSlideshowRunning = true
        scheduleSlideshowTimer()
        syncToolbarActiveStates()
        updateStatus()
        showToast(localizer.string(.slideshowStarted))
    }

    func stopSlideshow(showFeedback: Bool) {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
        isSlideshowRunning = false
        syncToolbarActiveStates()
        updateStatus()

        if showFeedback {
            showToast(localizer.string(.slideshowStopped))
        }
    }

    func scheduleSlideshowTimer() {
        slideshowTimer?.invalidate()
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: settings.slideshowInterval, repeats: true) { [weak self] _ in
            self?.advanceSlideshow()
        }
    }

    func advanceSlideshow() {
        guard isSlideshowRunning, assets.count > 1 else {
            stopSlideshow(showFeedback: false)
            return
        }

        if settings.slideshowRandom {
            var nextIndex = currentIndex
            while nextIndex == currentIndex {
                nextIndex = Int.random(in: 0..<assets.count)
            }
            showImage(at: nextIndex)
            return
        }

        let nextIndex = currentIndex + 1
        if nextIndex < assets.count {
            showImage(at: nextIndex)
        } else if settings.slideshowLoop {
            showImage(at: 0)
        } else {
            stopSlideshow(showFeedback: true)
        }
    }

    func setImmersiveChrome(_ enabled: Bool, showFeedback: Bool) {
        guard let window = view.window else { return }
        guard enabled != isImmersiveChromeEnabled else { return }
        isImmersiveChromeEnabled = enabled
        syncToolbarActiveStates()

        if isImmersiveChromeEnabled {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            if showFeedback {
                showToast(localizer.string(.immersiveChromeOn))
            }
        } else {
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.styleMask.remove(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            if showFeedback {
                showToast(localizer.string(.immersiveChromeOff))
            }
        }
    }

    func showGrid() {
        guard !assets.isEmpty else {
            showToast(localizer.string(.noFolderImages))
            return
        }

        gridRequestHandler?(assets, assets[safe: currentIndex]?.url)
        showChromeTemporarily()
    }

    func pinCurrentImage() {
        guard let currentImage else {
            showToast(localizer.string(.noImageToPin))
            return
        }

        let title = assets[safe: currentIndex]?.fileName ?? currentMetadata?.fileName ?? localizer.string(.pinnedImageTitle)
        pinRequestHandler?(currentImage.copy() as? NSImage ?? currentImage, title)
        showToast(localizer.string(.pinnedImage))
    }

    func reloadToolbarButtons() {
        for group in [leadingToolGroup, centerToolGroup, trailingToolGroup] {
            for view in group.arrangedSubviews {
                group.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        leadingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "minus.magnifyingglass",
            toolTip: localizer.string(.zoomOut),
            action: #selector(zoomOutButtonPressed)
        ))
        leadingToolGroup.addArrangedSubview(zoomLabel)
        leadingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "plus.magnifyingglass",
            toolTip: localizer.string(.zoomIn),
            action: #selector(zoomInButtonPressed)
        ))
        leadingToolGroup.addArrangedSubview(makeToolbarSeparator())
        leadingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "arrow.down.right.and.arrow.up.left",
            toolTip: localizer.string(.fitToWindow),
            action: #selector(fitButtonPressed)
        ))
        leadingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "1.square",
            toolTip: localizer.string(.actualSize),
            action: #selector(actualSizeButtonPressed)
        ))

        centerToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "chevron.left",
            toolTip: localizer.string(.previousImage),
            action: #selector(previousImageButtonPressed)
        ))
        centerToolGroup.addArrangedSubview(pageLabel)
        centerToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "chevron.right",
            toolTip: localizer.string(.nextImage),
            action: #selector(nextImageButtonPressed)
        ))

        trailingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "square.grid.3x3",
            toolTip: localizer.string(.grid),
            action: #selector(gridButtonPressed)
        ))
        let slideshowBtn = makeToolbarButton(
            symbolName: "playpause",
            toolTip: localizer.string(.slideshow),
            action: #selector(slideshowButtonPressed)
        )
        slideshowToolbarButton = slideshowBtn
        trailingToolGroup.addArrangedSubview(slideshowBtn)

        trailingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "pin",
            toolTip: localizer.string(.pinImage),
            action: #selector(pinButtonPressed)
        ))
        trailingToolGroup.addArrangedSubview(makeToolbarSeparator())
        trailingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "rotate.left",
            toolTip: localizer.string(.rotateLeft),
            action: #selector(rotateLeftButtonPressed)
        ))
        trailingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "rotate.right",
            toolTip: localizer.string(.rotateRight),
            action: #selector(rotateRightButtonPressed)
        ))
        let bgBtn = makeToolbarButton(
            symbolName: "circle.lefthalf.filled",
            toolTip: localizer.string(.canvasBackground),
            action: #selector(backgroundButtonPressed)
        )
        backgroundToolbarButton = bgBtn
        trailingToolGroup.addArrangedSubview(bgBtn)

        let ocrBtn = makeToolbarButton(
            symbolName: "text.viewfinder",
            toolTip: localizer.string(.recognizeText),
            action: #selector(recognizeTextButtonPressed)
        )
        ocrToolbarButton = ocrBtn
        trailingToolGroup.addArrangedSubview(ocrBtn)
        trailingToolGroup.addArrangedSubview(makeToolbarSeparator())
        let infoBtn = makeToolbarButton(
            symbolName: "info.circle",
            toolTip: localizer.string(.metadata),
            action: #selector(infoButtonPressed)
        )
        infoToolbarButton = infoBtn
        trailingToolGroup.addArrangedSubview(infoBtn)

        trailingToolGroup.addArrangedSubview(makeToolbarButton(
            symbolName: "doc.on.doc",
            toolTip: localizer.string(.copyMetadata),
            action: #selector(copyMetadataButtonPressed)
        ))
        let immersiveBtn = makeToolbarButton(
            symbolName: "rectangle.compress.vertical",
            toolTip: localizer.string(.immersiveChrome),
            action: #selector(immersiveButtonPressed)
        )
        immersiveToolbarButton = immersiveBtn
        trailingToolGroup.addArrangedSubview(immersiveBtn)
        syncToolbarActiveStates()
    }

    @objc func previousImageButtonPressed() {
        handle(.previousImage)
    }

    @objc func nextImageButtonPressed() {
        handle(.nextImage)
    }

    @objc func zoomInButtonPressed() {
        handle(.zoomIn)
    }

    @objc func zoomOutButtonPressed() {
        handle(.zoomOut)
    }

    @objc func fitButtonPressed() {
        handle(.fitToWindow)
    }

    @objc func actualSizeButtonPressed() {
        handle(.actualSize)
    }

    @objc func gridButtonPressed() {
        handle(.toggleGrid)
    }

    @objc func slideshowButtonPressed() {
        handle(.toggleSlideshow)
    }

    @objc func pinButtonPressed() {
        handle(.pinCurrentImage)
    }

    @objc func infoButtonPressed() {
        handle(.toggleInfoPanel)
    }

    @objc func rotateLeftButtonPressed() {
        handle(.rotateLeft)
    }

    @objc func rotateRightButtonPressed() {
        handle(.rotateRight)
    }

    @objc func backgroundButtonPressed() {
        handle(.cycleCanvasBackground)
    }

    @objc func recognizeTextButtonPressed() {
        handle(.recognizeText)
    }

    @objc func copyMetadataButtonPressed() {
        guard let currentMetadata else {
            showToast(localizer.string(.noMetadataToCopy))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentMetadata.clipboardText(language: settings.language), forType: .string)
        showToast(localizer.string(.copiedMetadata))
    }

    @objc func immersiveButtonPressed() {
        handle(.toggleImmersiveChrome)
    }

    @objc func toggleMetadataSection(_ sender: NSButton) {
        guard let sectionID = sender.identifier?.rawValue else { return }
        if collapsedMetadataSectionIDs.contains(sectionID) {
            collapsedMetadataSectionIDs.remove(sectionID)
        } else {
            collapsedMetadataSectionIDs.insert(sectionID)
        }
        updateInfoPanel()
        showChromeTemporarily()
    }

    var currentAssetURL: URL? {
        assets[safe: currentIndex]?.url
    }

    var currentAnimatedImage: AnimatedImage? {
        guard let url = currentAssetURL else { return nil }
        return imageCache.result(for: url)?.animatedImage
    }

    func rotateCurrentImage(by delta: Int) {
        guard let url = currentAssetURL, let currentImage else { return }
        let updatedQuarterTurns = (((rotationQuarterTurnsByURL[url] ?? 0) + delta) % 4 + 4) % 4
        rotationQuarterTurnsByURL[url] = updatedQuarterTurns
        canvasView.setRotationQuarterTurns(updatedQuarterTurns)
        canvasView.setImage(
            currentImage,
            animatedImage: currentAnimatedImage,
            longImageMode: shouldUseLongImageMode(
                image: currentImage,
                metadata: currentMetadata,
                rotationQuarterTurns: updatedQuarterTurns
            )
        )
        updateStatus()
    }

    func flipCurrentImage(horizontal: Bool, vertical: Bool) {
        guard let url = currentAssetURL, currentImage != nil else { return }
        var state = flipStateByURL[url] ?? (false, false)
        if horizontal {
            state.horizontal.toggle()
        }
        if vertical {
            state.vertical.toggle()
        }
        flipStateByURL[url] = state
        canvasView.setFlip(horizontal: state.horizontal, vertical: state.vertical)
        showToast(localizer.string(horizontal ? .flippedHorizontal : .flippedVertical))
    }

    func cycleCanvasBackground() {
        guard !isShowingWelcomeState else { return }
        let nextStyle = canvasView.backgroundStyle.next
        canvasView.backgroundStyle = nextStyle
        syncToolbarActiveStates()
        let toastKey: Localizer.Key
        switch nextStyle {
        case .dark:
            toastKey = .backgroundDark
        case .checkerboard:
            toastKey = .backgroundCheckerboard
        case .light:
            toastKey = .backgroundLight
        case .ambient:
            toastKey = .backgroundAmbient
        }
        showToast(localizer.string(toastKey))
    }

    func togglePixelatedInterpolation() {
        guard !isShowingWelcomeState else { return }
        canvasView.isPixelatedInterpolation.toggle()
        showToast(localizer.string(canvasView.isPixelatedInterpolation ? .pixelatedOn : .pixelatedOff))
    }

    func toggleZoomLock() {
        guard !isShowingWelcomeState else { return }
        canvasView.isZoomLocked.toggle()
        updateStatus()
        showToast(localizer.string(canvasView.isZoomLocked ? .zoomLockOn : .zoomLockOff))
    }

    func toggleFilterBar() {
        guard !allAssets.isEmpty else { return }
        if filterBar.isHidden {
            filterBar.isHidden = false
            view.window?.makeFirstResponder(filterSearchField)
            showChromeTemporarily()
        } else {
            closeFilterBar()
        }
    }

    func closeFilterBar() {
        filterBar.isHidden = true
        if !filterQuery.isEmpty {
            filterQuery = ""
            filterSearchField.stringValue = ""
            applyFilterQuery("")
        }
        view.window?.makeFirstResponder(canvasView)
    }

    func filteredAssets(from source: [ImageAsset], query: String) -> [ImageAsset] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return source }
        return source.filter { $0.fileName.localizedCaseInsensitiveContains(trimmed) }
    }

    func applyFilterQuery(_ query: String) {
        let previousURL = currentAssetURL
        filterQuery = query
        let matches = filteredAssets(from: allAssets, query: query)
        guard !matches.isEmpty else {
            assets = []
            updateStatus()
            refreshFilmstrip()
            return
        }

        assets = matches
        if let previousURL, let existingIndex = assets.firstIndex(where: { $0.url == previousURL }) {
            currentIndex = existingIndex
            updateStatus()
            refreshFilmstrip()
        } else {
            showImage(at: 0)
        }
    }

    func copyCurrentImageBitmap() {
        guard let currentImage else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.writeObjects([currentImage]) {
            showToast(localizer.string(.copiedImageBitmap))
        } else {
            showToast(localizer.string(.fileOperationFailed))
        }
    }

    func saveCurrentTransformedImage() {
        guard let url = currentAssetURL, let currentImage else { return }
        let turns = rotationQuarterTurnsByURL[url] ?? 0
        let flip = flipStateByURL[url] ?? (false, false)
        guard turns != 0 || flip.horizontal || flip.vertical else {
            showToast(localizer.string(.nothingToSave))
            return
        }

        do {
            let decoded = try decoder.saveTransformedImage(
                currentImage,
                to: url,
                rotationQuarterTurns: turns,
                flipHorizontal: flip.horizontal,
                flipVertical: flip.vertical
            )
            rotationQuarterTurnsByURL.removeValue(forKey: url)
            flipStateByURL.removeValue(forKey: url)
            imageCache.store(decoded, for: url)
            thumbnailLoader.invalidateThumbnail(for: url)

            self.currentImage = decoded.image
            self.currentMetadata = decoded.metadata
            canvasView.setRotationQuarterTurns(0)
            canvasView.setFlip(horizontal: false, vertical: false)
            canvasView.setImage(
                decoded.image,
                animatedImage: decoded.animatedImage,
                longImageMode: shouldUseLongImageMode(
                    image: decoded.image,
                    metadata: decoded.metadata,
                    rotationQuarterTurns: 0
                )
            )
            updateStatus()
            updateInfoPanel()
            refreshFilmstrip()
            showToast(localizer.string(.savedImage))
        } catch {
            showToast(localizer.string(.fileOperationFailed))
        }
    }

    func recognizeCurrentImageText() {
        guard let currentImage else { return }
        var rect = NSRect(origin: .zero, size: currentImage.size)
        guard let cgImage = currentImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            showOCRPanel(with: localizer.string(.noTextRecognized))
            showToast(localizer.string(.noTextRecognized))
            return
        }

        showOCRPanel(with: localizer.string(.recognizingText))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])

            let recognizedLines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let fullText = recognizedLines.joined(separator: "\n")

            DispatchQueue.main.async {
                guard let self else { return }
                guard !fullText.isEmpty else {
                    self.showOCRPanel(with: self.localizer.string(.noTextRecognized))
                    self.showToast(self.localizer.string(.noTextRecognized))
                    return
                }
                self.showOCRPanel(with: fullText)
            }
        }
    }

    func showOCRPanel(with text: String) {
        infoPanel.isHidden = true
        ocrPanel.isHidden = false
        ocrTextView.string = text
        syncToolbarActiveStates()
        showChromeTemporarily()
    }

    @objc func copyOCRTextButtonPressed() {
        let text = ocrTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              text != localizer.string(.noTextRecognized),
              text != localizer.string(.recognizingText) else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ocrTextView.string, forType: .string)
        showToast(localizer.string(.recognizedTextCopied))
    }

    @objc func closeOCRPanelButtonPressed() {
        ocrPanel.isHidden = true
        syncToolbarActiveStates()
        view.window?.makeFirstResponder(canvasView)
    }

    func revealCurrentImageInFinder() {
        guard let url = currentAssetURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyCurrentImageFile() {
        guard let url = currentAssetURL else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.writeObjects([url as NSURL]) {
            showToast(localizer.string(.copiedFile))
        } else {
            showToast(localizer.string(.fileOperationFailed))
        }
    }

    func copyCurrentImagePath() {
        guard let url = currentAssetURL else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(url.path, forType: .string) {
            showToast(localizer.string(.copiedFilePath))
        } else {
            showToast(localizer.string(.fileOperationFailed))
        }
    }

    func moveCurrentImageToTrash() {
        guard let url = currentAssetURL else { return }

        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            rotationQuarterTurnsByURL.removeValue(forKey: url)
            flipStateByURL.removeValue(forKey: url)

            let removedIndex = currentIndex
            allAssets.removeAll { $0.url == url }
            assets.removeAll { $0.url == url }
            if assets.isEmpty {
                pendingDecodeURL = nil
                currentImage = nil
                currentMetadata = nil
                canvasView.clearImage()
                updateEmptyStateVisibility(animated: true)
                refreshFilmstrip()
                updateInfoPanel()
                showToast(localizer.string(.movedToTrash))
                return
            }

            let nextIndex = min(removedIndex, assets.count - 1)
            showImage(at: nextIndex)
            showToast(localizer.string(.movedToTrash))
        } catch {
            showToast(localizer.string(.fileOperationFailed))
        }
    }
}

extension ViewerViewController {
    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSSearchField === filterSearchField else { return }
        applyFilterQuery(filterSearchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === filterSearchField else { return false }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            closeFilterBar()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            view.window?.makeFirstResponder(canvasView)
            return true
        }
        return false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private enum ViewerChromeLayout {
    static let infoBarTopPadding: CGFloat = 14
    static let infoBarHeight: CGFloat = 30
    static let imageInfoBarGap: CGFloat = 12
    static let toolbarBottomPadding: CGFloat = 16
    static let toolbarHeight: CGFloat = 44
    static let filmstripToolbarGap: CGFloat = 12
    static let imageFilmstripGap: CGFloat = 12

    static var topInsetWhenInfoBarVisible: CGFloat {
        infoBarTopPadding + infoBarHeight + imageInfoBarGap
    }

    static var bottomInsetWhenToolbarOnly: CGFloat {
        toolbarBottomPadding + toolbarHeight + imageFilmstripGap
    }

    static var bottomInsetWhenFilmstripVisible: CGFloat {
        toolbarBottomPadding + toolbarHeight + filmstripToolbarGap + FilmstripView.preferredHeight + imageFilmstripGap
    }
}
