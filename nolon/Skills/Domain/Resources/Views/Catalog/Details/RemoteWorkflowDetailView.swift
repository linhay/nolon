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

        if let description = RemoteResourceDetailBuilders.descriptionSection(summary: workflow.summary) {
            sections.append(description)
        }

        if let changelog = RemoteResourceDetailBuilders.changelogSection(changelog: workflow.latestVersion?.changelog) {
            sections.append(changelog)
        }

        var stats: [RemoteResourceDetailData.StatItem] = []
        if let values = workflow.stats {
            stats.append(contentsOf: RemoteResourceDetailBuilders.commonStats(stars: values.stars, downloads: values.downloads))
            if let usages = values.usages {
                stats.append(RemoteResourceDetailBuilders.usagesStat(usages))
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
        return RemoteResourceDetailBuilders.versionSubtitle(version: version.version, createdAt: version.createdAt)
    }
}
