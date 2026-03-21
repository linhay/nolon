import XCTest
@testable import nolon

final class RuntimeEnvironmentTests: XCTestCase {
    func testBDD_GivenPreviewEnvironmentWithoutUITest_WhenResolvingRuntimeMode_ThenReturnsTrue() {
        let environment = ["XCODE_RUNNING_FOR_PREVIEWS": "1"]

        let isPreviewMode = RuntimeEnvironment.isSwiftUIPreview(environment: environment, isUITestModeEnabled: false)

        XCTAssertTrue(isPreviewMode)
    }

    func testBDD_GivenPreviewEnvironmentWithUITest_WhenResolvingRuntimeMode_ThenReturnsFalse() {
        let environment = [
            "XCODE_RUNNING_FOR_PREVIEWS": "1",
            "NOLON_UI_TEST_MODE": "1"
        ]

        let isPreviewMode = RuntimeEnvironment.isSwiftUIPreview(environment: environment, isUITestModeEnabled: true)

        XCTAssertFalse(isPreviewMode)
    }

    func testBDD_GivenNormalEnvironment_WhenResolvingRuntimeMode_ThenReturnsFalse() {
        let environment = ["PATH": "/usr/bin:/bin"]

        let isPreviewMode = RuntimeEnvironment.isSwiftUIPreview(environment: environment, isUITestModeEnabled: false)

        XCTAssertFalse(isPreviewMode)
    }
}
