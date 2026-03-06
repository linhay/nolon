import Foundation
import NolonResourceKit

enum UITestSupport {
    private static let environment = ProcessInfo.processInfo.environment

    static var isEnabled: Bool {
        environment["NOLON_UI_TEST_MODE"] == "1"
    }

    static var shouldSkipOnboarding: Bool {
        isEnabled || environment["NOLON_UI_TEST_SKIP_ONBOARDING"] == "1"
    }

    static var shouldOpenResourceCenterOnLaunch: Bool {
        environment["NOLON_UI_TEST_OPEN_RESOURCE_CENTER"] == "1"
    }

    static var initialRepositoryTemplate: RepositoryTemplate? {
        guard let raw = environment["NOLON_UI_TEST_RESOURCE_REPOSITORY"] else { return nil }
        return RepositoryTemplate(rawValue: raw)
    }

    static var initialSearchQuery: String? {
        guard let raw = environment["NOLON_UI_TEST_RESOURCE_SEARCH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }

    static var shouldExposeDirectDeleteButton: Bool {
        environment["NOLON_UI_TEST_DIRECT_DELETE"] == "1"
    }

    static var shouldAutoConfirmDelete: Bool {
        environment["NOLON_UI_TEST_AUTO_CONFIRM_DELETE"] == "1"
    }

    static var fixtureGlobalSkillSlug: String? {
        guard let raw = environment["NOLON_UI_TEST_FIXTURE_GLOBAL_SKILL_SLUG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }
}
