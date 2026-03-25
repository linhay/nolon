import XCTest
import AppKit
@testable import nolon

final class AppDelegateLifecycleTests: XCTestCase {
    func testBDD_GivenLastWindowClosed_WhenCheckingTerminationPolicy_ThenAppKeepsRunning() {
        let delegate = AppDelegate()

        let shouldTerminate = delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)

        XCTAssertFalse(shouldTerminate)
    }

    func testBDD_GivenAppTermination_WhenCheckingStateSavePolicy_ThenAppStateDoesNotPersist() {
        let delegate = AppDelegate()

        let shouldSaveState = delegate.applicationShouldSaveApplicationState(NSApplication.shared)

        XCTAssertFalse(shouldSaveState)
    }

    func testBDD_GivenAppLaunch_WhenCheckingStateRestorePolicy_ThenPreviousWindowsAreNotRestored() {
        let delegate = AppDelegate()

        let shouldRestoreState = delegate.applicationShouldRestoreApplicationState(NSApplication.shared)

        XCTAssertFalse(shouldRestoreState)
    }
}
