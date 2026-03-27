import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

struct RemoteMCPDetailView: View {
    let mcp: RemoteMCP
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

        if let description = RemoteResourceDetailBuilders.descriptionSection(summary: mcp.summary) {
            sections.append(description)
        }

        if let config = mcp.configuration {
            if let command = config.command, !command.isEmpty {
                sections.append(.codeBlock(id: "command", title: "Command", content: command))
            }
            if let args = config.args, !args.isEmpty {
                sections.append(.list(id: "args", title: "Arguments", items: args, monospaced: true))
            }
            if let env = config.env, !env.isEmpty {
                let envItems = env.keys.sorted().compactMap { key -> String? in
                    guard let value = env[key] else { return nil }
                    return "\(key)=\(value)"
                }
                sections.append(.kvList(id: "env", title: "Environment Variables", items: envItems, monospaced: true))
            }
        }

        if let changelog = RemoteResourceDetailBuilders.changelogSection(changelog: mcp.latestVersion?.changelog) {
            sections.append(changelog)
        }

        var stats: [RemoteResourceDetailData.StatItem] = []
        if let values = mcp.stats {
            stats.append(contentsOf: RemoteResourceDetailBuilders.commonStats(stars: values.stars, downloads: values.downloads))
            if let installs = values.installs {
                stats.append(RemoteResourceDetailBuilders.installsStat(installs))
            }
        }

        return .init(
            title: mcp.displayName,
            subtitle: versionSubtitle,
            stats: stats,
            sections: sections,
            providers: providers.map { .init(id: $0.id, name: $0.name, iconName: $0.iconName) },
            preferredProviderID: targetProvider?.id
        )
    }

    private var versionSubtitle: String? {
        guard let version = mcp.latestVersion else { return nil }
        return RemoteResourceDetailBuilders.versionSubtitle(version: version.version, createdAt: version.createdAt)
    }
}
