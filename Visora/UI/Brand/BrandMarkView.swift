import AppKit

enum BrandStyle {
    static let backgroundColor = NSColor(red: 0.04, green: 0.045, blue: 0.055, alpha: 1)
    static let accentColor = NSColor(calibratedRed: 0.94, green: 0.32, blue: 0.34, alpha: 1)
    static let defaultLogoSize: CGFloat = 96
}

enum AppIconImage {
    static func load() -> NSImage? {
        if let bundledURL = Bundle.main.url(forResource: "Visora", withExtension: "png"),
           let image = NSImage(contentsOf: bundledURL) {
            return image
        }

        let fallbackURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("assets")
            .appendingPathComponent("Visora.png")
        return NSImage(contentsOf: fallbackURL)
    }
}

final class AppIconView: NSImageView {
    init() {
        super.init(frame: .zero)
        image = AppIconImage.load()
        imageScaling = .scaleProportionallyUpOrDown
        imageAlignment = .alignCenter
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class BrandMarkView: NSView {
    override var wantsDefaultClipping: Bool { false }

    // Fallback mark for development environments where the bundled app icon is unavailable.
    override func draw(_ dirtyRect: NSRect) {
        if let image = AppIconImage.load() {
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            return
        }

        let canvas = bounds
        let outerRect = canvas.insetBy(dx: canvas.width * 0.05, dy: canvas.height * 0.05)
        let outerPath = NSBezierPath(
            roundedRect: outerRect,
            xRadius: canvas.width * 0.22,
            yRadius: canvas.height * 0.22
        )
        let outerGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.93, green: 0.34, blue: 0.28, alpha: 1),
            NSColor(calibratedRed: 0.78, green: 0.23, blue: 0.22, alpha: 1)
        ])
        outerGradient?.draw(in: outerPath, angle: -45)

        let innerRect = outerRect.insetBy(dx: canvas.width * 0.16, dy: canvas.height * 0.16)
        let innerPath = NSBezierPath(
            roundedRect: innerRect,
            xRadius: canvas.width * 0.12,
            yRadius: canvas.height * 0.12
        )
        NSColor(white: 1, alpha: 0.96).setFill()
        innerPath.fill()

        let sunDiameter = innerRect.width * 0.16
        let sunRect = NSRect(
            x: innerRect.maxX - sunDiameter - innerRect.width * 0.12,
            y: innerRect.maxY - sunDiameter - innerRect.height * 0.12,
            width: sunDiameter,
            height: sunDiameter
        )
        let sunPath = NSBezierPath(ovalIn: sunRect)
        BrandStyle.accentColor.setFill()
        sunPath.fill()

        let ridgePath = NSBezierPath()
        ridgePath.move(to: NSPoint(x: innerRect.minX + innerRect.width * 0.12, y: innerRect.minY + innerRect.height * 0.26))
        ridgePath.line(to: NSPoint(x: innerRect.minX + innerRect.width * 0.38, y: innerRect.minY + innerRect.height * 0.56))
        ridgePath.line(to: NSPoint(x: innerRect.minX + innerRect.width * 0.54, y: innerRect.minY + innerRect.height * 0.40))
        ridgePath.line(to: NSPoint(x: innerRect.minX + innerRect.width * 0.72, y: innerRect.minY + innerRect.height * 0.62))
        ridgePath.line(to: NSPoint(x: innerRect.maxX - innerRect.width * 0.12, y: innerRect.minY + innerRect.height * 0.26))
        ridgePath.close()
        BrandStyle.accentColor.setFill()
        ridgePath.fill()

        let foregroundPath = NSBezierPath()
        foregroundPath.move(to: NSPoint(x: innerRect.minX + innerRect.width * 0.12, y: innerRect.minY + innerRect.height * 0.18))
        foregroundPath.curve(
            to: NSPoint(x: innerRect.maxX - innerRect.width * 0.12, y: innerRect.minY + innerRect.height * 0.18),
            controlPoint1: NSPoint(x: innerRect.minX + innerRect.width * 0.28, y: innerRect.minY + innerRect.height * 0.34),
            controlPoint2: NSPoint(x: innerRect.minX + innerRect.width * 0.66, y: innerRect.minY + innerRect.height * 0.02)
        )
        foregroundPath.line(to: NSPoint(x: innerRect.maxX - innerRect.width * 0.12, y: innerRect.minY + innerRect.height * 0.08))
        foregroundPath.line(to: NSPoint(x: innerRect.minX + innerRect.width * 0.12, y: innerRect.minY + innerRect.height * 0.08))
        foregroundPath.close()
        NSColor(calibratedRed: 0.22, green: 0.11, blue: 0.12, alpha: 0.14).setFill()
        foregroundPath.fill()
    }
}
