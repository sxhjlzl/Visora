import AppKit

final class SceneCoordinator {
    private let decoder = ImageIODecoder()
    private let imageCache = ImageMemoryCache()
    private let thumbnailLoader = ThumbnailLoader()
    private let scanner = FileScanner()
    private let folderMonitor = FolderMonitor()
    private let preferencesStore = PreferencesStore()
    private let recentItemsStore = RecentItemsStore()
    private var viewerWindowController: ViewerWindowController?
    private var gridWindowController: GridWindowController?
    private var pinWindowControllers: [PinWindowController] = []
    private var preferencesWindowController: PreferencesWindowController?
    private var pendingOpenURL: URL?
    private var activeFolderURL: URL?
    private var settings: AppSettings
    private var recentItems: [RecentItem]
    var settingsChangedHandler: ((AppSettings) -> Void)?
    var language: AppLanguage {
        settings.language
    }
    /// 暴露当前最新的偏好设置，便于 AppDelegate 等外部协作组件读取
    var currentSettings: AppSettings {
        settings
    }

    init() {
        self.settings = preferencesStore.load()
        self.recentItems = recentItemsStore.load()
        imageCache.updateCountLimit(settings.cacheCountLimit)
    }

    func showEmptyViewer() {
        let controller = makeViewerIfNeeded()
        pruneMissingRecentItems()
        controller.updateRecentItems(recentItems)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func reopenMainWindowIfNeeded() {
        let controller = makeViewerIfNeeded()
        pruneMissingRecentItems()
        controller.updateRecentItems(recentItems)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func openImage(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            removeRecentItem(url: url)
            showError(Localizer(language: settings.language).unableToOpen(url.lastPathComponent))
            return
        }

        guard ImageFormat.isSupported(url) else {
            showError(Localizer(language: settings.language).string(.openUnsupported))
            return
        }

        let folder = url.deletingLastPathComponent()
        activeFolderURL = folder
        let assets = scanner.scan(folder: folder, currentURL: url, options: settings.folderScanOptions)
        updateRecentItems(url: url, kind: .file)
        open(url: url, assets: assets)
        watchFolder(folder)
    }

    func openFolder(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            removeRecentItem(url: url)
            showError(Localizer(language: settings.language).unableToOpen(url.lastPathComponent))
            return
        }

        activeFolderURL = url
        let assets = scanner.scan(folder: url, currentURL: nil, options: settings.folderScanOptions)
        guard let first = assets.first else {
            showError(Localizer(language: settings.language).string(.supportedImagesNotFound))
            return
        }
        updateRecentItems(url: url, kind: .folder)
        open(url: first.url, assets: assets)
        watchFolder(url)
    }

    func clearRecentItems() {
        recentItemsStore.clear()
        recentItems = []
        viewerWindowController?.updateRecentItems(recentItems)
    }

    func showPreferencesPlaceholder() {
        if let existing = preferencesWindowController {
            existing.apply(settings: settings)
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = PreferencesWindowController(settings: settings) { [weak self] newSettings in
            self?.apply(settings: newSettings)
        }
        preferencesWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// 弹出系统选择面板让用户挑选单张图片，统一服务于菜单与欢迎页按钮
    func promptOpenImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ImageFormat.supportedContentTypes

        if panel.runModal() == .OK, let url = panel.url {
            openImage(url)
        }
    }

    /// 弹出系统选择面板让用户挑选文件夹，统一服务于菜单与欢迎页按钮
    func promptOpenFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url)
        }
    }

    func pinClipboardItem() {
        let pasteboard = NSPasteboard.general
        let localizer = Localizer(language: settings.language)

        // Prefer images when both image and text representations exist, matching the pinboard's primary visual use case.
        if let image = NSImage(pasteboard: pasteboard) {
            pin(image: image, title: localizer.string(.pinnedClipboardImageTitle))
            return
        }

        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pin(text: text, title: localizer.string(.pinnedClipboardTextTitle))
            return
        }

        showError(localizer.string(.pinClipboardEmpty))
    }

    func handleViewerCommand(_ command: ViewerCommand) {
        viewerWindowController?.handle(command)
    }
}

private extension SceneCoordinator {
    func apply(settings newSettings: AppSettings) {
        settings = newSettings.normalized
        preferencesStore.save(settings)
        imageCache.updateCountLimit(settings.cacheCountLimit)
        viewerWindowController?.apply(settings: settings)
        gridWindowController?.apply(settings: settings)
        preferencesWindowController?.apply(settings: settings)
        if let activeFolderURL {
            let refreshedAssets = scanner.scan(
                folder: activeFolderURL,
                currentURL: viewerWindowController?.currentDisplayedURL,
                options: settings.folderScanOptions
            )
            viewerWindowController?.reloadFolderAssets(refreshedAssets)
            if gridWindowController?.window?.isVisible == true {
                gridWindowController?.update(
                    assets: refreshedAssets,
                    currentURL: viewerWindowController?.currentDisplayedURL
                )
            }
        }
        // The main menu is installed by AppDelegate, so language changes are reported back to that owner.
        settingsChangedHandler?(settings)
    }

