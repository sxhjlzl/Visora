import AppKit
import ImageIO

/// 专为胶卷条等小预览设计的异步缩略图加载器，独立于全尺寸图缓存，避免胶卷条把大图全部留在内存里
final class ThumbnailLoader {
    private let cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(
        label: "visora.thumbnail.loader",
        qos: .utility,
        attributes: .concurrent
    )
    private let maxPixelSize: Int

    init(maxPixelSize: Int = 192, cacheCountLimit: Int = 512) {
        self.maxPixelSize = maxPixelSize
        cache.countLimit = cacheCountLimit
    }

    func cachedThumbnail(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func invalidateThumbnail(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    /// 异步加载缩略图，完成后在主线程回调；同一个 URL 多次请求会共享同一份缓存结果
    func loadThumbnail(for url: URL, completion: @escaping (NSImage?) -> Void) {
        if let cached = cachedThumbnail(for: url) {
            completion(cached)
            return
        }

        queue.async { [weak self, maxPixelSize] in
            let thumbnail = Self.makeThumbnail(for: url, maxPixelSize: maxPixelSize)
            if let thumbnail {
                self?.cache.setObject(thumbnail, forKey: url as NSURL)
            }
            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }

    private static func makeThumbnail(for url: URL, maxPixelSize: Int) -> NSImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        if let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
                let size = NSSize(width: cgImage.width, height: cgImage.height)
                return NSImage(cgImage: cgImage, size: size)
            }
        }

        // SVG 等矢量格式回退使用 NSImage 解码
        return NSImage(contentsOf: url)
    }
}
