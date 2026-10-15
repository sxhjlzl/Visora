import Foundation

enum SortRule: String, Codable, CaseIterable {
    case fileNameAscending
    case fileNameDescending
    case createdAtAscending
    case createdAtDescending
    case modifiedAtAscending
    case modifiedAtDescending
    case fileSizeAscending
    case fileSizeDescending

    func displayName(language: AppLanguage) -> String {
        let localizer = Localizer(language: language)
        switch self {
        case .fileNameAscending:
            return localizer.string(.fileNameAscending)
        case .fileNameDescending:
            return localizer.string(.fileNameDescending)
        case .createdAtAscending:
            return localizer.string(.createdTime)
        case .createdAtDescending:
            return localizer.string(.createdTimeDescending)
        case .modifiedAtAscending:
            return localizer.string(.modifiedTime)
        case .modifiedAtDescending:
            return localizer.string(.modifiedTimeDescending)
        case .fileSizeAscending:
            return localizer.string(.fileSizeAscending)
        case .fileSizeDescending:
            return localizer.string(.fileSizeDescending)
        }
    }
}
