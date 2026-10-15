import XCTest
@testable import Visora

final class ImageFormatTests: XCTestCase {
    func testSupportedExtensionsAreRecognizedCaseInsensitively() {
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.JPG")))
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/mockup.heic")))
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/preview.webp")))
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/banner.avif")))
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/vector.SVG")))
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/camera.CR3")))
        XCTAssertTrue(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.jxl")))
    }

    func testUnsupportedExtensionsAreRejected() {
        XCTAssertFalse(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/readme.md")))
        XCTAssertFalse(ImageFormat.isSupported(URL(fileURLWithPath: "/tmp/archive.zip")))
    }

    func testAnimatedFormatDetection() {
        XCTAssertTrue(ImageFormat.isAnimated(URL(fileURLWithPath: "/tmp/animation.GIF")))
        XCTAssertTrue(ImageFormat.isAnimated(URL(fileURLWithPath: "/tmp/sticker.apng")))
        XCTAssertTrue(ImageFormat.isAnimated(URL(fileURLWithPath: "/tmp/motion.webp")))
        XCTAssertFalse(ImageFormat.isAnimated(URL(fileURLWithPath: "/tmp/photo.png")))
    }
}
