import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ImageDecodeResult {
    let image: NSImage
    let metadata: ImageMetadata
    let animatedImage: AnimatedImage?
}

enum ImageDecodeError: Error {
    case unsupportedFormat
    case decodeFailed
}

struct AnimatedImage {
    let frames: [NSImage]
    let durations: [TimeInterval]
}

final class ImageIODecoder {
    func decode(_ url: URL) throws -> ImageDecodeResult {
        guard ImageFormat.isSupported(url) else {
            throw ImageDecodeError.unsupportedFormat
        }

        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = Self.makeImage(from: source, url: url) {
            let metadata = readMetadata(for: url, image: image, source: source)
            let animatedImage = Self.makeAnimatedImage(from: source, url: url)
            return ImageDecodeResult(image: image, metadata: metadata, animatedImage: animatedImage)
        }

        // SVG 等矢量图或 CGImageSource 不直接产出的格式回退到 NSImage
        guard let fallbackImage = NSImage(contentsOf: url),
              fallbackImage.size.width > 0,
              fallbackImage.size.height > 0 else {
            throw ImageDecodeError.decodeFailed
        }

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let metadata = ImageMetadata(
            fileName: url.lastPathComponent,
            filePath: url.path,
            fileSize: Int64(resourceValues?.fileSize ?? 0),
            pixelWidth: Int(fallbackImage.size.width),
            pixelHeight: Int(fallbackImage.size.height),
            format: url.pathExtension.lowercased()
        )
        return ImageDecodeResult(image: fallbackImage, metadata: metadata, animatedImage: nil)
    }

    /// 将旋转（quarterTurns）与水平/垂直翻转烘焙进图像，并写回目标文件
    func saveTransformedImage(
        _ image: NSImage,
        to url: URL,
        rotationQuarterTurns: Int,
        flipHorizontal: Bool,
        flipVertical: Bool
    ) throws -> ImageDecodeResult {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let sourceCG = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw ImageDecodeError.decodeFailed
        }

        let normalizedTurns = ((rotationQuarterTurns % 4) + 4) % 4
        let swapsDimensions = !normalizedTurns.isMultiple(of: 2)
        let targetWidth = swapsDimensions ? sourceCG.height : sourceCG.width
        let targetHeight = swapsDimensions ? sourceCG.width : sourceCG.height

        guard let colorSpace = sourceCG.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: targetWidth,
                  height: targetHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ImageDecodeError.decodeFailed
        }

        context.translateBy(x: CGFloat(targetWidth) / 2, y: CGFloat(targetHeight) / 2)
        context.rotate(by: CGFloat(normalizedTurns) * .pi / 2)
        context.scaleBy(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
        context.draw(
            sourceCG,
            in: CGRect(
                x: -CGFloat(sourceCG.width) / 2,
                y: -CGFloat(sourceCG.height) / 2,
                width: CGFloat(sourceCG.width),
                height: CGFloat(sourceCG.height)
            )
        )

        guard let outputCG = context.makeImage() else {
            throw ImageDecodeError.decodeFailed
        }

        let sourceType = (CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceGetType($0) as String? })
            ?? UTType(filenameExtension: url.pathExtension)?.identifier
            ?? UTType.png.identifier

        var metadataProps: [CFString: Any] = [:]
        if let existingSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let existingProps = CGImageSourceCopyPropertiesAtIndex(existingSource, 0, nil) as? [CFString: Any] {
            metadataProps = existingProps
        }
        metadataProps[kCGImagePropertyOrientation] = 1
        if var tiff = metadataProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            metadataProps[kCGImagePropertyTIFFDictionary] = tiff
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, sourceType as CFString, 1, nil) else {
            throw ImageDecodeError.decodeFailed
        }
        CGImageDestinationAddImage(destination, outputCG, metadataProps as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageDecodeError.decodeFailed
        }

        return try decode(url)
    }
}

