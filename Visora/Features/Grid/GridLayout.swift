import CoreGraphics

enum GridLayout {
    static let minimumScale: CGFloat = 0.8
    static let maximumScale: CGFloat = 1.6
    static let defaultScale: CGFloat = 1
    static let scaleStep: CGFloat = 0.1
    static let baseCellWidth: CGFloat = 142
    static let baseCellHeight: CGFloat = 170
    static let spacing: CGFloat = 18

    static func rowCount(itemCount: Int, columns: Int) -> Int {
        guard itemCount > 0, columns > 0 else { return 0 }
        return (itemCount + columns - 1) / columns
    }

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }

    static func adjustedScale(_ scale: CGFloat, delta: CGFloat) -> CGFloat {
        clampedScale(((scale + delta) * 10).rounded() / 10)
    }

    static func cellSize(scale: CGFloat) -> CGSize {
        let normalized = clampedScale(scale)
        return CGSize(
            width: baseCellWidth * normalized,
            height: baseCellHeight * normalized
        )
    }

    static func columnCount(availableWidth: CGFloat, scale: CGFloat) -> Int {
        let width = cellSize(scale: scale).width
        guard availableWidth > 0, width > 0 else { return 1 }
        return max(Int((availableWidth + spacing) / (width + spacing)), 1)
    }

    static func movedIndex(current: Int, keyCode: UInt16, itemCount: Int, columns: Int) -> Int {
        guard itemCount > 0 else { return 0 }

        switch keyCode {
        case 123:
            return max(current - 1, 0)
        case 124:
            return min(current + 1, itemCount - 1)
        case 125:
            return min(current + max(columns, 1), itemCount - 1)
        case 126:
            return max(current - max(columns, 1), 0)
        default:
            return current
        }
    }
}
