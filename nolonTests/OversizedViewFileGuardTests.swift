import XCTest

final class OversizedViewFileGuardTests: XCTestCase {
    func test_selected_refactored_files_stay_under_2000_lines() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let targets = [
            "nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderUsageView.swift",
            "nolon/Skills/Domain/Providers/Views/CodexAdvancedConfigView.swift",
            "nolon/Skills/Domain/Providers/Views/CodexAdvancedConfigSupport.swift",
            "libs/NolonUI/Sources/NolonUI/Components/UnifiedDomainCardViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/AccountCard/UnifiedAccountCardComponents.swift",
            "libs/NolonUI/Sources/NolonUI/Components/UnifiedResourceCardViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/AccountCard/UnifiedCodexCompactAccountComponents.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Remote/UnifiedRemoteComponents.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Remote/UnifiedRemoteCatalogViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Remote/UnifiedResourceInstallStateViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderSharedViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSharedViews.swift",
            "libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexRuntimeViews.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIPayloads.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCLIEntrypoint.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIRuntimeSupport.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCoreCLIRunner.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCoreCLIRunner+Gemini.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCoreCLIRunner+Plugin.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCoreCLIRunner+ResourceOperations.swift",
            "libs/Providers/Sources/NolonCoreCLIKit/NolonCoreCLIRunner+ResourcePresentation.swift",
            "libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift",
            "libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift",
            "libs/Providers/Sources/ProviderUsage/CodexAuthManager+ImportValidation.swift",
            "libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift",
            "libs/Providers/Sources/ProviderUsage/CodexAuthManager+SQLite.swift",
            "nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift",
            "nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexManagement.swift",
            "nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexLogin.swift",
            "nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift",
        ]

        let overLimit = try targets.compactMap { relativePath -> String? in
            let fileURL = root.appendingPathComponent(relativePath)
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lineCount = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            return lineCount > 2000 ? "\(relativePath) (\(lineCount))" : nil
        }

        XCTAssertTrue(
            overLimit.isEmpty,
            "These refactored files still exceed 2000 lines: \(overLimit.joined(separator: ", "))"
        )
    }
}
