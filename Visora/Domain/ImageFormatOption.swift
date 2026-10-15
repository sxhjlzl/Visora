struct ImageFormatOption: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let extensions: [String]

    static let all: [ImageFormatOption] = [
        ImageFormatOption(id: "jpeg", displayName: "JPEG", extensions: ["jpg", "jpeg"]),
        ImageFormatOption(id: "png", displayName: "PNG / APNG", extensions: ["png", "apng"]),
        ImageFormatOption(id: "gif", displayName: "GIF", extensions: ["gif"]),
        ImageFormatOption(id: "bmp", displayName: "BMP", extensions: ["bmp"]),
        ImageFormatOption(id: "tiff", displayName: "TIFF", extensions: ["tif", "tiff"]),
        ImageFormatOption(id: "webp", displayName: "WebP", extensions: ["webp"]),
        ImageFormatOption(id: "heic", displayName: "HEIC / HEIF", extensions: ["heic", "heif"]),
        ImageFormatOption(id: "avif", displayName: "AVIF", extensions: ["avif"]),
        ImageFormatOption(id: "jxl", displayName: "JPEG XL", extensions: ["jxl"]),
        ImageFormatOption(id: "svg", displayName: "SVG", extensions: ["svg"]),
        ImageFormatOption(id: "raw", displayName: "RAW", extensions: ["dng", "cr2", "cr3", "nef", "arw", "orf", "raf", "rw2"]),
        ImageFormatOption(id: "ico", displayName: "ICO", extensions: ["ico"])
    ]

    static let defaultEnabledIDs: Set<String> = Set(all.map(\.id))

    static var allExtensions: Set<String> {
        Set(all.flatMap(\.extensions))
    }

    static func enabledExtensions(for enabledIDs: Set<String>) -> Set<String> {
        Set(all.filter { enabledIDs.contains($0.id) }.flatMap(\.extensions))
    }
}
