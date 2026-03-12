import XCTest
import AppKit
import ApplicationServices
import NolonResourceKit
@testable import nolon

@MainActor
final class GlobalSkillDeletionAXTests: XCTestCase {
    private var fixture: TestFixture!
    private var appProcess: Process?

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        appProcess?.terminate()
        appProcess = nil
        fixture.cleanup()
    }

    func testBDD_GivenGlobalSkill_WhenDeleteThroughUI_ThenGlobalCacheFolderIsRemoved() async throws {
        try XCTSkipUnless(AXIsProcessTrusted(), "Accessibility permission is required for UI-driven integration tests.")

        let source = try fixture.createSampleSkill(id: "gemini", name: "Gemini")
        let repository = SkillRepository(nolonManager: fixture.nolonManager)
        _ = try repository.importSkill(from: source)

        let skillPath = fixture.nolonManager.skillsURL.appendingPathComponent("gemini")
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillPath.path))

        let process = try launchApp()
        appProcess = process

        let app = try waitForApplication(pid: process.processIdentifier)
        try waitForWindow(in: app)

        let deleteButton = try waitForElement(
            in: app,
            description: "direct delete button",
            timeout: 15
        ) { element in
            let identifier: String? = self.attribute(kAXIdentifierAttribute, of: element)
            return identifier == "uitest.direct-delete.skill.gemini"
        }

        try click(deleteButton)

        let removed = try waitUntil(timeout: 15) {
            !FileManager.default.fileExists(atPath: skillPath.path)
        }
        XCTAssertTrue(removed)
    }

    private func launchApp() throws -> Process {
        let process = Process()
        process.executableURL = appExecutableURL()

        var environment = ProcessInfo.processInfo.environment
        environment["NOLON_HOME"] = fixture.tempRoot.path
        environment["NOLON_UI_TEST_MODE"] = "1"
        environment["NOLON_UI_TEST_SKIP_ONBOARDING"] = "1"
        environment["NOLON_UI_TEST_OPEN_RESOURCE_CENTER"] = "1"
        environment["NOLON_UI_TEST_RESOURCE_REPOSITORY"] = RepositoryTemplate.globalSkills.rawValue
        environment["NOLON_UI_TEST_RESOURCE_SEARCH"] = "gemini"
        environment["NOLON_UI_TEST_DIRECT_DELETE"] = "1"
        environment["NOLON_UI_TEST_AUTO_CONFIRM_DELETE"] = "1"
        environment["XCODE_RUNNING_FOR_PREVIEWS"] = "1"
        process.environment = environment

        try process.run()
        return process
    }

    private func appExecutableURL() -> URL {
        let testBundleURL = Bundle(for: Self.self).bundleURL
        let appBundleURL = testBundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return appBundleURL
            .appendingPathComponent("Contents/MacOS")
            .appendingPathComponent("nolon")
    }

    private func waitForApplication(pid: pid_t, timeout: TimeInterval = 10) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let runningApp = NSRunningApplication(processIdentifier: pid) {
                runningApp.activate(options: [.activateAllWindows])
                return AXUIElementCreateApplication(pid)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        throw XCTSkip("App failed to launch in time.")
    }

    private func waitForWindow(in app: AXUIElement, timeout: TimeInterval = 10) throws {
        let found = try waitUntil(timeout: timeout) {
            let windows: [AXUIElement] = self.attribute(kAXWindowsAttribute, of: app) ?? []
            return !windows.isEmpty
        }
        XCTAssertTrue(found, "App window did not appear in time.")
    }

    private func waitForElement(
        in app: AXUIElement,
        description: String,
        timeout: TimeInterval,
        predicate: (AXUIElement) -> Bool
    ) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let element = descendants(of: app).first(where: predicate) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("Timed out waiting for \(description).")
        return AXUIElementCreateSystemWide()
    }

    private func descendants(of root: AXUIElement) -> [AXUIElement] {
        var queue: [AXUIElement] = [root]
        var visited = Set<String>()
        var result: [AXUIElement] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let key = "\(Unmanaged.passUnretained(current).toOpaque())"
            if visited.contains(key) { continue }
            visited.insert(key)
            result.append(current)
            let children: [AXUIElement] = attribute(kAXChildrenAttribute, of: current) ?? []
            queue.append(contentsOf: children)
        }

        return result
    }

    private func click(_ element: AXUIElement) throws {
        if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            return
        }

        guard let center = center(of: element) else {
            XCTFail("Element is not clickable.")
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func center(of element: AXUIElement) -> CGPoint? {
        guard
            let positionValue: AXValue = copyAXValue(kAXPositionAttribute, of: element),
            let sizeValue: AXValue = copyAXValue(kAXSizeAttribute, of: element)
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &position)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
    }

    private func copyAXValue(_ name: String, of element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }

    private func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else {
            return nil
        }
        return value as? T
    }

    private func waitUntil(timeout: TimeInterval, pollInterval: TimeInterval = 0.1, condition: () -> Bool) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }
}
