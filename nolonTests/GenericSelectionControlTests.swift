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

    func testBDD_GivenBatchMultiSelection_WhenAllValuesAlreadySelected_ThenBatchIsRemoved() {
        let result = GenericSelectionStateResolver.resolveBatchMultiSelection(
            current: Set(["a", "b", "c"]),
            toggledValues: Set(["a", "b"])
        )
        XCTAssertEqual(result, Set(["c"]))
    }

    func testBDD_GivenBatchMultiSelection_WhenAnyValueMissing_ThenBatchIsUnioned() {
        let result = GenericSelectionStateResolver.resolveBatchMultiSelection(
            current: Set(["c"]),
            toggledValues: Set(["a", "b"])
        )
        XCTAssertEqual(result, Set(["a", "b", "c"]))
    }

    func testBDD_GivenBatchMultiSelection_WhenBatchIsEmpty_ThenSelectionRemainsUnchanged() {
        let result = GenericSelectionStateResolver.resolveBatchMultiSelection(
            current: Set(["a"]),
            toggledValues: Set<String>()
        )
        XCTAssertEqual(result, Set(["a"]))
    }

    func testBDD_GivenOptionalHoverSelection_WhenHoverBegins_ThenCurrentBecomesHoveredValue() {
        let result = GenericSelectionStateResolver.resolveHoverSelection(
            current: "a",
            hovered: "b",
            isHovering: true
        )
        XCTAssertEqual(result, "b")
    }

    func testBDD_GivenOptionalHoverSelection_WhenHoverEndsOnCurrentValue_ThenSelectionClears() {
        let result = GenericSelectionStateResolver.resolveHoverSelection(
            current: "b",
            hovered: "b",
            isHovering: false
        )
        XCTAssertNil(result)
    }

    func testBDD_GivenBooleanState_WhenToggling_ThenReturnsInvertedValue() {
        XCTAssertTrue(GenericSelectionStateResolver.resolveBooleanToggle(current: false))
        XCTAssertFalse(GenericSelectionStateResolver.resolveBooleanToggle(current: true))
    }

    func testBDD_GivenSortState_WhenTappingCurrentKey_ThenDirectionToggles() {
        let result = GenericSelectionStateResolver.resolveSortSelection(
            currentKey: "date",
            currentAscending: false,
            tappedKey: "date",
            defaultAscendingForTappedKey: true
        )
        XCTAssertEqual(result.key, "date")
        XCTAssertTrue(result.ascending)
    }

    func testBDD_GivenSortState_WhenTappingNewKey_ThenKeyChangesAndUsesProvidedDefaultDirection() {
        let result = GenericSelectionStateResolver.resolveSortSelection(
            currentKey: "date",
            currentAscending: false,
            tappedKey: "total",
            defaultAscendingForTappedKey: false
        )
        XCTAssertEqual(result.key, "total")
        XCTAssertFalse(result.ascending)
    }
}
