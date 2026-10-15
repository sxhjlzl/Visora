import XCTest
@testable import Visora

final class GridLayoutTests: XCTestCase {
    func testRowCountRoundsUpPartialRows() {
        XCTAssertEqual(GridLayout.rowCount(itemCount: 0, columns: 5), 0)
        XCTAssertEqual(GridLayout.rowCount(itemCount: 1, columns: 5), 1)
        XCTAssertEqual(GridLayout.rowCount(itemCount: 5, columns: 5), 1)
        XCTAssertEqual(GridLayout.rowCount(itemCount: 6, columns: 5), 2)
    }

    func testRowCountHandlesInvalidColumns() {
        XCTAssertEqual(GridLayout.rowCount(itemCount: 6, columns: 0), 0)
    }

    func testColumnCountRespondsToAvailableWidthAndScale() {
        XCTAssertEqual(GridLayout.columnCount(availableWidth: 900, scale: 1), 5)
        XCTAssertEqual(GridLayout.columnCount(availableWidth: 900, scale: 1.6), 3)
        XCTAssertEqual(GridLayout.columnCount(availableWidth: 0, scale: 1), 1)
    }

    func testAdjustedScaleClampsWithinGridBounds() {
        XCTAssertEqual(GridLayout.adjustedScale(1, delta: 0.1), 1.1, accuracy: 0.001)
        XCTAssertEqual(GridLayout.adjustedScale(0.8, delta: -0.2), 0.8, accuracy: 0.001)
        XCTAssertEqual(GridLayout.adjustedScale(1.6, delta: 0.3), 1.6, accuracy: 0.001)
    }

    func testMovedIndexFollowsArrowNavigation() {
        XCTAssertEqual(GridLayout.movedIndex(current: 5, keyCode: 123, itemCount: 12, columns: 4), 4)
        XCTAssertEqual(GridLayout.movedIndex(current: 5, keyCode: 124, itemCount: 12, columns: 4), 6)
        XCTAssertEqual(GridLayout.movedIndex(current: 5, keyCode: 125, itemCount: 12, columns: 4), 9)
        XCTAssertEqual(GridLayout.movedIndex(current: 1, keyCode: 126, itemCount: 12, columns: 4), 0)
    }
}
