import AppKit
import XCTest
@testable import Visora

final class PinWindowLayoutTests: XCTestCase {
    func testInitialWindowSizeScalesLargeImagesWithinMaxBounds() {
        let size = PinWindowLayout.initialWindowSize(
            for: NSSize(width: 2_000, height: 1_000),
            maxSize: NSSize(width: 500, height: 300)
        )

        XCTAssertEqual(size.width, 500, accuracy: 0.001)
        XCTAssertEqual(size.height, 250, accuracy: 0.001)
    }

    func testInitialWindowSizeAppliesMinimumBoundsForTinyImages() {
        let size = PinWindowLayout.initialWindowSize(
            for: NSSize(width: 80, height: 60),
            maxSize: NSSize(width: 500, height: 300)
        )

        XCTAssertEqual(size.width, 220, accuracy: 0.001)
        XCTAssertEqual(size.height, 160, accuracy: 0.001)
    }

    func testInitialWindowSizeFallsBackForInvalidImageSize() {
        let size = PinWindowLayout.initialWindowSize(for: .zero)

        XCTAssertEqual(size.width, 360, accuracy: 0.001)
        XCTAssertEqual(size.height, 260, accuracy: 0.001)
    }

    func testInitialTextWindowSizeGrowsForLongTextWithinMaxBounds() {
        let shortSize = PinWindowLayout.initialTextWindowSize(characterCount: 20)
        let longSize = PinWindowLayout.initialTextWindowSize(characterCount: 900)

        XCTAssertGreaterThan(longSize.height, shortSize.height)
        XCTAssertLessThanOrEqual(longSize.width, 520)
        XCTAssertLessThanOrEqual(longSize.height, 420)
    }

    func testPinWindowOpacityAdjustsAndClampsToReadableRange() {
        XCTAssertEqual(PinWindowOpacity.adjusted(1, delta: -0.1), 0.9, accuracy: 0.001)
        XCTAssertEqual(PinWindowOpacity.adjusted(0.36, delta: -0.1), 0.35, accuracy: 0.001)
        XCTAssertEqual(PinWindowOpacity.adjusted(0.96, delta: 0.1), 1, accuracy: 0.001)
        XCTAssertEqual(PinWindowOpacity.percentText(for: 0.735), "74%")
    }

    func testPinWindowLockStateSwitchesButtonTitleKey() {
        XCTAssertEqual(PinWindowLockState.buttonTitleKey(isLocked: false), .lock)
        XCTAssertEqual(PinWindowLockState.buttonTitleKey(isLocked: true), .unlock)
    }
}
