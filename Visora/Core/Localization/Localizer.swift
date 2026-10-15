import Foundation

struct Localizer: Equatable {
    enum Key: String {
        case about
        case aboutTagline
        case actionColumn
        case actualSize
        case all
        case application
        case autoHideChrome
        case camera
        case captured
        case chooseFileButton
        case chooseFolderButton
        case close
        case clearRecentItems
        case colorModel
        case colorSpace
        case copiedFile
        case copiedFilePath
        case copiedMetadata
        case copyFile
        case copyFilePath
        case copyMetadata
        case createdTime
        case dimensions
        case exposure
        case file
        case filmstrip
        case filmstripHidden
        case filmstripShown
        case fileMenu
        case fileNameAscending
        case fileNameDescending
        case fileSizeAscending
        case fileSizeDescending
        case fitToWindow
        case focalLength
        case folder
        case format
        case formats
        case general
        case grid
        case image
        case immersiveChrome
        case immersiveChromeOff
        case immersiveChromeOn
        case includeHiddenFiles
        case intervalSeconds
        case language
        case lens
        case lock
        case longImageMode
        case loopPlayback
        case make
        case maximumDepth
        case memoryCacheImages
        case metadata
        case minimize
        case model
        case modifiedTime
        case name
        case nextImage
        case noFolderImages
        case noImageToPin
        case noImages
        case noMetadataLoaded
        case noMetadataToCopy
        case none
        case openFolder
        case openImage
        case openLongImagesFromTop
        case openPrompt
        case openUnsupported
        case opacity
        case path
        case pinClipboard
        case pinClipboardEmpty
        case pinnedClipboardImageTitle
        case pinnedClipboardTextTitle
        case pinImage
        case pinnedImage
        case pinnedImageTitle
        case preferences
        case previousImage
        case quitVisora
        case quitWhenLastWindowClosed
        case randomPlayback
        case recentFilesAndFolders
        case revealInFinder
        case recursiveBrowsing
        case reset
        case rotateLeft
        case rotateRight
        case save
        case shortcutColumn
        case shortcuts
        case showFilmstrip
        case shutter
        case size
        case slideshow
        case slideshowNeedTwoImages
        case slideshowStarted
        case slideshowStopped
        case sort
        case supportedImagesNotFound
        case thumbnailSize
        case toggleFullScreen
        case trashImage
        case unlock
        case version
        case view
        case viewer
        case welcomeShortcutsHint
        case welcomeSubtitle
        case welcomeTitle
        case window
        case movedToTrash
        case fileOperationFailed
        case zoomIn
        case zoomOut
        case flipHorizontal
        case flipVertical
        case flippedHorizontal
        case flippedVertical
        case canvasBackground
        case backgroundDark
        case backgroundCheckerboard
        case backgroundLight
        case backgroundAmbient
        case pixelatedInterpolation
        case pixelatedOn
        case pixelatedOff
        case zoomLock
        case zoomLockOn
        case zoomLockOff
        case zoomLockedBadge
        case histogram
        case filterImages
        case filterPlaceholder
        case copyImageBitmap
        case copiedImageBitmap
        case recognizeText
        case recognizingText
        case recognizedTextCopied
        case noTextRecognized
        case createdTimeDescending
        case modifiedTimeDescending
        case savedImage
        case nothingToSave
        case ocrPanelTitle
        case copyAllText
    }

    let language: AppLanguage

    static let `default` = Localizer(language: AppSettings.defaults.language)

    func string(_ key: Key) -> String {
        switch language {
        case .english:
            return Self.english[key] ?? key.rawValue
        case .simplifiedChinese:
            return Self.simplifiedChinese[key] ?? Self.english[key] ?? key.rawValue
        }
    }
}

extension Localizer {
    func loading(_ fileName: String) -> String {
        switch language {
        case .english:
            return "Loading \(fileName)..."
        case .simplifiedChinese:
            return "正在加载 \(fileName)..."
        }
    }

    func unableToOpen(_ fileName: String) -> String {
        switch language {
        case .english:
            return "Unable to open \(fileName)"
        case .simplifiedChinese:
            return "无法打开 \(fileName)"
        }
    }

    func gridTitle(count: Int) -> String {
        guard count > 0 else { return string(.grid) }
        switch language {
        case .english:
            return "Grid - \(count) images"
        case .simplifiedChinese:
            return "网格 - \(count) 张图片"
        }
    }
}

