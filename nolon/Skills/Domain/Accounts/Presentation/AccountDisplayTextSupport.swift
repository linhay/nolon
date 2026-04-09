import Foundation
import ProviderUsage
import NolonUIFoundation

enum AccountDisplayTextSupport {
    static func title(primary: String?, fallback: String) -> String {
        TextNormalizationSupport.firstNonEmpty(primary, fallback) ?? fallback
    }

    static func subtitle(_ values: String?...) -> String? {
        TextNormalizationSupport.joinedNonEmpty(values)
    }

    static func codexTitle(
        summary: CodexAuthSummary?,
        relativeAuthPath: String?,
        defaultName: String,
        accountID: UUID?
    ) -> String {
        ProviderUsageAccountDisplayNameResolver.resolve(
            email: summary?.email,
            summaryAccountID: summary?.accountID,
            cardKind: summary?.cardKind?.rawValue,
            apiKeySuffix: summary?.apiKeySuffix,
            relayModelProvider: summary?.relayModelProvider,
            relayBaseURL: summary?.relayBaseURL,
            relativeAuthPath: relativeAuthPath,
            defaultName: defaultName,
            accountID: accountID
        )
    }

    static func codexSubtitle(title: String, email: String?, plan: String?) -> String? {
        let normalizedTitle = TextNormalizationSupport.trimmed(title)
        let normalizedEmail = TextNormalizationSupport.trimmed(email)
        return TextNormalizationSupport.joinedNonEmpty([
            (normalizedEmail != normalizedTitle) ? normalizedEmail : nil,
            plan,
        ])
    }

    static func codexSnapshotLabel(summary: CodexAuthSummary?, account: CodexAuthAccount) -> String {
        codexTitle(
            summary: summary,
            relativeAuthPath: account.relativeAuthPath,
            defaultName: account.name,
            accountID: account.id
        )
    }
}
