import XCTest
@testable import nolon

final class UnifiedAccountCardTapBehaviorTests: XCTestCase {
    func testBDD_GivenTapBehaviorIsNone_WhenResolvingCardTapGesture_ThenDoesNotInstallTapGesture() {
        XCTAssertFalse(UnifiedAccountCard.shouldInstallTapGesture(for: .none))
    }

    func testBDD_GivenTapBehaviorCanTriggerAction_WhenResolvingCardTapGesture_ThenInstallsTapGesture() {
        XCTAssertTrue(UnifiedAccountCard.shouldInstallTapGesture(for: .activate))
        XCTAssertTrue(UnifiedAccountCard.shouldInstallTapGesture(for: .toggleSelection))
        XCTAssertTrue(UnifiedAccountCard.shouldInstallTapGesture(for: .openProvider))
    }
}
