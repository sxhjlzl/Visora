import XCTest
@testable import Visora

final class FileScannerTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let folder {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func testScanReturnsSupportedImagesInNaturalNameOrder() throws {
        try createFile(named: "b.png")
        try createFile(named: "a.jpg")
        try createFile(named: "notes.txt")
        try createFile(named: ".hidden.jpg")

        let assets = FileScanner().scan(folder: folder, currentURL: nil)

        XCTAssertEqual(assets.map(\.fileName), ["a.jpg", "b.png"])
    }

    func testScanSupportsDescendingNameSort() throws {
        try createFile(named: "b.png")
        try createFile(named: "a.jpg")

        let assets = FileScanner().scan(
            folder: folder,
            currentURL: nil,
            options: FolderScanOptions(
                sortRule: .fileNameDescending,
                includeHiddenFiles: false,
                recursive: false,
                maxDepth: 0,
                enabledExtensions: ImageFormatOption.allExtensions
            )
        )

        XCTAssertEqual(assets.map(\.fileName), ["b.png", "a.jpg"])
    }

    func testScanSupportsModifiedDateDescendingSort() throws {
        let olderURL = folder.appendingPathComponent("older.jpg")
        let newerURL = folder.appendingPathComponent("newer.jpg")
        try Data().write(to: olderURL)
        try Data().write(to: newerURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)],
            ofItemAtPath: olderURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 5_000)],
            ofItemAtPath: newerURL.path
        )

        let assets = FileScanner().scan(
            folder: folder,
            currentURL: nil,
            options: FolderScanOptions(
                sortRule: .modifiedAtDescending,
                includeHiddenFiles: false,
                recursive: false,
                maxDepth: 0,
                enabledExtensions: ImageFormatOption.allExtensions
            )
        )

        XCTAssertEqual(assets.map(\.fileName), ["newer.jpg", "older.jpg"])
    }

    func testScanRecursesToConfiguredDepth() throws {
        try createFile(named: "root.jpg")
        try createDirectory(named: "level1")
        try createFile(named: "level1/child.png")
        try createDirectory(named: "level1/level2")
        try createFile(named: "level1/level2/grandchild.png")

        let shallowAssets = FileScanner().scan(
            folder: folder,
            currentURL: nil,
            options: FolderScanOptions(
                sortRule: .fileNameAscending,
                includeHiddenFiles: false,
                recursive: true,
                maxDepth: 0,
                enabledExtensions: ImageFormatOption.allExtensions
            )
        )
        let deepAssets = FileScanner().scan(
            folder: folder,
            currentURL: nil,
            options: FolderScanOptions(
                sortRule: .fileNameAscending,
                includeHiddenFiles: false,
                recursive: true,
                maxDepth: 1,
                enabledExtensions: ImageFormatOption.allExtensions
            )
        )

        XCTAssertEqual(shallowAssets.map(\.fileName), ["root.jpg"])
        XCTAssertEqual(deepAssets.map(\.fileName), ["child.png", "root.jpg"])
    }

    func testScanCanIncludeHiddenFiles() throws {
        try createFile(named: "visible.jpg")
        try createFile(named: ".hidden.jpg")

        let assets = FileScanner().scan(
            folder: folder,
            currentURL: nil,
            options: FolderScanOptions(
                sortRule: .fileNameAscending,
                includeHiddenFiles: true,
                recursive: false,
                maxDepth: 0,
                enabledExtensions: ImageFormatOption.allExtensions
            )
        )

        XCTAssertEqual(assets.map(\.fileName), [".hidden.jpg", "visible.jpg"])
    }

    func testScanFiltersByEnabledExtensions() throws {
        try createFile(named: "photo.jpg")
        try createFile(named: "mockup.png")
        try createFile(named: "animation.gif")

        let assets = FileScanner().scan(
            folder: folder,
            currentURL: nil,
            options: FolderScanOptions(
                sortRule: .fileNameAscending,
                includeHiddenFiles: false,
                recursive: false,
                maxDepth: 0,
                enabledExtensions: ["png"]
            )
        )

        XCTAssertEqual(assets.map(\.fileName), ["mockup.png"])
    }

    func testScanIncludesCurrentURLWhenFolderAccessFails() {
        let currentURL = folder.appendingPathComponent("current.jpg")
        let missingFolder = folder.appendingPathComponent("missing")

        let assets = FileScanner().scan(folder: missingFolder, currentURL: currentURL)

        XCTAssertEqual(assets.map(\.url), [currentURL])
    }

    private func createFile(named name: String) throws {
        let url = folder.appendingPathComponent(name)
        try Data().write(to: url)
    }

    private func createDirectory(named name: String) throws {
        let url = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
