import XCTest
import AppKit
@testable import nolon

final class AppDelegateLifecycleTests: XCTestCase {
    func testBDD_GivenLastWindowClosed_WhenCheckingTerminationPolicy_ThenAppKeepsRunning() {
        let delegate = AppDelegate()

        let shouldTerminate = delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)

        XCTAssertFalse(shouldTerminate)
    }
}
