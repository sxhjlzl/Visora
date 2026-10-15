import Foundation

struct RecentItem: Codable, Equatable, Hashable {
    let url: URL
    let kind: Kind
    let lastOpenedAt: Date

    enum Kind: String, Codable {
        case file
        case folder
    }

    var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}
