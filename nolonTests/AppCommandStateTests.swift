import XCTest
@testable import nolon

@MainActor
final class AppCommandStateTests: XCTestCase {
    func testBDD_GivenDebugPageMarkersEnabled_WhenStateIsRecreated_ThenPersistsPreviousSelection() {
        let suiteName = "AppCommandStateTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create isolated user defaults suite")
            return
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let firstState = AppCommandState(userDefaults: userDefaults)
        XCTAssertFalse(firstState.isDebugPageMarkersEnabled)

        firstState.isDebugPageMarkersEnabled = true

        let recreatedState = AppCommandState(userDefaults: userDefaults)
        XCTAssertTrue(recreatedState.isDebugPageMarkersEnabled)
    }
}
