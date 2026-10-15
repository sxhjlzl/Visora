import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sceneCoordinator = SceneCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install(actions: self, language: sceneCoordinator.language)
        sceneCoordinator.settingsChangedHandler = { [weak self] settings in
            guard let self else { return }
            MainMenu.install(actions: self, language: settings.language)
        }
        NSApp.activate(ignoringOtherApps: true)

        if let startupURL = Self.startupURL() {
            if startupURL.hasDirectoryPath {
                sceneCoordinator.openFolder(startupURL)
            } else {
                sceneCoordinator.openImage(startupURL)
            }
        } else {
            sceneCoordinator.showEmptyViewer()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if url.hasDirectoryPath {
            sceneCoordinator.openFolder(url)
        } else {
            sceneCoordinator.openImage(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sceneCoordinator.reopenMainWindowIfNeeded()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 跟随偏好设置中的“所有窗口关闭时退出”选项，未勾选时让应用驻留 Dock 等待用户重新打开
        sceneCoordinator.currentSettings.quitWhenLastWindowClosed
    }
}

extension AppDelegate: MainMenuActions {
    func openImageFromMenu() {
        sceneCoordinator.promptOpenImage()
    }

    func openFolderFromMenu() {
        sceneCoordinator.promptOpenFolder()
    }

    func pinClipboardFromMenu() {
        sceneCoordinator.pinClipboardItem()
    }

    func showPreferencesFromMenu() {
        sceneCoordinator.showPreferencesPlaceholder()
    }

    func revealCurrentImageFromMenu() {
        sceneCoordinator.handleViewerCommand(.revealInFinder)
    }

    func copyCurrentImageFromMenu() {
        sceneCoordinator.handleViewerCommand(.copyFile)
    }

    func copyCurrentImagePathFromMenu() {
        sceneCoordinator.handleViewerCommand(.copyFilePath)
    }

    func moveCurrentImageToTrashFromMenu() {
        sceneCoordinator.handleViewerCommand(.moveToTrash)
    }

    func rotateLeftFromMenu() {
        sceneCoordinator.handleViewerCommand(.rotateLeft)
    }

    func rotateRightFromMenu() {
        sceneCoordinator.handleViewerCommand(.rotateRight)
    }

    func copyCurrentImageBitmapFromMenu() {
        sceneCoordinator.handleViewerCommand(.copyImageBitmap)
    }

    func recognizeTextFromMenu() {
        sceneCoordinator.handleViewerCommand(.recognizeText)
    }

    func filterImagesFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleFilterBar)
    }

    func flipHorizontalFromMenu() {
        sceneCoordinator.handleViewerCommand(.flipHorizontal)
    }

    func flipVerticalFromMenu() {
        sceneCoordinator.handleViewerCommand(.flipVertical)
    }

    func cycleBackgroundFromMenu() {
        sceneCoordinator.handleViewerCommand(.cycleCanvasBackground)
    }

    func togglePixelatedFromMenu() {
        sceneCoordinator.handleViewerCommand(.togglePixelatedInterpolation)
    }

    func toggleZoomLockFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleZoomLock)
    }

    func saveTransformedImageFromMenu() {
        sceneCoordinator.handleViewerCommand(.saveTransformedImage)
    }

    func fitToWindowFromMenu() {
        sceneCoordinator.handleViewerCommand(.fitToWindow)
    }

    func actualSizeFromMenu() {
        sceneCoordinator.handleViewerCommand(.actualSize)
    }

    func toggleGridFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleGrid)
    }

    func toggleFilmstripFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleFilmstrip)
    }

    func toggleInfoPanelFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleInfoPanel)
    }

    func toggleImmersiveChromeFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleImmersiveChrome)
    }

    func toggleSlideshowFromMenu() {
        sceneCoordinator.handleViewerCommand(.toggleSlideshow)
    }
}

private extension AppDelegate {
    static func startupURL() -> URL? {
        CommandLine.arguments
            .dropFirst()
            .map(URL.init(fileURLWithPath:))
            .first(where: { url in
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    return true
                }
                return ImageFormat.isSupported(url)
            })
    }
}
