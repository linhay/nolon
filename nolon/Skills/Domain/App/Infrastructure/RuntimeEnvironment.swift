import Foundation

enum RuntimeEnvironment {
    static func isSwiftUIPreview(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isUITestModeEnabled: Bool = UITestSupport.isEnabled
    ) -> Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" && !isUITestModeEnabled
    }
}
