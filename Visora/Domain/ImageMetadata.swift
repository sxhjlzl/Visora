import Foundation

struct ImageMetadata: Hashable {
    var fileName: String
    var filePath: String
    var fileSize: Int64
    var pixelWidth: Int?
    var pixelHeight: Int?
    var format: String
    var colorModel: String?
    var colorSpace: String?
    var capturedAt: Date?
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var iso: Int?
    var aperture: Double?
    var shutterSpeed: String?
    var exposureBias: Double?
    var focalLength: Double?
}

struct MetadataSection: Hashable {
    var id: String
    var title: String
    var rows: [MetadataRow]
}

struct MetadataRow: Hashable {
    var label: String
    var value: String
}

extension ImageMetadata {
    func sections(language: AppLanguage) -> [MetadataSection] {
        let localizer = Localizer(language: language)
        return [
            MetadataSection(
                id: "file",
                title: localizer.string(.file),
                rows: compactRows([
                    MetadataRow(label: localizer.string(.name), value: fileName),
                    MetadataRow(label: localizer.string(.path), value: filePath),
                    fileSize > 0 ? MetadataRow(label: localizer.string(.size), value: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) : nil,
                    MetadataRow(label: localizer.string(.format), value: format.uppercased())
                ])
            ),
            MetadataSection(
                id: "image",
                title: localizer.string(.image),
                rows: compactRows([
                    pixelSizeText.map { MetadataRow(label: localizer.string(.dimensions), value: $0) },
                    colorModel.map { MetadataRow(label: localizer.string(.colorModel), value: $0) },
                    colorSpace.map { MetadataRow(label: localizer.string(.colorSpace), value: $0) }
                ])
            ),
            MetadataSection(
                id: "camera",
                title: localizer.string(.camera),
                rows: compactRows([
                    cameraMake.map { MetadataRow(label: localizer.string(.make), value: $0) },
                    cameraModel.map { MetadataRow(label: localizer.string(.model), value: $0) },
                    lensModel.map { MetadataRow(label: localizer.string(.lens), value: $0) },
                    capturedAt.map { MetadataRow(label: localizer.string(.captured), value: Self.dateFormatter.string(from: $0)) },
                    iso.map { MetadataRow(label: "ISO", value: "\($0)") },
                    aperture.map { MetadataRow(label: "Aperture", value: String(format: "f/%.1f", $0)) },
                    shutterSpeed.map { MetadataRow(label: localizer.string(.shutter), value: $0) },
                    exposureBias.map { MetadataRow(label: localizer.string(.exposure), value: String(format: "%.2f EV", $0)) },
                    focalLength.map { MetadataRow(label: localizer.string(.focalLength), value: String(format: "%.0f mm", $0)) }
                ])
            )
        ].filter { !$0.rows.isEmpty }
    }

    func clipboardText(language: AppLanguage) -> String {
        sections(language: language)
            .map { section in
                let rows = section.rows.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
                return "[\(section.title)]\n\(rows)"
            }
            .joined(separator: "\n\n")
    }
}

private extension ImageMetadata {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var pixelSizeText: String? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return "\(pixelWidth) x \(pixelHeight)"
    }

    func compactRows(_ rows: [MetadataRow?]) -> [MetadataRow] {
        rows.compactMap { $0 }
    }
}
