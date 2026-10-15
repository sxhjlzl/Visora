import XCTest
@testable import Visora

final class ImageMetadataTests: XCTestCase {
    func testSectionsGroupMetadataByFileImageAndCamera() {
        let metadata = makeMetadata()

        let sections = metadata.sections(language: .english)

        XCTAssertEqual(sections.map(\.id), ["file", "image", "camera"])
        XCTAssertEqual(sections.map(\.title), ["File", "Image", "Camera"])
        XCTAssertEqual(sections[0].rows.map(\.label), ["Name", "Path", "Size", "Format"])
        XCTAssertTrue(sections[1].rows.contains(MetadataRow(label: "Dimensions", value: "1200 x 800")))
        XCTAssertTrue(sections[2].rows.contains(MetadataRow(label: "ISO", value: "400")))
    }

    func testClipboardTextIncludesSectionHeadersAndRows() {
        let text = makeMetadata().clipboardText(language: .english)

        XCTAssertTrue(text.contains("[File]"))
        XCTAssertTrue(text.contains("Name: image.jpg"))
        XCTAssertTrue(text.contains("[Camera]"))
        XCTAssertTrue(text.contains("Focal length: 35 mm"))
    }

    private func makeMetadata() -> ImageMetadata {
        ImageMetadata(
            fileName: "image.jpg",
            filePath: "/tmp/image.jpg",
            fileSize: 2048,
            pixelWidth: 1200,
            pixelHeight: 800,
            format: "jpg",
            colorModel: "RGB",
            colorSpace: "sRGB",
            capturedAt: nil,
            cameraMake: "Acme",
            cameraModel: "Acme X1",
            lensModel: "35mm",
            iso: 400,
            aperture: 2.8,
            shutterSpeed: "0.01s",
            exposureBias: 0,
            focalLength: 35
        )
    }
}
