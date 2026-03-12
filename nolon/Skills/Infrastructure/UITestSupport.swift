import Foundation
import NolonResourceKit

enum UITestSupport {
    static var environmentOverride: [String: String]?

    private static var environment: [String: String] {
        environmentOverride ?? ProcessInfo.processInfo.environment
    }

    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

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

    static var initialResourceTab: ResourceContentTabType? {
        guard let raw = environment["NOLON_UI_TEST_RESOURCE_TAB"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }
        switch raw {
        case "skills":
            return .skills
        case "workflows":
            return .workflows
        case "mcps":
            return .mcps
        default:
            return nil
        }
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

    static var fixtureGlobalWorkflowSlug: String? {
        guard let raw = environment["NOLON_UI_TEST_FIXTURE_GLOBAL_WORKFLOW_SLUG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    static var fixtureGlobalMCPSlug: String? {
        guard let raw = environment["NOLON_UI_TEST_FIXTURE_GLOBAL_MCP_SLUG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    static var fixtureProviderSkillSlug: String? {
        guard let raw = environment["NOLON_UI_TEST_FIXTURE_PROVIDER_SKILL_SLUG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    static var initialSelectedProviderIndex: Int? {
        guard let raw = environment["NOLON_UI_TEST_SELECTED_PROVIDER_INDEX"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Int(raw),
              value >= 0 else {
            return nil
        }
        return value
    }

    static var initialSelectedProviderTab: ProviderContentTabType? {
        guard let raw = environment["NOLON_UI_TEST_SELECTED_PROVIDER_TAB"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return ProviderContentTabType(vendorTabId: raw) ?? ProviderContentTabType(rawValue: raw)
    }
}
