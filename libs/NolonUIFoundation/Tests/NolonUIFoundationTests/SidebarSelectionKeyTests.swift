import XCTest
@testable import NolonUIFoundation

final class SidebarSelectionKeyTests: XCTestCase {
    func testSelectionKey_RoundTripProvider() {
        let key = SidebarSelectionKey.provider("abc")
        XCTAssertEqual(key.rawValue, "provider:abc")
        XCTAssertEqual(SidebarSelectionKey(rawValue: key.rawValue).itemID, .provider("abc"))
    }

    func testSelectionKey_RoundTripTools() {
        XCTAssertEqual(SidebarSelectionKey.accounts.rawValue, "accounts")
        XCTAssertEqual(SidebarSelectionKey(rawValue: "accounts").itemID, .tool(.accounts))

        XCTAssertEqual(SidebarSelectionKey.pluginManagement.rawValue, "pluginManagement")
        XCTAssertEqual(SidebarSelectionKey(rawValue: "pluginManagement").itemID, .tool(.pluginManagement))
    }
}
