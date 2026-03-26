import XCTest
@testable import nolon

final class GenericSelectionControlTests: XCTestCase {
    func testBDD_GivenSingleSelection_WhenSelectingNewValue_ThenSelectionSwitchesToNewValue() {
        let result = GenericSelectionStateResolver.resolveSingleSelection(
            current: "a",
            tapped: "b",
            allowsEmptySelection: false
        )
        XCTAssertEqual(result, "b")
    }

    func testBDD_GivenSingleSelectionWithoutEmpty_WhenTappingSameValue_ThenSelectionStaysUnchanged() {
        let result = GenericSelectionStateResolver.resolveSingleSelection(
            current: "a",
            tapped: "a",
            allowsEmptySelection: false
        )
        XCTAssertEqual(result, "a")
    }

    func testBDD_GivenSingleSelectionWithEmpty_WhenTappingSameValue_ThenSelectionClears() {
        let result = GenericSelectionStateResolver.resolveSingleSelection(
            current: "a",
            tapped: "a",
            allowsEmptySelection: true
        )
        XCTAssertNil(result)
    }

    func testBDD_GivenMultiSelection_WhenTappingSelectedValue_ThenValueIsRemoved() {
        let result = GenericSelectionStateResolver.resolveMultiSelection(
            current: Set(["a", "b"]),
            tapped: "a"
        )
        XCTAssertEqual(result, Set(["b"]))
    }

    func testBDD_GivenMultiSelection_WhenTappingUnselectedValue_ThenValueIsInserted() {
        let result = GenericSelectionStateResolver.resolveMultiSelection(
            current: Set(["a"]),
            tapped: "b"
        )
        XCTAssertEqual(result, Set(["a", "b"]))
    }

    func testBDD_GivenIDBoxSelections_WhenToggling_ThenKeepsTypeErasedSetStable() {
        let one = IDBox(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let two = IDBox(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let result = GenericSelectionStateResolver.resolveMultiSelection(
            current: Set([one]),
            tapped: two
        )
        XCTAssertEqual(result, Set([one, two]))
    }
}
