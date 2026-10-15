import AppKit

protocol MainMenuActions: AnyObject {
    func openImageFromMenu()
    func openFolderFromMenu()
    func pinClipboardFromMenu()
    func showPreferencesFromMenu()
    func revealCurrentImageFromMenu()
    func saveTransformedImageFromMenu()
    func copyCurrentImageBitmapFromMenu()
    func copyCurrentImageFromMenu()
    func copyCurrentImagePathFromMenu()
    func recognizeTextFromMenu()
    func filterImagesFromMenu()
    func moveCurrentImageToTrashFromMenu()
    func fitToWindowFromMenu()
    func actualSizeFromMenu()
    func toggleGridFromMenu()
    func toggleFilmstripFromMenu()
    func toggleInfoPanelFromMenu()
    func toggleImmersiveChromeFromMenu()
    func toggleSlideshowFromMenu()
    func rotateLeftFromMenu()
    func rotateRightFromMenu()
    func flipHorizontalFromMenu()
    func flipVerticalFromMenu()
    func cycleBackgroundFromMenu()
    func togglePixelatedFromMenu()
    func toggleZoomLockFromMenu()
}

final class MainMenu: NSObject {
    private weak var actions: MainMenuActions?

    private init(actions: MainMenuActions) {
        self.actions = actions
    }

    static func install(actions: MainMenuActions, language: AppLanguage) {
        let menuHandler = MainMenu(actions: actions)
        MenuHandlerStore.shared.handler = menuHandler

        let mainMenu = NSMenu()
        let localizer = Localizer(language: language)
        mainMenu.addItem(Self.appMenu(handler: menuHandler, localizer: localizer))
        mainMenu.addItem(Self.fileMenu(handler: menuHandler, localizer: localizer))
        mainMenu.addItem(Self.viewMenu(handler: menuHandler, localizer: localizer))
        mainMenu.addItem(Self.windowMenu(localizer: localizer))
        NSApp.mainMenu = mainMenu
    }

    @objc private func openImage() {
        actions?.openImageFromMenu()
    }

    @objc private func openFolder() {
        actions?.openFolderFromMenu()
    }

    @objc private func pinClipboard() {
        actions?.pinClipboardFromMenu()
    }

    @objc private func showPreferences() {
        actions?.showPreferencesFromMenu()
    }

    @objc private func revealCurrentImage() {
        actions?.revealCurrentImageFromMenu()
    }

    @objc private func copyCurrentImage() {
        actions?.copyCurrentImageFromMenu()
    }

    @objc private func copyCurrentImagePath() {
        actions?.copyCurrentImagePathFromMenu()
    }

    @objc private func moveCurrentImageToTrash() {
        actions?.moveCurrentImageToTrashFromMenu()
    }

    @objc private func rotateLeft() {
        actions?.rotateLeftFromMenu()
    }

    @objc private func rotateRight() {
        actions?.rotateRightFromMenu()
    }

    @objc private func copyCurrentImageBitmap() {
        actions?.copyCurrentImageBitmapFromMenu()
    }

    @objc private func recognizeText() {
        actions?.recognizeTextFromMenu()
    }

    @objc private func filterImages() {
        actions?.filterImagesFromMenu()
    }

    @objc private func flipHorizontal() {
        actions?.flipHorizontalFromMenu()
    }

    @objc private func flipVertical() {
        actions?.flipVerticalFromMenu()
    }

    @objc private func cycleBackground() {
        actions?.cycleBackgroundFromMenu()
    }

    @objc private func togglePixelated() {
        actions?.togglePixelatedFromMenu()
    }

    @objc private func toggleZoomLock() {
        actions?.toggleZoomLockFromMenu()
    }

    @objc private func saveTransformedImage() {
        actions?.saveTransformedImageFromMenu()
    }

    @objc private func fitToWindow() {
        actions?.fitToWindowFromMenu()
    }

    @objc private func actualSize() {
        actions?.actualSizeFromMenu()
    }

    @objc private func toggleGrid() {
        actions?.toggleGridFromMenu()
    }

    @objc private func toggleFilmstrip() {
        actions?.toggleFilmstripFromMenu()
    }

    @objc private func toggleInfoPanel() {
        actions?.toggleInfoPanelFromMenu()
    }

    @objc private func toggleImmersiveChrome() {
        actions?.toggleImmersiveChromeFromMenu()
    }

    @objc private func toggleSlideshow() {
        actions?.toggleSlideshowFromMenu()
    }
}

