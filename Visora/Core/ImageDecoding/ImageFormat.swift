import Foundation
import UniformTypeIdentifiers

enum ImageFormat {
    static let supportedExtensions: Set<String> = ImageFormatOption.allExtensions

    static let supportedContentTypes: [UTType] = {
        var types: [UTType] = [
            .jpeg,
            .png,
            .gif,
            .bmp,
            .tiff,
            .heic,
            .heif,
            .webP,
            .svg,
            .rawImage,
            .ico
        ]
        for ext in ["avif", "jxl", "apng", "dng", "cr2", "cr3", "nef", "arw", "orf", "raf", "rw2"] {
            if let utType = UTType(filenameExtension: ext), !types.contains(utType) {
                types.append(utType)
            }
        }
        return types
    }()

    static let animatedExtensions: Set<String> = ["gif", "apng", "webp"]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func isSupported(_ url: URL, enabledExtensions: Set<String>) -> Bool {
        enabledExtensions.contains(url.pathExtension.lowercased())
    }

    static func isAnimated(_ url: URL) -> Bool {
        animatedExtensions.contains(url.pathExtension.lowercased())
    }
}
