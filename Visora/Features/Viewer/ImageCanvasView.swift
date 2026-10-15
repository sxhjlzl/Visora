import AppKit
import CoreImage

enum CanvasBackgroundStyle: String, CaseIterable {
    case dark
    case checkerboard
    case light
    case ambient

    var next: CanvasBackgroundStyle {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}

final class ImageCanvasView: NSView {
    var commandHandler: ((ViewerCommand) -> Void)?
    var openURLHandler: ((URL) -> Void)?
    var zoomChangedHandler: (() -> Void)?
    var interactionHandler: (() -> Void)?
    var localizer = Localizer.default {
        didSet {
            needsDisplay = true
        }
    }
    var backgroundStyle: CanvasBackgroundStyle = .dark {
        didSet {
            if backgroundStyle == .ambient, ambientBackdropImage == nil, let image {
                ambientBackdropImage = Self.makeAmbientBackdrop(for: image)
            }
            needsDisplay = true
        }
    }
    var isPixelatedInterpolation = false {
        didSet {
            needsDisplay = true
        }
    }
    var isZoomLocked = false
    private(set) var isFlippedHorizontally = false
    private(set) var isFlippedVertically = false
    private var accumulatedRotationDegrees: Float = 0
    private var ambientBackdropImage: NSImage?
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    var contentInsets = NSEdgeInsetsZero {
        didSet {
            guard !contentInsets.isVisuallyEqual(to: oldValue) else { return }
            guard image != nil else {
                needsDisplay = true
                return
            }
            if isLongImageMode {
                fitWidthFromTop()
            } else if zoomScale <= 1.01 {
                fitToWindow()
            } else {
                clampPanOffset()
                needsDisplay = true
            }
        }
    }

