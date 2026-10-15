import XCTest
@testable import Visora

final class LocalizationTests: XCTestCase {
    func testLocalizerReturnsChineseStrings() {
        let localizer = Localizer(language: .simplifiedChinese)

        XCTAssertEqual(localizer.string(.preferences), "偏好设置...")
        XCTAssertEqual(localizer.string(.pinClipboard), "钉住剪贴板")
        XCTAssertEqual(localizer.loading("image.jpg"), "正在加载 image.jpg...")
        XCTAssertEqual(localizer.gridTitle(count: 3), "网格 - 3 张图片")
    }

    func testMetadataCanBeRenderedInChinese() {
        let metadata = ImageMetadata(
            fileName: "image.jpg",
            filePath: "/tmp/image.jpg",
            fileSize: 2_048,
            pixelWidth: 1_200,
            pixelHeight: 800,
            format: "jpg",
            colorModel: "RGB",
            colorSpace: "sRGB",
            capturedAt: nil,
            cameraMake: nil,
            cameraModel: "Acme X1",
            lensModel: nil,
            iso: nil,
            aperture: nil,
            shutterSpeed: nil,
            exposureBias: nil,
            focalLength: 35
        )

        let text = metadata.clipboardText(language: .simplifiedChinese)

        XCTAssertTrue(text.contains("[文件]"))
        XCTAssertTrue(text.contains("名称: image.jpg"))
        XCTAssertTrue(text.contains("[相机]"))
        XCTAssertTrue(text.contains("焦距: 35 mm"))
    }
}
