import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

struct RemoteWorkflowDetailView: View {
    let workflow: RemoteWorkflow
    let providers: [Provider]
    let targetProvider: Provider?
    let onInstall: (Provider) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NolonUI.RemoteResourceDetailSheetView(
            data: detailData,
            onInstall: { providerID in
                guard let provider = providers.first(where: { $0.id == providerID }) else { return }
                onInstall(provider)
            },
            onClose: { dismiss() }
        )
    }

    private var detailData: RemoteResourceDetailData {
        var sections: [RemoteResourceDetailData.Section] = []

        if let summary = workflow.summary, !summary.isEmpty {
            sections.append(.markdown(id: "summary", title: "Description", content: summary))
        }

        if let changelog = workflow.latestVersion?.changelog, !changelog.isEmpty {
            sections.append(.markdown(id: "changelog", title: "Changelog", content: changelog))
        }

        var stats: [RemoteResourceDetailData.StatItem] = []
        if let values = workflow.stats {
            if let stars = values.stars {
                stats.append(.init(id: "stars", title: "\(stars) Stars", systemImage: "star.fill"))
            }
            if let downloads = values.downloads {
                stats.append(.init(id: "downloads", title: "\(downloads) Downloads", systemImage: "arrow.down.circle"))
            }
            if let usages = values.usages {
                stats.append(.init(id: "usages", title: "\(usages) Usages", systemImage: "arrow.triangle.branch"))
            }
        }

        return .init(
            title: workflow.displayName,
            subtitle: versionSubtitle,
            stats: stats,
            sections: sections,
            providers: providers.map { .init(id: $0.id, name: $0.name, iconName: $0.iconName) },
            preferredProviderID: targetProvider?.id
        )
    }

    private var versionSubtitle: String? {
        guard let version = workflow.latestVersion else { return nil }
        let date = Date(timeIntervalSince1970: version.createdAt).formatted(date: .abbreviated, time: .omitted)
        return date.isEmpty ? version.version : "\(version.version) • \(date)"
    }
}