    private var image: NSImage?
    private var animatedImage: AnimatedImage?
    private var animationTimer: Timer?
    private var currentFrameIndex = 0
    private var panOffset: CGSize = .zero
    private var lastDragLocation: NSPoint?
    private var trackingArea: NSTrackingArea?
    private var isLongImageMode = false
    private var rotationQuarterTurns = 0
    private(set) var zoomScale: CGFloat = 1

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { image == nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        registerForDraggedTypes([.fileURL])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    func setImage(_ image: NSImage, animatedImage: AnimatedImage? = nil, longImageMode: Bool = false) {
        let hadPreviousImage = self.image != nil
        let lockedZoom = zoomScale
        let lockedPan = panOffset

        self.image = image
        self.animatedImage = animatedImage
        self.isLongImageMode = longImageMode
        self.ambientBackdropImage = backgroundStyle == .ambient ? Self.makeAmbientBackdrop(for: image) : nil
        currentFrameIndex = 0
        updateAnimationState()

        if isZoomLocked && hadPreviousImage && !longImageMode {
            zoomScale = lockedZoom
            panOffset = lockedPan
            clampPanOffset()
            needsDisplay = true
            zoomChangedHandler?()
        } else if longImageMode {
            fitWidthFromTop()
        } else {
            fitToWindow()
        }
    }

    func clearImage() {
        stopAnimation()
        image = nil
        animatedImage = nil
        ambientBackdropImage = nil
        isLongImageMode = false
        rotationQuarterTurns = 0
        isFlippedHorizontally = false
        isFlippedVertically = false
        zoomScale = 1
        panOffset = .zero
        currentFrameIndex = 0
        needsDisplay = true
        zoomChangedHandler?()
    }

    func setFlip(horizontal: Bool, vertical: Bool) {
        isFlippedHorizontally = horizontal
        isFlippedVertically = vertical
        needsDisplay = true
    }

    func setRotationQuarterTurns(_ value: Int) {
        rotationQuarterTurns = ((value % 4) + 4) % 4
        if image != nil {
            if isLongImageMode {
                fitWidthFromTop()
            } else {
                fitToWindow()
            }
        } else {
            needsDisplay = true
        }
    }

    func zoom(by factor: CGFloat, centeredAt point: NSPoint? = nil) {
        guard image != nil else { return }
        let oldZoom = zoomScale
        zoomScale = min(max(zoomScale * factor, 0.05), 20)

        if let point {
            let center = viewportRect.center
            panOffset.width += (point.x - center.x) * (1 - zoomScale / oldZoom)
            panOffset.height += (point.y - center.y) * (1 - zoomScale / oldZoom)
        }

        needsDisplay = true
        clampPanOffset()
        zoomChangedHandler?()
    }

    func fitToWindow() {
        let displayedSize = orientedImageSize
        let viewport = viewportRect
        guard displayedSize.width > 0, displayedSize.height > 0, viewport.width > 0, viewport.height > 0 else {
            zoomScale = 1
            panOffset = .zero
            needsDisplay = true
            zoomChangedHandler?()
            return
        }

        let scaleX = viewport.width / displayedSize.width
        let scaleY = viewport.height / displayedSize.height
        zoomScale = min(scaleX, scaleY, 1)
        panOffset = .zero
        isLongImageMode = false
        needsDisplay = true
        zoomChangedHandler?()
    }

    func fitWidthFromTop() {
        let displayedSize = orientedImageSize
        let viewport = viewportRect
        guard displayedSize.width > 0, viewport.width > 0 else {
            fitToWindow()
            return
        }

        isLongImageMode = true
        zoomScale = viewport.width / displayedSize.width
        panOffset.width = 0
        alignTop()
        clampPanOffset()
        needsDisplay = true
        zoomChangedHandler?()
    }

    func showActualSize() {
        zoomScale = 1
        panOffset = .zero
        isLongImageMode = false
        needsDisplay = true
        zoomChangedHandler?()
    }

    func jumpToTop() {
        guard isLongImageMode else { return }
        alignTop()
        needsDisplay = true
    }

    func jumpToBottom() {
        guard isLongImageMode else { return }
        alignBottom()
        needsDisplay = true
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        if isLongImageMode {
            fitWidthFromTop()
        } else if zoomScale <= 1.01 {
            fitToWindow()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground(in: dirtyRect)

        guard let image else {
            drawEmptyState()
            return
        }

        let displayedImage = currentDisplayedImage ?? image
        let drawSize = NSSize(width: displayedImage.size.width * zoomScale, height: displayedImage.size.height * zoomScale)
        let center = NSPoint(x: viewportRect.midX + panOffset.width, y: viewportRect.midY + panOffset.height)
        let interpolation: NSImageInterpolation = isPixelatedInterpolation ? .none : .high

        guard let graphicsContext = NSGraphicsContext.current?.cgContext else {
            displayedImage.draw(
                in: NSRect(
                    x: center.x - drawSize.width / 2,
                    y: center.y - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                ),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return
        }

        graphicsContext.saveGState()
        graphicsContext.interpolationQuality = isPixelatedInterpolation ? .none : .high
        graphicsContext.translateBy(x: center.x, y: center.y)
        graphicsContext.rotate(by: CGFloat(rotationQuarterTurns) * .pi / 2)
        graphicsContext.scaleBy(
            x: isFlippedHorizontally ? -1 : 1,
            y: isFlippedVertically ? -1 : 1
        )

        let imageRect = NSRect(
            x: -drawSize.width / 2,
            y: -drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        // 当图片未撑满整个画布时，绘制柔和立体阴影与 1px 微高光描边，提升画面层次感
        graphicsContext.saveGState()
        graphicsContext.setShadow(
            offset: CGSize(width: 0, height: -8),
            blur: 28,
            color: NSColor(white: 0, alpha: 0.52).cgColor
        )
        displayedImage.draw(
            in: imageRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: interpolation]
        )
        graphicsContext.restoreGState()

        let borderColor = backgroundStyle == .light
            ? NSColor(white: 0, alpha: 0.10)
            : NSColor(white: 1, alpha: 0.10)
        borderColor.setStroke()
        let borderPath = NSBezierPath(rect: imageRect.insetBy(dx: -0.5, dy: -0.5))
        borderPath.lineWidth = 1
        borderPath.stroke()

        graphicsContext.restoreGState()
    }

    override func scrollWheel(with event: NSEvent) {
        interactionHandler?()

        if event.modifierFlags.contains(.command) {
            if event.scrollingDeltaY < 0 {
                commandHandler?(.nextImage)
            } else {
                commandHandler?(.previousImage)
            }
            return
        }

        if event.modifierFlags.contains(.option) {
            panOffset.width += event.scrollingDeltaX
            panOffset.height -= event.scrollingDeltaY
            clampPanOffset()
            needsDisplay = true
            return
        }

        if isLongImageMode {
            panOffset.height -= event.scrollingDeltaY
            clampPanOffset()
            needsDisplay = true
            return
        }

        let factor = event.scrollingDeltaY > 0 ? 1.08 : 1 / 1.08
        zoom(by: factor, centeredAt: convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        interactionHandler?()

        if event.clickCount == 2 {
            toggleZoom()
            return
        }
        lastDragLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        interactionHandler?()

        let current = convert(event.locationInWindow, from: nil)
        if let lastDragLocation {
            panOffset.width += current.x - lastDragLocation.x
            panOffset.height += current.y - lastDragLocation.y
            clampPanOffset()
            needsDisplay = true
        }
        lastDragLocation = current
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
    }

    override func mouseMoved(with event: NSEvent) {
        interactionHandler?()
    }

    override func magnify(with event: NSEvent) {
        interactionHandler?()
        let factor = max(0.2, 1 + event.magnification)
        zoom(by: factor, centeredAt: convert(event.locationInWindow, from: nil))
    }

    override func smartMagnify(with event: NSEvent) {
        interactionHandler?()
        toggleZoom()
    }

    override func rotate(with event: NSEvent) {
        interactionHandler?()
        if event.phase == .began {
            accumulatedRotationDegrees = 0
        }
        accumulatedRotationDegrees += event.rotation
        if accumulatedRotationDegrees >= 35 {
            accumulatedRotationDegrees = 0
            commandHandler?(.rotateLeft)
        } else if accumulatedRotationDegrees <= -35 {
            accumulatedRotationDegrees = 0
            commandHandler?(.rotateRight)
        }
    }

    override func swipe(with event: NSEvent) {
        interactionHandler?()
        if event.deltaX > 0 {
            commandHandler?(.previousImage)
        } else if event.deltaX < 0 {
            commandHandler?(.nextImage)
        }
    }

    override func keyDown(with event: NSEvent) {
        interactionHandler?()

        switch event.keyCode {
        case 53:
            commandHandler?(.closeWindow)
        case 123:
            commandHandler?(.previousImage)
        case 124:
            commandHandler?(.nextImage)
        case 125:
            commandHandler?(.zoomOut)
        case 126:
            commandHandler?(.zoomIn)
        case 49:
            if zoomScale == 1 {
                commandHandler?(.fitToWindow)
            } else {
                commandHandler?(.actualSize)
            }
        case 51:
            commandHandler?(.moveToTrash)
        case 115:
            commandHandler?(.jumpToTop)
        case 119:
            commandHandler?(.jumpToBottom)
        default:
            handleCharacter(event.charactersIgnoringModifiers)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        interactionHandler?()
        return draggedFileURL(from: sender) == nil ? NSDragOperation() : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = draggedFileURL(from: sender) else { return false }
        openURLHandler?(url)
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        interactionHandler?()
        guard image != nil else { return nil }

        let menu = NSMenu()
        addContextItem(to: menu, title: localizer.string(.copyImageBitmap), symbol: "doc.on.clipboard", action: #selector(contextCopyBitmap))
        addContextItem(to: menu, title: localizer.string(.copyFile), symbol: "doc.on.doc", action: #selector(contextCopyFile))
        addContextItem(to: menu, title: localizer.string(.copyFilePath), symbol: "link", action: #selector(contextCopyPath))
        addContextItem(to: menu, title: localizer.string(.recognizeText), symbol: "text.viewfinder", action: #selector(contextRecognizeText))
        menu.addItem(.separator())
        addContextItem(to: menu, title: localizer.string(.fitToWindow), symbol: "arrow.down.right.and.arrow.up.left", action: #selector(contextFitToWindow))
        addContextItem(to: menu, title: localizer.string(.actualSize), symbol: "1.square", action: #selector(contextActualSize))
        addContextItem(to: menu, title: localizer.string(.zoomLock), symbol: "lock.square", action: #selector(contextToggleZoomLock), state: isZoomLocked ? .on : .off)
        addContextItem(to: menu, title: localizer.string(.pixelatedInterpolation), symbol: "squareshape.split.2x2", action: #selector(contextTogglePixelated), state: isPixelatedInterpolation ? .on : .off)
        addContextItem(to: menu, title: localizer.string(.canvasBackground), symbol: "circle.lefthalf.filled", action: #selector(contextCycleBackground))
        menu.addItem(.separator())
        addContextItem(to: menu, title: localizer.string(.rotateLeft), symbol: "rotate.left", action: #selector(contextRotateLeft))
        addContextItem(to: menu, title: localizer.string(.rotateRight), symbol: "rotate.right", action: #selector(contextRotateRight))
        addContextItem(to: menu, title: localizer.string(.flipHorizontal), symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", action: #selector(contextFlipHorizontal))
        addContextItem(to: menu, title: localizer.string(.flipVertical), symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down", action: #selector(contextFlipVertical))
        menu.addItem(.separator())
        addContextItem(to: menu, title: localizer.string(.pinImage), symbol: "pin", action: #selector(contextPinImage))
        addContextItem(to: menu, title: localizer.string(.revealInFinder), symbol: "folder", action: #selector(contextRevealInFinder))
        addContextItem(to: menu, title: localizer.string(.trashImage), symbol: "trash", action: #selector(contextMoveToTrash))
        return menu
    }
}

private extension ImageCanvasView {
    func handleCharacter(_ value: String?) {
        switch value?.lowercased() {
        case "f":
            commandHandler?(.toggleFullscreen)
        case "g":
            commandHandler?(.toggleGrid)
        case "i":
            commandHandler?(.toggleInfoPanel)
        case "p":
            commandHandler?(.pinCurrentImage)
        case "c":
            commandHandler?(.toggleImmersiveChrome)
        case "[":
            commandHandler?(.rotateLeft)
        case "]":
            commandHandler?(.rotateRight)
        case "h":
            commandHandler?(.flipHorizontal)
        case "v":
            commandHandler?(.flipVertical)
        case "b":
            commandHandler?(.cycleCanvasBackground)
        case "n":
            commandHandler?(.togglePixelatedInterpolation)
        case "l":
            commandHandler?(.toggleZoomLock)
        case "o":
            commandHandler?(.recognizeText)
        case "/":
            commandHandler?(.toggleFilterBar)
        case "s":
            commandHandler?(.toggleSlideshow)
        case "t":
            commandHandler?(.toggleFilmstrip)
        default:
            break
        }
    }

    func drawBackground(in dirtyRect: NSRect) {
        switch backgroundStyle {
        case .dark:
            NSColor(red: 0.04, green: 0.045, blue: 0.055, alpha: 1).setFill()
            dirtyRect.fill()
            if let gradient = NSGradient(
                starting: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 0.55),
                ending: .clear
            ) {
                gradient.draw(
                    fromCenter: bounds.center,
                    radius: 0,
                    toCenter: bounds.center,
                    radius: max(bounds.width, bounds.height) * 0.65,
                    options: []
                )
            }
        case .light:
            NSColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1).setFill()
            dirtyRect.fill()
        case .ambient:
            NSColor(red: 0.04, green: 0.045, blue: 0.055, alpha: 1).setFill()
            dirtyRect.fill()
            if let backdrop = ambientBackdropImage {
                let targetRect = bounds.insetBy(dx: -bounds.width * 0.08, dy: -bounds.height * 0.08)
                backdrop.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 0.72)
                NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 0.48).setFill()
                dirtyRect.fill(using: .sourceOver)
            }
        case .checkerboard:
            let tileSize: CGFloat = 16
            let darkTile = NSColor(white: 0.14, alpha: 1)
            let lightTile = NSColor(white: 0.22, alpha: 1)
            darkTile.setFill()
            dirtyRect.fill()

            lightTile.setFill()
            let startCol = max(Int(floor(dirtyRect.minX / tileSize)), 0)
            let endCol = Int(ceil(dirtyRect.maxX / tileSize))
            let startRow = max(Int(floor(dirtyRect.minY / tileSize)), 0)
            let endRow = Int(ceil(dirtyRect.maxY / tileSize))
            guard endCol >= startCol, endRow >= startRow else { return }

            for row in startRow...endRow {
                for col in startCol...endCol where (row + col).isMultiple(of: 2) {
                    let rect = NSRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    ).intersection(dirtyRect)
                    if !rect.isNull {
                        rect.fill()
                    }
                }
            }
        }
    }

    static func makeAmbientBackdrop(for sourceImage: NSImage) -> NSImage? {
        let thumbSize = NSSize(width: 96, height: 96)
        guard let smallBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(thumbSize.width),
            pixelsHigh: Int(thumbSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: smallBitmap)
        sourceImage.draw(
            in: NSRect(origin: .zero, size: thumbSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let ciInput = CIImage(bitmapImageRep: smallBitmap) else { return nil }
        let clamped = ciInput.clampedToExtent()
        let blurred = clamped.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 18.0])
            .cropped(to: ciInput.extent)

        guard let cgOutput = ciContext.createCGImage(blurred, from: ciInput.extent) else { return nil }
        return NSImage(cgImage: cgOutput, size: thumbSize)
    }

    func addContextItem(
        to menu: NSMenu,
        title: String,
        symbol: String,
        action: Selector,
        state: NSControl.StateValue = .off
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = state
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        if #available(macOS 27.0, *) {
            item.preferredImageVisibility = .visible
        }
        menu.addItem(item)
    }

    @objc func contextCopyBitmap() { commandHandler?(.copyImageBitmap) }
    @objc func contextCopyFile() { commandHandler?(.copyFile) }
    @objc func contextCopyPath() { commandHandler?(.copyFilePath) }
    @objc func contextRecognizeText() { commandHandler?(.recognizeText) }
    @objc func contextFitToWindow() { commandHandler?(.fitToWindow) }
    @objc func contextActualSize() { commandHandler?(.actualSize) }
    @objc func contextToggleZoomLock() { commandHandler?(.toggleZoomLock) }
    @objc func contextTogglePixelated() { commandHandler?(.togglePixelatedInterpolation) }
    @objc func contextCycleBackground() { commandHandler?(.cycleCanvasBackground) }
    @objc func contextRotateLeft() { commandHandler?(.rotateLeft) }
    @objc func contextRotateRight() { commandHandler?(.rotateRight) }
    @objc func contextFlipHorizontal() { commandHandler?(.flipHorizontal) }
    @objc func contextFlipVertical() { commandHandler?(.flipVertical) }
    @objc func contextPinImage() { commandHandler?(.pinCurrentImage) }
    @objc func contextRevealInFinder() { commandHandler?(.revealInFinder) }
    @objc func contextMoveToTrash() { commandHandler?(.moveToTrash) }

    func drawEmptyState() {
        let text = localizer.string(.openPrompt)
        let viewport = viewportRect
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor(white: 0.75, alpha: 0.7)
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: viewport.midX - size.width / 2, y: viewport.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    func draggedFileURL(from sender: NSDraggingInfo) -> URL? {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            return first
        }
        guard let value = pasteboard.string(forType: .fileURL) else { return nil }
        return URL(string: value)
    }

    func toggleZoom() {
        guard image != nil else { return }
        if abs(zoomScale - 1) < 0.01 {
            if isLongImageMode {
                fitWidthFromTop()
            } else {
                fitToWindow()
            }
        } else {
            showActualSize()
        }
    }

    func alignTop() {
        let drawHeight = orientedImageSize.height * zoomScale
        panOffset.height = (viewportRect.height - drawHeight) / 2
    }

    func alignBottom() {
        let drawHeight = orientedImageSize.height * zoomScale
        panOffset.height = max((drawHeight - viewportRect.height) / 2, 0)
    }

    func clampPanOffset() {
        let displayedSize = orientedImageSize
        guard displayedSize.width > 0, displayedSize.height > 0 else { return }
        let viewport = viewportRect
        let drawWidth = displayedSize.width * zoomScale
        let drawHeight = displayedSize.height * zoomScale
        let horizontalLimit = max((drawWidth - viewport.width) / 2, 0)
        let verticalLimit = max((drawHeight - viewport.height) / 2, 0)

        panOffset.width = min(max(panOffset.width, -horizontalLimit), horizontalLimit)
        panOffset.height = min(max(panOffset.height, -verticalLimit), verticalLimit)
    }

    var viewportRect: NSRect {
        let horizontalInset = min(contentInsets.left + contentInsets.right, max(bounds.width - 1, 0))
        let verticalInset = min(contentInsets.top + contentInsets.bottom, max(bounds.height - 1, 0))
        return NSRect(
            x: bounds.minX + min(contentInsets.left, horizontalInset),
            y: bounds.minY + min(contentInsets.bottom, verticalInset),
            width: max(bounds.width - horizontalInset, 1),
            height: max(bounds.height - verticalInset, 1)
        )
    }

    var currentDisplayedImage: NSImage? {
        guard let animatedImage, animatedImage.frames.indices.contains(currentFrameIndex) else {
            return image
        }
        return animatedImage.frames[currentFrameIndex]
    }

    var orientedImageSize: NSSize {
        guard let image else { return .zero }
        if rotationQuarterTurns.isMultiple(of: 2) {
            return image.size
        }
        return NSSize(width: image.size.height, height: image.size.width)
    }

    func updateAnimationState() {
        stopAnimation()
        guard let animatedImage, animatedImage.frames.count > 1 else { return }
        scheduleAnimationFrame()
    }

    func scheduleAnimationFrame() {
        guard let animatedImage, animatedImage.durations.indices.contains(currentFrameIndex) else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: animatedImage.durations[currentFrameIndex], repeats: false) { [weak self] _ in
            self?.advanceAnimationFrame()
        }
    }

    func advanceAnimationFrame() {
        guard let animatedImage, !animatedImage.frames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex + 1) % animatedImage.frames.count
        needsDisplay = true
        scheduleAnimationFrame()
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

private extension NSEdgeInsets {
    func isVisuallyEqual(to other: NSEdgeInsets) -> Bool {
        abs(top - other.top) < 0.5
            && abs(left - other.left) < 0.5
            && abs(bottom - other.bottom) < 0.5
            && abs(right - other.right) < 0.5
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
