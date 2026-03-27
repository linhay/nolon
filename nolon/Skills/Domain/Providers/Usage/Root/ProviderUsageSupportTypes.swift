import SwiftUI
import ProviderUsage
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
