struct FolderScanOptions: Equatable {
    var sortRule: SortRule
    var includeHiddenFiles: Bool
    var recursive: Bool
    var maxDepth: Int
    var enabledExtensions: Set<String>

    static let defaults = FolderScanOptions(
        sortRule: .fileNameAscending,
        includeHiddenFiles: false,
        recursive: false,
        maxDepth: 2,
        enabledExtensions: ImageFormatOption.allExtensions
    )
}
