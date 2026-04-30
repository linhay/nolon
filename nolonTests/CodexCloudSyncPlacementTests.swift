import AppKit
import SwiftUI
import Testing
import ProviderCatalog
@testable import nolon

@MainActor
@Suite("Codex Cloud Sync Placement")
struct CodexCloudSyncPlacementTests {
    @Test("advanced config page hides iCloud sync settings when feature is off")
    func advancedConfigPageHidesCloudSyncSettingsWhenFeatureIsOff() {
        ProviderUsageRootViewModelStore.shared.clear()
        let provider = makeCodexProvider()

        let host = makeHost(
            CodexAdvancedConfigView(provider: provider)
        )

        #expect(allTextValues(in: host.view).contains("Cloud Sync") == false)
        #expect(allTextValues(in: host.view).contains("iCloud 同步") == false)
    }

    @Test("accounts page source no longer mounts iCloud sync card")
    func accountsPageSourceNoLongerMountsCloudSyncCard() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderUsageView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(
            source.contains(
                """
                if viewModel.capabilities.isCodexFamily {
                            codexManagementCard
                            codexAccountsSection
                """
            )
        )
        #expect(source.contains("codexCloudSyncCard") == false)
        #expect(source.contains("CodexCloudAttentionSheet") == false)
        #expect(source.contains("clearCloudData()") == false)
        #expect(source.contains("iCloud 已同步") == false)
    }

    private func makeCodexProvider() -> Provider {
        let root = URL(fileURLWithPath: "/tmp/nolon-cloud-sync-placement-\(UUID().uuidString)", isDirectory: true)
        let skills = root.appendingPathComponent("skills", isDirectory: true)
        let workflows = root.appendingPathComponent("workflows", isDirectory: true)
        try? FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: workflows, withIntermediateDirectories: true)
        return Provider(
            id: "codex-cloud-sync-placement-\(UUID().uuidString)",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: workflows.path,
            templateId: ProviderTemplate.codex.rawValue
        )
    }

    private func makeHost(_ view: some View) -> NSHostingController<AnyView> {
        let size = CGSize(width: 960, height: 900)
        let rootView = AnyView(
            view
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, .light)
        )

        let host = NSHostingController(rootView: rootView)
        host.view.frame = NSRect(origin: .zero, size: size)
        host.view.appearance = NSAppearance(named: .aqua)
        host.view.layoutSubtreeIfNeeded()
        return host
    }

    private func allTextValues(in root: NSView) -> [String] {
        var results: [String] = []
        if let label = root as? NSTextField {
            results.append(label.stringValue)
        }
        for child in root.subviews {
            results.append(contentsOf: allTextValues(in: child))
        }
        return results
    }
}
