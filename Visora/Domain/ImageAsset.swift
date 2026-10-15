import Foundation

struct ImageAsset {
    let url: URL
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
    let createdAt: Date?
    let modifiedAt: Date?

    init(url: URL) {
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.fileSize = Int64(resourceValues?.fileSize ?? 0)
        self.createdAt = resourceValues?.creationDate
        self.modifiedAt = resourceValues?.contentModificationDate
    }
}
