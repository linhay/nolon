import SwiftUI
import Observation
import NolonResourceKit
import AppKit

@MainActor
@Observable
final class PluginManagementViewModel {
    struct PluginItem: Identifiable, Equatable {
        let id: String
        let name: String
        let installedVersion: String?
        let latestVersion: String?
        let hasUpgrade: Bool
        let releaseURL: URL
    }

    var isChecking = false
    var plugin: PluginItem?
    var errorMessage: String?

    private let releaseChecker: XcodeMCPKitReleaseChecker
    private let installedVersionProvider: @Sendable () -> String?
    private let releaseRootURL = URL(string: "https://github.com/linhay/XcodeMCPKit/releases")!

    init(
        releaseChecker: XcodeMCPKitReleaseChecker = XcodeMCPKitReleaseChecker(),
        installedVersionProvider: (@Sendable () -> String?)? = nil
    ) {
        self.releaseChecker = releaseChecker
        self.installedVersionProvider = installedVersionProvider ?? { Self.defaultInstalledVersion() }
    }

    func load() async {
        isChecking = true
        defer { isChecking = false }

        let installed = installedVersionProvider()
        let status = await releaseChecker.checkUpgrade(installedVersion: installed)
        plugin = PluginItem(
            id: "xcodemcpkit",
            name: "XcodeMCPKit",
            installedVersion: installed,
            latestVersion: status.latestVersion,
            hasUpgrade: status.hasUpgrade,
            releaseURL: status.releaseURL ?? releaseRootURL
        )
    }

    nonisolated private static func defaultInstalledVersion() -> String? {
        let versionFile = NolonManager.shared
            .rootURL
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("xcodemcpkit", isDirectory: true)
            .appendingPathComponent("installed_version.txt", isDirectory: false)
        guard let data = try? Data(contentsOf: versionFile),
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }
}

struct PluginManagementView: View {
    @State private var viewModel = PluginManagementViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isChecking {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let plugin = viewModel.plugin {
                    pluginCard(plugin)
                } else if !viewModel.isChecking {
                    ContentUnavailableView(
                        NSLocalizedString("plugin.empty.title", value: "No Plugin", comment: "No plugin title"),
                        systemImage: "puzzlepiece",
                        description: Text(
                            NSLocalizedString("plugin.empty.desc", value: "No available plugins.", comment: "No plugin description")
                        )
                        .dsSecondaryText(font: .body)
                    )
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .dsSecondaryText(font: .callout)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func pluginCard(_ plugin: PluginManagementViewModel.PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(plugin.name, systemImage: "puzzlepiece.extension")
                    .font(.headline)
                Spacer(minLength: 0)
                if plugin.hasUpgrade {
                    Button(
                        NSLocalizedString("plugin.action.upgrade", value: "Upgrade", comment: "Upgrade plugin")
                    ) {
                        NSWorkspace.shared.open(plugin.releaseURL)
                    }
                    .dsPrimaryButton()
                } else {
                    Button(
                        NSLocalizedString("plugin.action.open_release", value: "Open Releases", comment: "Open plugin releases")
                    ) {
                        NSWorkspace.shared.open(plugin.releaseURL)
                    }
                    .dsLinkButton()
                }
            }

            HStack(spacing: 14) {
                Text("Installed: \(plugin.installedVersion ?? "-")")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text("Latest: \(plugin.latestVersion ?? "-")")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }
}
