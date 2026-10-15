import Foundation

struct AppSettings: Codable, Equatable {
    var language: AppLanguage
    var autoHideChrome: Bool
    var startImmersiveChrome: Bool
    var quitWhenLastWindowClosed: Bool
    var showFilmstrip: Bool
    var cacheCountLimit: Int
    var sortRule: SortRule
    var slideshowInterval: Double
    var slideshowRandom: Bool
    var slideshowLoop: Bool
    var enableLongImageMode: Bool
    var includeHiddenFiles: Bool
    var recursiveBrowsing: Bool
    var maxRecursionDepth: Int
    var enabledFormatIDs: Set<String>

    static let defaults = AppSettings(
        language: .english,
        autoHideChrome: true,
        startImmersiveChrome: false,
        cacheCountLimit: 16,
        sortRule: .fileNameAscending,
        slideshowInterval: 3,
        slideshowRandom: false,
        slideshowLoop: true,
        enableLongImageMode: true,
        includeHiddenFiles: false,
        recursiveBrowsing: false,
        maxRecursionDepth: 2,
        enabledFormatIDs: ImageFormatOption.defaultEnabledIDs
    )

    var normalized: AppSettings {
        var copy = self
        copy.cacheCountLimit = min(max(copy.cacheCountLimit, 2), 128)
        copy.slideshowInterval = min(max(copy.slideshowInterval, 1), 60)
        copy.maxRecursionDepth = min(max(copy.maxRecursionDepth, 0), 8)
        copy.enabledFormatIDs = copy.enabledFormatIDs.intersection(ImageFormatOption.defaultEnabledIDs)
        if copy.enabledFormatIDs.isEmpty {
            copy.enabledFormatIDs = ImageFormatOption.defaultEnabledIDs
        }
        return copy
    }

    var folderScanOptions: FolderScanOptions {
        FolderScanOptions(
            sortRule: sortRule,
            includeHiddenFiles: includeHiddenFiles,
            recursive: recursiveBrowsing,
            maxDepth: maxRecursionDepth,
            enabledExtensions: ImageFormatOption.enabledExtensions(for: enabledFormatIDs)
        )
    }

    // 保留显式 init，并给新字段提供默认值，方便单元测试和兼容旧调用方
    init(
        language: AppLanguage,
        autoHideChrome: Bool,
        startImmersiveChrome: Bool,
        cacheCountLimit: Int,
        sortRule: SortRule,
        slideshowInterval: Double,
        slideshowRandom: Bool,
        slideshowLoop: Bool,
        enableLongImageMode: Bool,
        includeHiddenFiles: Bool,
        recursiveBrowsing: Bool,
        maxRecursionDepth: Int,
        enabledFormatIDs: Set<String>,
        quitWhenLastWindowClosed: Bool = true,
        showFilmstrip: Bool = true
    ) {
        self.language = language
        self.autoHideChrome = autoHideChrome
        self.startImmersiveChrome = startImmersiveChrome
        self.quitWhenLastWindowClosed = quitWhenLastWindowClosed
        self.showFilmstrip = showFilmstrip
        self.cacheCountLimit = cacheCountLimit
        self.sortRule = sortRule
        self.slideshowInterval = slideshowInterval
        self.slideshowRandom = slideshowRandom
        self.slideshowLoop = slideshowLoop
        self.enableLongImageMode = enableLongImageMode
        self.includeHiddenFiles = includeHiddenFiles
        self.recursiveBrowsing = recursiveBrowsing
        self.maxRecursionDepth = maxRecursionDepth
        self.enabledFormatIDs = enabledFormatIDs
    }

    init(from decoder: Decoder) throws {
        let defaults = AppSettings.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Keep settings saved before multilingual support readable without forcing users to reset preferences.
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? defaults.language
        autoHideChrome = try container.decodeIfPresent(Bool.self, forKey: .autoHideChrome) ?? defaults.autoHideChrome
        startImmersiveChrome = try container.decodeIfPresent(Bool.self, forKey: .startImmersiveChrome) ?? defaults.startImmersiveChrome
        quitWhenLastWindowClosed = try container.decodeIfPresent(Bool.self, forKey: .quitWhenLastWindowClosed) ?? defaults.quitWhenLastWindowClosed
        showFilmstrip = try container.decodeIfPresent(Bool.self, forKey: .showFilmstrip) ?? defaults.showFilmstrip
        cacheCountLimit = try container.decodeIfPresent(Int.self, forKey: .cacheCountLimit) ?? defaults.cacheCountLimit
        sortRule = try container.decodeIfPresent(SortRule.self, forKey: .sortRule) ?? defaults.sortRule
        slideshowInterval = try container.decodeIfPresent(Double.self, forKey: .slideshowInterval) ?? defaults.slideshowInterval
        slideshowRandom = try container.decodeIfPresent(Bool.self, forKey: .slideshowRandom) ?? defaults.slideshowRandom
        slideshowLoop = try container.decodeIfPresent(Bool.self, forKey: .slideshowLoop) ?? defaults.slideshowLoop
        enableLongImageMode = try container.decodeIfPresent(Bool.self, forKey: .enableLongImageMode) ?? defaults.enableLongImageMode
        includeHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .includeHiddenFiles) ?? defaults.includeHiddenFiles
        recursiveBrowsing = try container.decodeIfPresent(Bool.self, forKey: .recursiveBrowsing) ?? defaults.recursiveBrowsing
        maxRecursionDepth = try container.decodeIfPresent(Int.self, forKey: .maxRecursionDepth) ?? defaults.maxRecursionDepth
        enabledFormatIDs = try container.decodeIfPresent(Set<String>.self, forKey: .enabledFormatIDs) ?? defaults.enabledFormatIDs
    }
}