private extension MainMenu {
    static func appMenu(handler: MainMenu, localizer: Localizer) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: "Visora")
        menu.addItem(NSMenuItem(
            title: localizer.string(.preferences),
            action: #selector(MainMenu.showPreferences),
            keyEquivalent: ","
        ))
        menu.items.last?.target = handler
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: localizer.string(.quitVisora), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        root.submenu = menu
        return root
    }

    static func fileMenu(handler: MainMenu, localizer: Localizer) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: localizer.string(.fileMenu))

        let openImage = Self.makeMenuItem(
            title: localizer.string(.openImage),
            symbol: "photo.badge.plus",
            action: #selector(MainMenu.openImage),
            keyEquivalent: "o",
            target: handler
        )
        menu.addItem(openImage)

        let openFolder = Self.makeMenuItem(
            title: localizer.string(.openFolder),
            symbol: "folder.badge.plus",
            action: #selector(MainMenu.openFolder),
            keyEquivalent: "O",
            modifiers: [.command, .shift],
            target: handler
        )
        menu.addItem(openFolder)

        let pinClipboard = Self.makeMenuItem(
            title: localizer.string(.pinClipboard),
            symbol: "pin",
            action: #selector(MainMenu.pinClipboard),
            keyEquivalent: "v",
            modifiers: [.command, .shift],
            target: handler
        )
        menu.addItem(pinClipboard)

        menu.addItem(.separator())
        let saveItem = Self.makeMenuItem(
            title: localizer.string(.save),
            symbol: "square.and.arrow.down",
            action: #selector(MainMenu.saveTransformedImage),
            keyEquivalent: "s",
            target: handler
        )
        menu.addItem(saveItem)

        let revealInFinder = Self.makeMenuItem(
            title: localizer.string(.revealInFinder),
            symbol: "folder",
            action: #selector(MainMenu.revealCurrentImage),
            keyEquivalent: "r",
            target: handler
        )
        menu.addItem(revealInFinder)

        let filterImages = Self.makeMenuItem(
            title: localizer.string(.filterImages),
            symbol: "magnifyingglass",
            action: #selector(MainMenu.filterImages),
            keyEquivalent: "f",
            target: handler
        )
        menu.addItem(filterImages)

        let copyBitmap = Self.makeMenuItem(
            title: localizer.string(.copyImageBitmap),
            symbol: "doc.on.clipboard",
            action: #selector(MainMenu.copyCurrentImageBitmap),
            keyEquivalent: "c",
            target: handler
        )
        menu.addItem(copyBitmap)

        let copyFile = Self.makeMenuItem(
            title: localizer.string(.copyFile),
            symbol: "doc.on.doc",
            action: #selector(MainMenu.copyCurrentImage),
            keyEquivalent: "c",
            modifiers: [.command, .shift],
            target: handler
        )
        menu.addItem(copyFile)

        let copyPath = Self.makeMenuItem(
            title: localizer.string(.copyFilePath),
            symbol: "link",
            action: #selector(MainMenu.copyCurrentImagePath),
            keyEquivalent: "c",
            modifiers: [.command, .option],
            target: handler
        )
        menu.addItem(copyPath)

        let recognizeText = Self.makeMenuItem(
            title: localizer.string(.recognizeText),
            symbol: "text.viewfinder",
            action: #selector(MainMenu.recognizeText),
            keyEquivalent: "o",
            modifiers: [],
            target: handler
        )
        menu.addItem(recognizeText)

        let trashImage = Self.makeMenuItem(
            title: localizer.string(.trashImage),
            symbol: "trash",
            action: #selector(MainMenu.moveCurrentImageToTrash),
            keyEquivalent: "\u{8}",
            target: handler
        )
        menu.addItem(trashImage)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: localizer.string(.close), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        root.submenu = menu
        return root
    }

    static func viewMenu(handler: MainMenu, localizer: Localizer) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: localizer.string(.view))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.fitToWindow),
            symbol: "arrow.down.right.and.arrow.up.left",
            action: #selector(MainMenu.fitToWindow),
            keyEquivalent: "9",
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.actualSize),
            symbol: "1.square",
            action: #selector(MainMenu.actualSize),
            keyEquivalent: "0",
            target: handler
        ))

        menu.addItem(.separator())

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.grid),
            symbol: "square.grid.3x3",
            action: #selector(MainMenu.toggleGrid),
            keyEquivalent: "g",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.filmstrip),
            symbol: "film",
            action: #selector(MainMenu.toggleFilmstrip),
            keyEquivalent: "t",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.metadata),
            symbol: "info.circle",
            action: #selector(MainMenu.toggleInfoPanel),
            keyEquivalent: "i",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.immersiveChrome),
            symbol: "rectangle.compress.vertical",
            action: #selector(MainMenu.toggleImmersiveChrome),
            keyEquivalent: "c",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.slideshow),
            symbol: "play.rectangle",
            action: #selector(MainMenu.toggleSlideshow),
            keyEquivalent: "s",
            modifiers: [],
            target: handler
        ))

        menu.addItem(.separator())

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.rotateLeft),
            symbol: "rotate.left",
            action: #selector(MainMenu.rotateLeft),
            keyEquivalent: "[",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.rotateRight),
            symbol: "rotate.right",
            action: #selector(MainMenu.rotateRight),
            keyEquivalent: "]",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.flipHorizontal),
            symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right",
            action: #selector(MainMenu.flipHorizontal),
            keyEquivalent: "h",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.flipVertical),
            symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down",
            action: #selector(MainMenu.flipVertical),
            keyEquivalent: "v",
            modifiers: [],
            target: handler
        ))

        menu.addItem(.separator())

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.canvasBackground),
            symbol: "circle.lefthalf.filled",
            action: #selector(MainMenu.cycleBackground),
            keyEquivalent: "b",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.pixelatedInterpolation),
            symbol: "squareshape.split.2x2",
            action: #selector(MainMenu.togglePixelated),
            keyEquivalent: "n",
            modifiers: [],
            target: handler
        ))

        menu.addItem(Self.makeMenuItem(
            title: localizer.string(.zoomLock),
            symbol: "lock.square",
            action: #selector(MainMenu.toggleZoomLock),
            keyEquivalent: "l",
            modifiers: [],
            target: handler
        ))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: localizer.string(.toggleFullScreen), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
        root.submenu = menu
        return root
    }

    static func makeMenuItem(
        title: String,
        symbol: String,
        action: Selector,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        if #available(macOS 27.0, *) {
            item.preferredImageVisibility = .visible
        }
        return item
    }

    static func windowMenu(localizer: Localizer) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: localizer.string(.window))
        menu.addItem(NSMenuItem(title: localizer.string(.minimize), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        root.submenu = menu
        NSApp.windowsMenu = menu
        return root
    }
}

private final class MenuHandlerStore {
    static let shared = MenuHandlerStore()
    var handler: MainMenu?
}
