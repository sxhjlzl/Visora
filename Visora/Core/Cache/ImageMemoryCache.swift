import Foundation

final class ImageMemoryCache {
    private final class Box {
        let result: ImageDecodeResult

        init(result: ImageDecodeResult) {
            self.result = result
        }
    }

    private let cache = NSCache<NSURL, Box>()

    init(countLimit: Int = 16, totalCostLimit: Int = 512 * 1024 * 1024) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func updateCountLimit(_ countLimit: Int) {
        cache.countLimit = min(max(countLimit, 2), 128)
    }

    func result(for url: URL) -> ImageDecodeResult? {
        cache.object(forKey: url as NSURL)?.result
    }

    func store(_ result: ImageDecodeResult, for url: URL) {
        let pixelWidth = max(result.metadata.pixelWidth ?? Int(result.image.size.width), 1)
        let pixelHeight = max(result.metadata.pixelHeight ?? Int(result.image.size.height), 1)
        let frameCount = max(result.animatedImage?.frames.count ?? 1, 1)
        let estimatedBytes = pixelWidth * pixelHeight * 4 * frameCount
        cache.setObject(Box(result: result), forKey: url as NSURL, cost: estimatedBytes)
    }

    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}