private extension Localizer {
    // SwiftPM executable targets do not have a localized app bundle yet, so the MVP keeps UI copy in a typed table.
    static let english: [Key: String] = [
        .about: "About",
        .aboutTagline: "A native open-source image viewer for macOS.",
        .actionColumn: "Action",
        .actualSize: "Actual size",
        .all: "All",
        .application: "Application",
        .autoHideChrome: "Auto-hide toolbar and status",
        .camera: "Camera",
        .captured: "Captured",
        .chooseFileButton: "Choose File",
        .chooseFolderButton: "Open Folder",
        .close: "Close",
        .clearRecentItems: "Clear",
        .colorModel: "Color model",
        .colorSpace: "Color space",
        .copiedFile: "File copied",
        .copiedFilePath: "Path copied",
        .copiedMetadata: "Metadata copied",
        .copyFile: "Copy file",
        .copyFilePath: "Copy path",
        .copyMetadata: "Copy metadata",
        .createdTime: "Created time",
        .dimensions: "Dimensions",
        .exposure: "Exposure",
        .file: "File",
        .filmstrip: "Film strip",
        .filmstripHidden: "Film strip hidden",
        .filmstripShown: "Film strip shown",
        .fileMenu: "File",
        .fileNameAscending: "File name ascending",
        .fileNameDescending: "File name descending",
        .fileSizeAscending: "File size ascending",
        .fileSizeDescending: "File size descending",
        .fitToWindow: "Fit to window",
        .focalLength: "Focal length",
        .folder: "Source",
        .format: "Format",
        .formats: "Formats",
        .general: "General",
        .grid: "Grid",
        .image: "Image",
        .immersiveChrome: "Immersive chrome",
        .immersiveChromeOff: "Immersive chrome off",
        .immersiveChromeOn: "Immersive chrome on",
        .includeHiddenFiles: "Include hidden files",
        .intervalSeconds: "Interval seconds",
        .language: "Language",
        .lens: "Lens",
        .lock: "Lock",
        .longImageMode: "Long",
        .loopPlayback: "Loop playback",
        .make: "Make",
        .maximumDepth: "Maximum depth",
        .memoryCacheImages: "Memory cache images",
        .metadata: "Metadata",
        .minimize: "Minimize",
        .model: "Model",
        .modifiedTime: "Modified time",
        .name: "Name",
        .nextImage: "Next image",
        .noFolderImages: "No folder images to show",
        .noImageToPin: "No image to pin",
        .noImages: "No images",
        .noMetadataLoaded: "No metadata loaded",
        .noMetadataToCopy: "No metadata to copy",
        .none: "None",
        .openFolder: "Open Folder...",
        .openImage: "Open Image...",
        .openLongImagesFromTop: "Open long images from top",
        .openPrompt: "Open an image with Cmd+O",
        .openUnsupported: "This format is not supported yet.",
        .opacity: "Opacity",
        .path: "Path",
        .pinClipboard: "Pin Clipboard",
        .pinClipboardEmpty: "Clipboard has no image or text to pin.",
        .pinnedClipboardImageTitle: "Pinned Clipboard Image",
        .pinnedClipboardTextTitle: "Pinned Clipboard Text",
        .pinImage: "Pin image",
        .pinnedImage: "Pinned image",
        .pinnedImageTitle: "Pinned Image",
        .preferences: "Preferences...",
        .previousImage: "Previous image",
        .quitVisora: "Quit Visora",
        .quitWhenLastWindowClosed: "Quit when the last window is closed",
        .randomPlayback: "Random playback",
        .recentFilesAndFolders: "Recent",
        .revealInFinder: "Reveal in Finder",
        .recursiveBrowsing: "Browse subfolders recursively",
        .reset: "Reset",
        .rotateLeft: "Rotate left",
        .rotateRight: "Rotate right",
        .save: "Save",
        .shortcutColumn: "Shortcut",
        .shortcuts: "Shortcuts",
        .showFilmstrip: "Show film strip at the bottom",
        .shutter: "Shutter",
        .size: "Size",
        .slideshow: "Slideshow",
        .slideshowNeedTwoImages: "Need at least two images for slideshow",
        .slideshowStarted: "Slideshow started",
        .slideshowStopped: "Slideshow stopped",
        .sort: "Sort",
        .supportedImagesNotFound: "No supported images found in this folder.",
        .thumbnailSize: "Thumbnail size",
        .toggleFullScreen: "Toggle Full Screen",
        .trashImage: "Move to Trash",
        .unlock: "Unlock",
        .version: "Version",
        .view: "View",
        .viewer: "Browse",
        .welcomeShortcutsHint: "⌘O Open Image    ⌘⇧O Open Folder    ⌘⇧V Pin Clipboard",
        .welcomeSubtitle: "Supports JPG, PNG, GIF, PSD, WEBP, RAW, SVG and more.",
        .welcomeTitle: "Drop a file here",
        .window: "Window",
        .movedToTrash: "Moved to Trash",
        .fileOperationFailed: "File operation failed.",
        .zoomIn: "Zoom in",
        .zoomOut: "Zoom out",
        .flipHorizontal: "Flip horizontal",
        .flipVertical: "Flip vertical",
        .flippedHorizontal: "Flipped horizontally",
        .flippedVertical: "Flipped vertically",
        .canvasBackground: "Switch background",
        .backgroundDark: "Background: Dark",
        .backgroundCheckerboard: "Background: Checkerboard",
        .backgroundLight: "Background: Light",
        .backgroundAmbient: "Background: Ambient Blur",
        .pixelatedInterpolation: "Pixelated zoom",
        .pixelatedOn: "Pixelated zoom on",
        .pixelatedOff: "Smooth zoom on",
        .zoomLock: "Lock zoom",
        .zoomLockOn: "Zoom lock on",
        .zoomLockOff: "Zoom lock off",
        .zoomLockedBadge: "Zoom Locked",
        .histogram: "Histogram",
        .filterImages: "Filter Images...",
        .filterPlaceholder: "Filter by file name...",
        .copyImageBitmap: "Copy Image",
        .copiedImageBitmap: "Image copied",
        .recognizeText: "Extract Text (OCR)",
        .recognizingText: "Extracting text...",
        .recognizedTextCopied: "OCR text copied",
        .noTextRecognized: "No text found in image",
        .createdTimeDescending: "Created time descending",
        .modifiedTimeDescending: "Modified time descending",
        .savedImage: "Saved changes to image",
        .nothingToSave: "No rotation or flip changes to save",
        .ocrPanelTitle: "Recognized Text",
        .copyAllText: "Copy All"
    ]

