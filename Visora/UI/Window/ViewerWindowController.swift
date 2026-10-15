import AppKit

final class ViewerWindowController: NSWindowController {
    private let viewerViewController: ViewerViewController

    var openURLHandler: ((URL) -> Void)? {
        get { viewerViewController.openURLHandler }
        set { viewerViewController.openURLHandler = newValue }
    }

    var gridRequestHandler: (([ImageAsset], URL?) -> Void)? {
        get { viewerViewController.gridRequestHandler }
        set { viewerViewController.gridRequestHandler = newValue }
    }

    var pinRequestHandler: ((NSImage, String) -> Void)? {
        get { viewerViewController.pinRequestHandler }
        set { viewerViewController.pinRequestHandler = newValue }
    }

    var chooseImageHandler: (() -> Void)? {
        get { viewerViewController.chooseImageHandler }
        set { viewerViewController.chooseImageHandler = newValue }
    }

    var chooseFolderHandler: (() -> Void)? {
        get { viewerViewController.chooseFolderHandler }
        set { viewerViewController.chooseFolderHandler = newValue }
    }

    var openPreferencesHandler: (() -> Void)? {
        get { viewerViewController.openPreferencesHandler }
        set { viewerViewController.openPreferencesHandler = newValue }
    }

    var openRecentItemHandler: ((RecentItem) -> Void)? {
        get { viewerViewController.openRecentItemHandler }
        set { viewerViewController.openRecentItemHandler = newValue }
    }

    var clearRecentItemsHandler: (() -> Void)? {
        get { viewerViewController.clearRecentItemsHandler }
        set { viewerViewController.clearRecentItemsHandler = newValue }
    }

    init(decoder: ImageIODecoder, imageCache: ImageMemoryCache, thumbnailLoader: ThumbnailLoader) {
        self.viewerViewController = ViewerViewController(
            decoder: decoder,
            imageCache: imageCache,
            thumbnailLoader: thumbnailLoader
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: ViewerWindowLayout.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Visora"
        window.contentMinSize = ViewerWindowLayout.minimumAdaptiveContentSize
        window.minSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: ViewerWindowLayout.minimumAdaptiveContentSize)
        ).size
        window.contentViewController = viewerViewController
        window.setContentSize(ViewerWindowLayout.defaultContentSize)
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    var currentDisplayedURL: URL? {
        viewerViewController.currentDisplayedURL
    }

    func setSession(assets: [ImageAsset], currentURL: URL, decodedImage: NSImage, metadata: ImageMetadata) {
        adaptWindowSize(to: decodedImage, metadata: metadata)
        viewerViewController.setSession(
            assets: assets,
            currentURL: currentURL,
            decodedImage: decodedImage,
            metadata: metadata
        )
        window?.title = currentURL.lastPathComponent
    }

    func reloadFolderAssets(_ assets: [ImageAsset]) {
        viewerViewController.reloadFolderAssets(assets)
    }

    func setLoading(assets: [ImageAsset], currentURL: URL) {
        viewerViewController.setLoading(assets: assets, currentURL: currentURL)
        window?.title = currentURL.lastPathComponent
    }

    func showOpenError(for url: URL) {
        viewerViewController.showOpenError(for: url)
    }

    func apply(settings: AppSettings) {
        viewerViewController.apply(settings: settings)
    }

    func updateRecentItems(_ items: [RecentItem]) {
        viewerViewController.updateRecentItems(items)
    }

    func handle(_ command: ViewerCommand) {
        viewerViewController.perform(command)
    }
}

private extension ViewerWindowController {
    func adaptWindowSize(to image: NSImage, metadata: ImageMetadata) {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }

        let imageSize = NSSize(
            width: CGFloat(metadata.pixelWidth ?? Int(image.size.width)),
            height: CGFloat(metadata.pixelHeight ?? Int(image.size.height))
        )
        let contentSize = ViewerWindowLayout.adaptiveContentSize(
            for: imageSize,
            visibleFrame: (window.screen ?? NSScreen.main)?.visibleFrame
        )
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(origin: .zero, size: frameSize)
        let origin = NSPoint(
            x: visibleFrame.midX - frameSize.width / 2,
            y: visibleFrame.midY - frameSize.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: frameSize), display: true, animate: false)
    }
}

private enum ViewerWindowLayout {
    static let defaultContentSize = NSSize(width: 1280, height: 840)
    static let minimumAdaptiveContentSize = NSSize(width: 780, height: 540)
    static let maxVisibleWidthRatio: CGFloat = 0.88
    static let maxVisibleHeightRatio: CGFloat = 0.84

    static func adaptiveContentSize(for imageSize: NSSize, visibleFrame: NSRect?) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return defaultContentSize
        }

        let visibleSize = visibleFrame?.size ?? defaultContentSize
        let maximumSize = NSSize(
            width: max(minimumAdaptiveContentSize.width, visibleSize.width * maxVisibleWidthRatio),
            height: max(minimumAdaptiveContentSize.height, visibleSize.height * maxVisibleHeightRatio)
        )
        let scale = min(1, maximumSize.width / imageSize.width, maximumSize.height / imageSize.height)
        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return NSSize(
            width: min(max(scaledSize.width, minimumAdaptiveContentSize.width), maximumSize.width),
            height: min(max(scaledSize.height, minimumAdaptiveContentSize.height), maximumSize.height)
        )
    }
}