    func open(url: URL, assets: [ImageAsset]) {
        let controller = makeViewerIfNeeded()
        pendingOpenURL = url
        controller.setLoading(assets: assets, currentURL: url)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)

        if let cached = imageCache.result(for: url) {
            controller.setSession(assets: assets, currentURL: url, decodedImage: cached.image, metadata: cached.metadata)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self, decoder, imageCache] in
            let result = Result { try decoder.decode(url) }
            if case .success(let decoded) = result {
                imageCache.store(decoded, for: url)
            }
            DispatchQueue.main.async {
                guard let self, self.pendingOpenURL == url else { return }
                switch result {
                case .success(let decoded):
                    controller.setSession(assets: assets, currentURL: url, decodedImage: decoded.image, metadata: decoded.metadata)
                case .failure:
                    controller.showOpenError(for: url)
                }
            }
        }
    }

    func handleDroppedURL(_ url: URL) {
        if url.hasDirectoryPath {
            openFolder(url)
        } else {
            openImage(url)
        }
    }

    func showGrid(assets: [ImageAsset], currentURL: URL?) {
        let controller = makeGridIfNeeded()
        controller.update(assets: assets, currentURL: currentURL)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func makeGridIfNeeded() -> GridWindowController {
        if let gridWindowController {
            return gridWindowController
        }

        let controller = GridWindowController(
            settings: settings,
            thumbnailLoader: thumbnailLoader,
            imageCache: imageCache
        ) { [weak self] url in
            self?.gridWindowController?.close()
            self?.openImage(url)
        }
        gridWindowController = controller
        return controller
    }

    func pin(image: NSImage, title: String) {
        let controller = PinWindowController(image: image, title: title, localizer: Localizer(language: settings.language))
        trackPinWindow(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func pin(text: String, title: String) {
        let controller = PinWindowController(text: text, title: title, localizer: Localizer(language: settings.language))
        trackPinWindow(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func trackPinWindow(_ controller: PinWindowController) {
        pinWindowControllers.append(controller)
        guard let window = controller.window else { return }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak controller] _ in
            guard let self, let controller else { return }
            self.pinWindowControllers.removeAll { $0 === controller }
        }
    }

    func watchFolder(_ folder: URL) {
        folderMonitor.startMonitoring(folderURL: folder) { [weak self] in
            guard let self, let activeFolderURL = self.activeFolderURL else { return }
            let currentURL = self.viewerWindowController?.currentDisplayedURL
            let refreshedAssets = self.scanner.scan(
                folder: activeFolderURL,
                currentURL: nil,
                options: self.settings.folderScanOptions
            )
            self.viewerWindowController?.reloadFolderAssets(refreshedAssets)
            if let gridWindowController = self.gridWindowController,
               gridWindowController.window?.isVisible == true {
                gridWindowController.update(
                    assets: refreshedAssets,
                    currentURL: self.viewerWindowController?.currentDisplayedURL ?? currentURL
                )
            }
        }
    }

    func makeViewerIfNeeded() -> ViewerWindowController {
        if let viewerWindowController {
            return viewerWindowController
        }

        let controller = ViewerWindowController(
            decoder: decoder,
            imageCache: imageCache,
            thumbnailLoader: thumbnailLoader
        )
        controller.apply(settings: settings)
        controller.openURLHandler = { [weak self] url in
            self?.handleDroppedURL(url)
        }
        controller.gridRequestHandler = { [weak self] assets, currentURL in
            self?.showGrid(assets: assets, currentURL: currentURL)
        }
        controller.pinRequestHandler = { [weak self] image, title in
            self?.pin(image: image, title: title)
        }
        controller.chooseImageHandler = { [weak self] in
            self?.promptOpenImage()
        }
        controller.chooseFolderHandler = { [weak self] in
            self?.promptOpenFolder()
        }
        controller.openPreferencesHandler = { [weak self] in
            self?.showPreferencesPlaceholder()
        }
        controller.openRecentItemHandler = { [weak self] item in
            switch item.kind {
            case .file:
                self?.openImage(item.url)
            case .folder:
                self?.openFolder(item.url)
            }
        }
        controller.clearRecentItemsHandler = { [weak self] in
            self?.clearRecentItems()
        }
        controller.updateRecentItems(recentItems)
        viewerWindowController = controller
        return controller
    }

    func updateRecentItems(url: URL, kind: RecentItem.Kind) {
        recentItems = recentItemsStore.record(url: url, kind: kind)
        viewerWindowController?.updateRecentItems(recentItems)
    }

    func removeRecentItem(url: URL) {
        recentItems = recentItemsStore.remove(url: url)
        viewerWindowController?.updateRecentItems(recentItems)
    }

    func pruneMissingRecentItems() {
        let missing = recentItems.filter { !FileManager.default.fileExists(atPath: $0.url.path) }
        for item in missing {
            recentItems = recentItemsStore.remove(url: item.url)
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Visora"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