    static let simplifiedChinese: [Key: String] = [
        .about: "关于",
        .aboutTagline: "面向 macOS 的原生开源看图工具。",
        .actionColumn: "操作",
        .actualSize: "实际尺寸",
        .all: "全选",
        .application: "应用程序",
        .autoHideChrome: "自动隐藏工具栏和状态栏",
        .camera: "相机",
        .captured: "拍摄时间",
        .chooseFileButton: "选择文件打开",
        .chooseFolderButton: "打开文件夹",
        .close: "关闭",
        .clearRecentItems: "清空",
        .colorModel: "颜色模型",
        .colorSpace: "色彩空间",
        .copiedFile: "文件已复制",
        .copiedFilePath: "路径已复制",
        .copiedMetadata: "元数据已复制",
        .copyFile: "复制文件",
        .copyFilePath: "复制路径",
        .copyMetadata: "复制元数据",
        .createdTime: "创建时间",
        .dimensions: "尺寸",
        .exposure: "曝光补偿",
        .file: "文件",
        .filmstrip: "胶卷条",
        .filmstripHidden: "已隐藏胶卷条",
        .filmstripShown: "已显示胶卷条",
        .fileMenu: "文件",
        .fileNameAscending: "文件名升序",
        .fileNameDescending: "文件名降序",
        .fileSizeAscending: "文件大小升序",
        .fileSizeDescending: "文件大小降序",
        .fitToWindow: "适应窗口",
        .focalLength: "焦距",
        .folder: "来源",
        .format: "格式",
        .formats: "格式",
        .general: "通用",
        .grid: "网格",
        .image: "图像",
        .immersiveChrome: "沉浸式窗口",
        .immersiveChromeOff: "沉浸式窗口已关闭",
        .immersiveChromeOn: "沉浸式窗口已开启",
        .includeHiddenFiles: "包含隐藏文件",
        .intervalSeconds: "间隔秒数",
        .language: "语言",
        .lens: "镜头",
        .lock: "锁定",
        .longImageMode: "长图",
        .loopPlayback: "循环播放",
        .make: "厂商",
        .maximumDepth: "最大深度",
        .memoryCacheImages: "内存缓存图片数",
        .metadata: "元数据",
        .minimize: "最小化",
        .model: "型号",
        .modifiedTime: "修改时间",
        .name: "名称",
        .nextImage: "下一张",
        .noFolderImages: "没有可显示的文件夹图片",
        .noImageToPin: "没有可钉住的图片",
        .noImages: "没有图片",
        .noMetadataLoaded: "尚未加载元数据",
        .noMetadataToCopy: "没有可复制的元数据",
        .none: "清空",
        .openFolder: "打开文件夹...",
        .openImage: "打开图片...",
        .openLongImagesFromTop: "从顶部打开长图",
        .openPrompt: "使用 Cmd+O 打开图片",
        .openUnsupported: "暂不支持这种格式。",
        .opacity: "透明度",
        .path: "路径",
        .pinClipboard: "钉住剪贴板",
        .pinClipboardEmpty: "剪贴板中没有可钉住的图片或文本。",
        .pinnedClipboardImageTitle: "钉住的剪贴板图片",
        .pinnedClipboardTextTitle: "钉住的剪贴板文本",
        .pinImage: "钉住图片",
        .pinnedImage: "图片已钉住",
        .pinnedImageTitle: "钉住的图片",
        .preferences: "偏好设置...",
        .previousImage: "上一张",
        .quitVisora: "退出 Visora",
        .quitWhenLastWindowClosed: "所有窗口关闭时退出",
        .randomPlayback: "随机播放",
        .recentFilesAndFolders: "最近打开",
        .revealInFinder: "在 Finder 中显示",
        .recursiveBrowsing: "递归浏览子文件夹",
        .reset: "重置",
        .rotateLeft: "向左旋转",
        .rotateRight: "向右旋转",
        .save: "保存",
        .shortcutColumn: "快捷键",
        .shortcuts: "快捷键",
        .showFilmstrip: "底部显示胶卷条",
        .shutter: "快门",
        .size: "大小",
        .slideshow: "幻灯片",
        .slideshowNeedTwoImages: "幻灯片至少需要两张图片",
        .slideshowStarted: "幻灯片已开始",
        .slideshowStopped: "幻灯片已停止",
        .sort: "排序",
        .supportedImagesNotFound: "这个文件夹中没有支持的图片。",
        .thumbnailSize: "缩略图尺寸",
        .toggleFullScreen: "切换全屏",
        .trashImage: "移到废纸篓",
        .unlock: "解锁",
        .version: "版本",
        .view: "显示",
        .viewer: "浏览",
        .welcomeShortcutsHint: "⌘O 打开图片    ⌘⇧O 打开文件夹    ⌘⇧V 钉住剪贴板",
        .welcomeSubtitle: "支持 JPG、PNG、GIF、PSD、WEBP、RAW、SVG 等 30 多种格式。",
        .welcomeTitle: "拖放文件到这里",
        .window: "窗口",
        .movedToTrash: "已移到废纸篓",
        .fileOperationFailed: "文件操作失败。",
        .zoomIn: "放大",
        .zoomOut: "缩小",
        .flipHorizontal: "水平翻转",
        .flipVertical: "垂直翻转",
        .flippedHorizontal: "已水平翻转",
        .flippedVertical: "已垂直翻转",
        .canvasBackground: "切换画布背景",
        .backgroundDark: "画布背景：深色",
        .backgroundCheckerboard: "画布背景：棋盘格",
        .backgroundLight: "画布背景：浅色",
        .backgroundAmbient: "画布背景：环境光晕",
        .pixelatedInterpolation: "像素级锐利缩放",
        .pixelatedOn: "像素级缩放已开启",
        .pixelatedOff: "平滑缩放已恢复",
        .zoomLock: "跨图锁定缩放",
        .zoomLockOn: "已锁定跨图缩放",
        .zoomLockOff: "已解除缩放锁定",
        .zoomLockedBadge: "锁定缩放",
        .histogram: "直方图",
        .filterImages: "过滤图片...",
        .filterPlaceholder: "按文件名过滤...",
        .copyImageBitmap: "复制图像内容",
        .copiedImageBitmap: "图像已复制",
        .recognizeText: "提取图中文字 (OCR)",
        .recognizingText: "正在识别文字...",
        .recognizedTextCopied: "识别文字已复制",
        .noTextRecognized: "未在图片中识别到文字",
        .createdTimeDescending: "创建时间降序",
        .modifiedTimeDescending: "修改时间降序",
        .savedImage: "修改已保存到原图",
        .nothingToSave: "当前图片没有旋转或翻转修改",
        .ocrPanelTitle: "识别到的文字",
        .copyAllText: "复制全部"
    ]
}
