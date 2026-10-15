import Foundation

final class FileScanner {
    func scan(folder: URL, currentURL: URL?, options: FolderScanOptions = .defaults) -> [ImageAsset] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]
        guard let urls = collectURLs(folder: folder, keys: keys, options: options) else {
            return currentURL.map { [ImageAsset(url: $0)] } ?? []
        }

        let assets = urls
            .filter { url in
                guard ImageFormat.isSupported(url, enabledExtensions: options.enabledExtensions) else { return false }
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
                return values?.isRegularFile == true
            }
            .map(ImageAsset.init(url:))
            .sorted(by: options.sortRule.compare)

        if let currentURL, !assets.contains(where: { $0.url == currentURL }) {
            return ([ImageAsset(url: currentURL)] + assets)
        }

        return assets
    }
}

private extension FileScanner {
    func collectURLs(folder: URL, keys: [URLResourceKey], options: FolderScanOptions) -> [URL]? {
        if options.recursive {
            return collectRecursiveURLs(folder: folder, keys: keys, options: options)
        }

        let directoryOptions: FileManager.DirectoryEnumerationOptions = options.includeHiddenFiles ? [] : [.skipsHiddenFiles]
        return try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: directoryOptions
        )
    }

    func collectRecursiveURLs(folder: URL, keys: [URLResourceKey], options: FolderScanOptions) -> [URL]? {
        guard FileManager.default.fileExists(atPath: folder.path) else { return nil }

        var urls: [URL] = []
        collectRecursiveURLs(
            folder: folder,
            keys: keys,
            options: options,
            currentDepth: 0,
            output: &urls
        )
        return urls
    }

    func collectRecursiveURLs(
        folder: URL,
        keys: [URLResourceKey],
        options: FolderScanOptions,
        currentDepth: Int,
        output: inout [URL]
    ) {
        let directoryOptions: FileManager.DirectoryEnumerationOptions = options.includeHiddenFiles ? [] : [.skipsHiddenFiles]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys + [.isDirectoryKey],
            options: directoryOptions
        ) else {
            return
        }

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            if values?.isHidden == true, !options.includeHiddenFiles {
                continue
            }

            output.append(child)

            if values?.isDirectory == true, currentDepth < options.maxDepth {
                collectRecursiveURLs(
                    folder: child,
                    keys: keys,
                    options: options,
                    currentDepth: currentDepth + 1,
                    output: &output
                )
            }
        }
    }
}

private extension SortRule {
    func compare(_ lhs: ImageAsset, _ rhs: ImageAsset) -> Bool {
        switch self {
        case .fileNameAscending:
            return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
        case .fileNameDescending:
            return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedDescending
        case .createdAtAscending:
            return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        case .createdAtDescending:
            return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        case .modifiedAtAscending:
            return (lhs.modifiedAt ?? .distantPast) < (rhs.modifiedAt ?? .distantPast)
        case .modifiedAtDescending:
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        case .fileSizeAscending:
            return lhs.fileSize < rhs.fileSize
        case .fileSizeDescending:
            return lhs.fileSize > rhs.fileSize
        }
    }
}