private extension ImageIODecoder {
    static func makeImage(from source: CGImageSource, url: URL) -> NSImage? {
        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let orientation = Self.readExifOrientation(from: properties)
            let orientedCGImage = Self.applyOrientation(orientation, to: cgImage) ?? cgImage
            return NSImage(
                cgImage: orientedCGImage,
                size: NSSize(width: orientedCGImage.width, height: orientedCGImage.height)
            )
        }
        return NSImage(contentsOf: url)
    }

    static func readExifOrientation(from properties: [CFString: Any]?) -> Int {
        guard let properties else { return 1 }
        if let topOrientation = properties[kCGImagePropertyOrientation] as? Int {
            return topOrientation
        }
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let tiffOrientation = tiff[kCGImagePropertyTIFFOrientation] as? Int {
            return tiffOrientation
        }
        return 1
    }

    /// 根据 EXIF Orientation (1...8) 旋转/翻转 CGImage，确保主画布与缩略图方向一致
    static func applyOrientation(_ orientation: Int, to cgImage: CGImage) -> CGImage? {
        guard (2...8).contains(orientation) else { return cgImage }

        let width = cgImage.width
        let height = cgImage.height
        let swapsDimensions = (5...8).contains(orientation)
        let targetWidth = swapsDimensions ? height : width
        let targetHeight = swapsDimensions ? width : height

        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: targetWidth,
                  height: targetHeight,
                  bitsPerComponent: cgImage.bitsPerComponent,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return cgImage
        }

        let w = CGFloat(width)
        let h = CGFloat(height)

        switch orientation {
        case 2: // 水平翻转
            context.translateBy(x: w, y: 0)
            context.scaleBy(x: -1, y: 1)
        case 3: // 180°
            context.translateBy(x: w, y: h)
            context.rotate(by: .pi)
        case 4: // 垂直翻转
            context.translateBy(x: 0, y: h)
            context.scaleBy(x: 1, y: -1)
        case 5: // 转置
            context.translateBy(x: 0, y: w)
            context.rotate(by: -.pi / 2)
            context.translateBy(x: w, y: 0)
            context.scaleBy(x: -1, y: 1)
        case 6: // 顺时针 90°
            context.translateBy(x: 0, y: w)
            context.rotate(by: -.pi / 2)
        case 7: // 横向转置
            context.translateBy(x: h, y: 0)
            context.rotate(by: .pi / 2)
            context.translateBy(x: w, y: 0)
            context.scaleBy(x: -1, y: 1)
        case 8: // 逆时针 90°
            context.translateBy(x: h, y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return context.makeImage() ?? cgImage
    }

    static func makeAnimatedImage(from source: CGImageSource, url: URL) -> AnimatedImage? {
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return nil }
        let ext = url.pathExtension.lowercased()
        let isAnimatedCandidate = ImageFormat.isAnimated(url)
            || (ext == "png" && hasPNGAnimationProperties(source: source))
        guard isAnimatedCandidate else { return nil }

        var frames: [NSImage] = []
        var durations: [TimeInterval] = []

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            frames.append(NSImage(cgImage: cgImage, size: size))
            durations.append(Self.frameDuration(forFrameAt: index, source: source))
        }

        guard frames.count > 1, frames.count == durations.count else { return nil }
        return AnimatedImage(frames: frames, durations: durations)
    }

    static func hasPNGAnimationProperties(source: CGImageSource) -> Bool {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pngProps = props[kCGImagePropertyPNGDictionary] as? [CFString: Any] else {
            return false
        }
        return pngProps[kCGImagePropertyAPNGDelayTime] != nil
            || pngProps[kCGImagePropertyAPNGUnclampedDelayTime] != nil
    }

    static func frameDuration(forFrameAt index: Int, source: CGImageSource) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.1
        }

        if let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
            return max(unclamped ?? clamped ?? 0.1, 0.02)
        }

        if let pngProperties = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            let unclamped = pngProperties[kCGImagePropertyAPNGUnclampedDelayTime] as? Double
            let clamped = pngProperties[kCGImagePropertyAPNGDelayTime] as? Double
            return max(unclamped ?? clamped ?? 0.1, 0.02)
        }

        if let webpProperties = properties[kCGImagePropertyWebPDictionary] as? [CFString: Any] {
            let unclamped = webpProperties[kCGImagePropertyWebPUnclampedDelayTime] as? Double
            let clamped = webpProperties[kCGImagePropertyWebPDelayTime] as? Double
            return max(unclamped ?? clamped ?? 0.1, 0.02)
        }

        return 0.1
    }

    func readMetadata(for url: URL, image: NSImage, source: CGImageSource) -> ImageMetadata {
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        var metadata = ImageMetadata(
            fileName: url.lastPathComponent,
            filePath: url.path,
            fileSize: Int64(resourceValues?.fileSize ?? 0),
            pixelWidth: nil,
            pixelHeight: nil,
            format: url.pathExtension.lowercased(),
            colorModel: nil,
            colorSpace: nil,
            capturedAt: nil,
            cameraMake: nil,
            cameraModel: nil,
            lensModel: nil,
            iso: nil,
            aperture: nil,
            shutterSpeed: nil,
            exposureBias: nil,
            focalLength: nil
        )

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            metadata.pixelWidth = Int(image.size.width)
            metadata.pixelHeight = Int(image.size.height)
            return metadata
        }

        let orientation = Self.readExifOrientation(from: properties)
        let swapsDimensions = (5...8).contains(orientation)
        let rawWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? Int(image.size.width)
        let rawHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? Int(image.size.height)
        metadata.pixelWidth = swapsDimensions ? rawHeight : rawWidth
        metadata.pixelHeight = swapsDimensions ? rawWidth : rawHeight
        metadata.colorModel = properties[kCGImagePropertyColorModel] as? String
        metadata.colorSpace = properties[kCGImagePropertyProfileName] as? String

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            metadata.capturedAt = parseDate(exif[kCGImagePropertyExifDateTimeOriginal] as? String)
            metadata.iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first
            metadata.aperture = exif[kCGImagePropertyExifFNumber] as? Double
            metadata.shutterSpeed = exif[kCGImagePropertyExifExposureTime].map { "\($0)s" }
            metadata.exposureBias = exif[kCGImagePropertyExifExposureBiasValue] as? Double
            metadata.focalLength = exif[kCGImagePropertyExifFocalLength] as? Double
            metadata.lensModel = exif[kCGImagePropertyExifLensModel] as? String
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            metadata.cameraMake = tiff[kCGImagePropertyTIFFMake] as? String
            metadata.cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
        }

        return metadata
    }

    func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
