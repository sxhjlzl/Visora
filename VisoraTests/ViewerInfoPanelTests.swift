import AppKit
import XCTest
@testable import Visora

final class ViewerInfoPanelTests: XCTestCase {
    func testWindowStartsAtDefaultSizeAndBottomToolbarFitsAllButtons() throws {
        let windowController = ViewerWindowController(
            decoder: ImageIODecoder(),
            imageCache: ImageMemoryCache(),
            thumbnailLoader: ThumbnailLoader()
        )
        let window = try XCTUnwrap(windowController.window)
        let contentView = try XCTUnwrap(window.contentView)
        contentView.layoutSubtreeIfNeeded()

        XCTAssertGreaterThanOrEqual(contentView.frame.width, 1280)
        XCTAssertGreaterThanOrEqual(contentView.frame.height, 840)

        let toolbar = try XCTUnwrap(findView(identifier: "bottomToolbar", in: contentView))
        XCTAssertGreaterThanOrEqual(toolbar.frame.width, 520)
        XCTAssertLessThanOrEqual(toolbar.frame.width, contentView.frame.width - 32)
    }

    func testInfoPanelBecomesVisibleWithNonzeroHeight() throws {
        let controller = ViewerViewController(
            decoder: ImageIODecoder(),
            imageCache: ImageMemoryCache(),
            thumbnailLoader: ThumbnailLoader()
        )
        controller.loadView()
        controller.view.frame = NSRect(x: 0, y: 0, width: 1080, height: 760)

        let url = URL(fileURLWithPath: "/tmp/image.jpg")
        controller.setSession(
            assets: [ImageAsset(url: url)],
            currentURL: url,
            decodedImage: NSImage(size: NSSize(width: 1200, height: 800)),
            metadata: ImageMetadata(
                fileName: "image.jpg",
                filePath: url.path,
                fileSize: 2048,
                pixelWidth: 1200,
                pixelHeight: 800,
                format: "jpg"
            )
        )

        controller.perform(.toggleInfoPanel)
        controller.view.layoutSubtreeIfNeeded()

        let panel = try XCTUnwrap(findView(identifier: "imageInfoPanel", in: controller.view))
        XCTAssertFalse(panel.isHidden)
        XCTAssertGreaterThan(panel.frame.height, 0)
        XCTAssertNotNil(findView(identifier: "imageHistogramView", in: panel))
    }

    func testFilterBarTogglesAndFiltersAssets() throws {
        let controller = ViewerViewController(
            decoder: ImageIODecoder(),
            imageCache: ImageMemoryCache(),
            thumbnailLoader: ThumbnailLoader()
        )
        controller.loadView()
        controller.view.frame = NSRect(x: 0, y: 0, width: 1080, height: 760)

        let url1 = URL(fileURLWithPath: "/tmp/sunset_01.jpg")
        let url2 = URL(fileURLWithPath: "/tmp/portrait_02.jpg")
        controller.setSession(
            assets: [ImageAsset(url: url1), ImageAsset(url: url2)],
            currentURL: url1,
            decodedImage: NSImage(size: NSSize(width: 800, height: 600)),
            metadata: ImageMetadata(
                fileName: "sunset_01.jpg",
                filePath: url1.path,
                fileSize: 1024,
                pixelWidth: 800,
                pixelHeight: 600,
                format: "jpg"
            )
        )

        let filterBar = try XCTUnwrap(findView(identifier: "imageFilterBar", in: controller.view))
        XCTAssertTrue(filterBar.isHidden)

        controller.perform(.toggleFilterBar)
        XCTAssertFalse(filterBar.isHidden)
    }

    func testCanvasCommandsCycleBackgroundAndFlipAndLockZoom() {
        let canvas = ImageCanvasView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let image1 = NSImage(size: NSSize(width: 400, height: 300))
        let image2 = NSImage(size: NSSize(width: 400, height: 300))

        canvas.setImage(image1)
        XCTAssertEqual(canvas.backgroundStyle, .dark)
        canvas.backgroundStyle = canvas.backgroundStyle.next
        XCTAssertEqual(canvas.backgroundStyle, .checkerboard)
        canvas.backgroundStyle = canvas.backgroundStyle.next
        XCTAssertEqual(canvas.backgroundStyle, .light)
        canvas.backgroundStyle = canvas.backgroundStyle.next
        XCTAssertEqual(canvas.backgroundStyle, .ambient)
        canvas.backgroundStyle = canvas.backgroundStyle.next
        XCTAssertEqual(canvas.backgroundStyle, .dark)

        canvas.setFlip(horizontal: true, vertical: false)
        XCTAssertTrue(canvas.isFlippedHorizontally)
        XCTAssertFalse(canvas.isFlippedVertically)

        canvas.isZoomLocked = true
        canvas.zoom(by: 2.0)
        let lockedZoom = canvas.zoomScale
        canvas.setImage(image2)
        XCTAssertEqual(canvas.zoomScale, lockedZoom, accuracy: 0.001)
    }

    func testSaveTransformedImageWritesRotatedDimensionsToFile() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("visora_transform_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let sourceImage = NSImage(size: NSSize(width: 120, height: 60))
        sourceImage.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 120, height: 60).fill()
        sourceImage.unlockFocus()

        let tiffData = try XCTUnwrap(sourceImage.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: tempURL)

        let decoder = ImageIODecoder()
        let initial = try decoder.decode(tempURL)
        let saved = try decoder.saveTransformedImage(
            initial.image,
            to: tempURL,
            rotationQuarterTurns: 1,
            flipHorizontal: false,
            flipVertical: false
        )

        XCTAssertEqual(saved.metadata.pixelWidth, initial.metadata.pixelHeight)
        XCTAssertEqual(saved.metadata.pixelHeight, initial.metadata.pixelWidth)
    }

    func testOCRPanelBecomesVisibleOnRecognizeTextCommand() throws {
        let controller = ViewerViewController(
            decoder: ImageIODecoder(),
            imageCache: ImageMemoryCache(),
            thumbnailLoader: ThumbnailLoader()
        )
        controller.loadView()
        controller.view.frame = NSRect(x: 0, y: 0, width: 1080, height: 760)

        let url = URL(fileURLWithPath: "/tmp/image.jpg")
        controller.setSession(
            assets: [ImageAsset(url: url)],
            currentURL: url,
            decodedImage: NSImage(size: NSSize(width: 800, height: 600)),
            metadata: ImageMetadata(
                fileName: "image.jpg",
                filePath: url.path,
                fileSize: 1024,
                pixelWidth: 800,
                pixelHeight: 600,
                format: "jpg"
            )
        )

        let ocrPanel = try XCTUnwrap(findView(identifier: "imageOCRPanel", in: controller.view))
        XCTAssertTrue(ocrPanel.isHidden)

        controller.perform(.recognizeText)
        controller.view.layoutSubtreeIfNeeded()

        XCTAssertFalse(ocrPanel.isHidden)
        XCTAssertGreaterThan(ocrPanel.frame.height, 0)
    }

    private func findView(identifier: String, in root: NSView) -> NSView? {
        if root.identifier?.rawValue == identifier {
            return root
        }

        for subview in root.subviews {
            if let match = findView(identifier: identifier, in: subview) {
                return match
            }
        }
        return nil
    }
}
