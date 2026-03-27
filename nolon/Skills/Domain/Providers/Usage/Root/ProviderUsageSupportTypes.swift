import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import Foundation
import NolonUIFoundation

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension ProviderSourceMode {
    var displayName: String {
        switch self {
        case .auto: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "auto")
        case .cli: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "cli")
        case .web: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "web")
        case .oauth: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "oauth")
        case .apiToken: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "apiToken")
        case .localProbe: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "localProbe")
        case .webDashboard: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "webDashboard")
        }
    }
}

enum UsageAutoRefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case twoHours = 120
    case fiveHours = 300

    var id: Int { rawValue }

    var title: String {
        ProviderUsageTextBuilders.autoRefreshTitle(minutes: rawValue)
    }
}

typealias UsageIssueCode = ProviderUsageIssueCode

enum UsageIssueClassifier {
    static func classify(provider: UsageProvider, error: Error) -> UsageIssueCode {
        ProviderUsageIssueClassifier.classify(
            providerID: provider.rawValue,
            errorText: error.localizedDescription,
            usageErrorCode: usageErrorCode(from: error)
        )
    }

    static func hints(provider: UsageProvider, code: UsageIssueCode) -> [String] {
        ProviderUsageIssueClassifier.hints(providerID: provider.rawValue, code: code)
    }

    static func isGeminiFamily(provider: UsageProvider) -> Bool {
        ProviderUsageIssueClassifier.isGeminiFamily(providerID: provider.rawValue)
    }

    private static func usageErrorCode(from error: Error) -> String? {
        guard let usageError = error as? ProviderUsageError else {
            return nil
        }

        switch usageError {
        case .unsupported:
            return "unsupported"
        case .missingToken:
            return "missingToken"
        case .missingAccount:
            return "missingAccount"
        case .authExpired:
            return "authExpired"
        }
    }
}
