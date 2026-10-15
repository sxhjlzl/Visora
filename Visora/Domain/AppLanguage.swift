import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case english
    case simplifiedChinese

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}
