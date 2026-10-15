import XCTest
@testable import Visora

final class PreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "VisoraTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testLoadReturnsDefaultsWhenNoSettingsWereSaved() {
        let store = PreferencesStore(userDefaults: defaults)

        XCTAssertEqual(store.load(), .defaults)
    }

    func testSaveAndLoadRoundTripSettings() {
        let store = PreferencesStore(userDefaults: defaults)
        let settings = AppSettings(
            language: .simplifiedChinese,
            autoHideChrome: false,
            startImmersiveChrome: true,
            cacheCountLimit: 24,
            sortRule: .fileNameDescending,
            slideshowInterval: 5,
            slideshowRandom: true,
            slideshowLoop: false,
            enableLongImageMode: false,
            includeHiddenFiles: true,
            recursiveBrowsing: true,
            maxRecursionDepth: 4,
            enabledFormatIDs: ["jpeg", "png"]
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testCacheLimitIsNormalizedOnSave() {
        let store = PreferencesStore(userDefaults: defaults)
        let settings = AppSettings(
            language: .english,
            autoHideChrome: true,
            startImmersiveChrome: false,
            cacheCountLimit: 400,
            sortRule: .fileSizeDescending,
            slideshowInterval: 0.2,
            slideshowRandom: false,
            slideshowLoop: true,
            enableLongImageMode: true,
            includeHiddenFiles: false,
            recursiveBrowsing: false,
            maxRecursionDepth: 20,
            enabledFormatIDs: ["jpeg", "unknown"]
        )

        store.save(settings)

        XCTAssertEqual(store.load().cacheCountLimit, 128)
        XCTAssertEqual(store.load().slideshowInterval, 1)
        XCTAssertEqual(store.load().maxRecursionDepth, 8)
        XCTAssertEqual(store.load().enabledFormatIDs, ["jpeg"])
    }

    func testLoadBackfillsSlideshowDefaultsForOlderSettings() throws {
        let legacyJSON = """
        {
          "autoHideChrome": false,
          "startImmersiveChrome": true,
          "cacheCountLimit": 12,
          "sortRule": "fileNameDescending"
        }
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "appSettings")

        let settings = PreferencesStore(userDefaults: defaults).load()

        XCTAssertFalse(settings.autoHideChrome)
        XCTAssertTrue(settings.startImmersiveChrome)
        XCTAssertEqual(settings.cacheCountLimit, 12)
        XCTAssertEqual(settings.sortRule, .fileNameDescending)
        XCTAssertEqual(settings.slideshowInterval, AppSettings.defaults.slideshowInterval)
        XCTAssertEqual(settings.slideshowRandom, AppSettings.defaults.slideshowRandom)
        XCTAssertEqual(settings.slideshowLoop, AppSettings.defaults.slideshowLoop)
        XCTAssertEqual(settings.language, AppSettings.defaults.language)
        XCTAssertEqual(settings.enableLongImageMode, AppSettings.defaults.enableLongImageMode)
        XCTAssertEqual(settings.includeHiddenFiles, AppSettings.defaults.includeHiddenFiles)
        XCTAssertEqual(settings.recursiveBrowsing, AppSettings.defaults.recursiveBrowsing)
        XCTAssertEqual(settings.maxRecursionDepth, AppSettings.defaults.maxRecursionDepth)
        XCTAssertEqual(settings.enabledFormatIDs, AppSettings.defaults.enabledFormatIDs)
    }
}
