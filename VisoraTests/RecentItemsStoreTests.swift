import XCTest
@testable import Visora

final class RecentItemsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "VisoraTests.RecentItems.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testRecordAddsNewestItemFirstAndDeduplicatesURL() {
        let store = RecentItemsStore(userDefaults: defaults, maximumItemCount: 3)
        let fileURL = URL(fileURLWithPath: "/tmp/a.jpg")
        let folderURL = URL(fileURLWithPath: "/tmp/folder", isDirectory: true)

        _ = store.record(url: fileURL, kind: .file)
        _ = store.record(url: folderURL, kind: .folder)
        let items = store.record(url: fileURL, kind: .file)

        XCTAssertEqual(items.map(\.url), [fileURL, folderURL])
        XCTAssertEqual(items.map(\.kind), [.file, .folder])
    }

    func testRecordRespectsMaximumItemCount() {
        let store = RecentItemsStore(userDefaults: defaults, maximumItemCount: 2)

        _ = store.record(url: URL(fileURLWithPath: "/tmp/a.jpg"), kind: .file)
        _ = store.record(url: URL(fileURLWithPath: "/tmp/b.jpg"), kind: .file)
        let items = store.record(url: URL(fileURLWithPath: "/tmp/c.jpg"), kind: .file)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.displayName), ["c.jpg", "b.jpg"])
    }

    func testClearRemovesPersistedItems() {
        let store = RecentItemsStore(userDefaults: defaults)
        _ = store.record(url: URL(fileURLWithPath: "/tmp/a.jpg"), kind: .file)

        store.clear()

        XCTAssertEqual(store.load(), [])
    }

    func testRemoveDeletesOnlyMatchingURL() {
        let store = RecentItemsStore(userDefaults: defaults)
        let urlA = URL(fileURLWithPath: "/tmp/a.jpg")
        let urlB = URL(fileURLWithPath: "/tmp/b.jpg")
        _ = store.record(url: urlA, kind: .file)
        _ = store.record(url: urlB, kind: .file)

        let remaining = store.remove(url: urlA)

        XCTAssertEqual(remaining.map(\.url), [urlB])
        XCTAssertEqual(store.load().map(\.url), [urlB])
    }
}
