import AppKit

struct ImageHistogram: Equatable {
    let red: [CGFloat]
    let green: [CGFloat]
    let blue: [CGFloat]
    let luminance: [CGFloat]

    static func compute(from image: NSImage, binCount: Int = 64) -> ImageHistogram? {
        guard binCount > 1 else { return nil }
        let sampleSize = 128
        var rawData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &rawData,
                  width: sampleSize,
                  height: sampleSize,
                  bitsPerComponent: 8,
                  bytesPerRow: sampleSize * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        var rect = NSRect(x: 0, y: 0, width: sampleSize, height: sampleSize)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        } else {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }

        var rBins = [Int](repeating: 0, count: binCount)
        var gBins = [Int](repeating: 0, count: binCount)
        var bBins = [Int](repeating: 0, count: binCount)
        var lBins = [Int](repeating: 0, count: binCount)

        let pixelCount = sampleSize * sampleSize
        for i in 0..<pixelCount {
            let offset = i * 4
            let a = Int(rawData[offset + 3])
            guard a > 16 else { continue }

            let r = Int(rawData[offset])
            let g = Int(rawData[offset + 1])
            let b = Int(rawData[offset + 2])
            let lum = min(max((299 * r + 587 * g + 114 * b) / 1000, 0), 255)

            rBins[min(r * binCount / 256, binCount - 1)] += 1
            gBins[min(g * binCount / 256, binCount - 1)] += 1
            bBins[min(b * binCount / 256, binCount - 1)] += 1
            lBins[min(lum * binCount / 256, binCount - 1)] += 1
        }

        let maxCount = CGFloat(max(
            rBins.max() ?? 1,
            gBins.max() ?? 1,
            bBins.max() ?? 1,
            lBins.max() ?? 1,
            1
        ))

        return ImageHistogram(
            red: rBins.map { CGFloat($0) / maxCount },
            green: gBins.map { CGFloat($0) / maxCount },
            blue: bBins.map { CGFloat($0) / maxCount },
            luminance: lBins.map { CGFloat($0) / maxCount }
        )
    }
}

final class HistogramView: NSView {
    var histogram: ImageHistogram? {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        identifier = NSUserInterfaceItemIdentifier("imageHistogramView")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 320, height: 76)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.28).setFill()
        bounds.fill()

        let gridLines = 3
        NSColor(white: 1, alpha: 0.06).setStroke()
        for index in 1...gridLines {
            let x = bounds.width * CGFloat(index) / CGFloat(gridLines + 1)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
            path.lineWidth = 1
            path.stroke()
        }

        guard let histogram else { return }

        drawChannel(
            histogram.red,
            fill: NSColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 0.24),
            stroke: NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 0.72)
        )
        drawChannel(
            histogram.green,
            fill: NSColor(red: 0.28, green: 0.92, blue: 0.48, alpha: 0.22),
            stroke: NSColor(red: 0.36, green: 0.96, blue: 0.54, alpha: 0.72)
        )
        drawChannel(
            histogram.blue,
            fill: NSColor(red: 0.32, green: 0.62, blue: 1.0, alpha: 0.24),
            stroke: NSColor(red: 0.44, green: 0.72, blue: 1.0, alpha: 0.76)
        )
        drawChannel(
            histogram.luminance,
            fill: NSColor(white: 0.95, alpha: 0.14),
            stroke: NSColor(white: 0.96, alpha: 0.85)
        )
    }

    private func drawChannel(_ values: [CGFloat], fill: NSColor, stroke: NSColor) {
        guard values.count > 1 else { return }
        let insetBounds = bounds.insetBy(dx: 4, dy: 4)
        guard insetBounds.width > 0, insetBounds.height > 0 else { return }

        let fillPath = NSBezierPath()
        let strokePath = NSBezierPath()
        let stepX = insetBounds.width / CGFloat(values.count - 1)

        fillPath.move(to: NSPoint(x: insetBounds.minX, y: insetBounds.minY))
        for (index, value) in values.enumerated() {
            let x = insetBounds.minX + CGFloat(index) * stepX
            let y = insetBounds.minY + min(max(value, 0), 1) * insetBounds.height
            let point = NSPoint(x: x, y: y)
            fillPath.line(to: point)
            if index == 0 {
                strokePath.move(to: point)
            } else {
                strokePath.line(to: point)
            }
        }
        fillPath.line(to: NSPoint(x: insetBounds.maxX, y: insetBounds.minY))
        fillPath.close()

        fill.setFill()
        fillPath.fill()

        stroke.setStroke()
        strokePath.lineWidth = 1.2
        strokePath.stroke()
    }
}
