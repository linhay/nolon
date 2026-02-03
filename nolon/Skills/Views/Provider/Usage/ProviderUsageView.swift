import SwiftUI
import ProviderCatalog
import Observation
import WebKit
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
@Observable
final class ProviderUsageViewModel {
    private let service = UsageMonitorService()
    private let settingsStore = UsageMonitorSettingsStore.shared

    let provider: Provider
    let usageProvider: UsageProvider?

    var settings: UsageMonitorProviderSettings
    var supportedSourceModes: [ProviderSourceMode] = []

    var isLoading = false
    var outcomes: [ProviderAccountUsageOutcome] = []

    var isShowingLogin = false

    init(provider: Provider) {
        self.provider = provider
        self.usageProvider = ProviderUsageViewModel.mapToUsageProvider(provider)
        self.settings = settingsStore.settings(for: provider)
        self.updateSupportedModes()
    }

    func updateSettings(_ newSettings: UsageMonitorProviderSettings) {
        settings = newSettings
        settingsStore.update(settings: newSettings, for: provider)
    }

    func load() async {
        guard let usageProvider else { return }

        isLoading = true
        defer { isLoading = false }

        outcomes = await service.fetchOutcomes(provider: usageProvider, settings: settings)
    }

    private func updateSupportedModes() {
        guard let usageProvider else { return }
        supportedSourceModes = ProviderUsageRegistry.fetchPlan(for: usageProvider).sourceModes
            .sorted(by: { $0.rawValue < $1.rawValue })
        if !supportedSourceModes.contains(settings.sourceMode) {
            updateSettings(UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: settings.includeCredits,
                webTimeoutSeconds: settings.webTimeoutSeconds))
        }
    }

    private static func mapToUsageProvider(_ provider: Provider) -> UsageProvider? {
        if let templateId = provider.templateId, let mapped = UsageProvider(rawValue: templateId) {
            return mapped
        }
        return nil
    }

    var dashboardURL: URL? {
        guard let usageProvider else { return nil }
        guard let raw = ProviderUsageRegistry.metadata(for: usageProvider)?.dashboardURL else { return nil }
        return URL(string: raw)
    }
}

struct ProviderUsageView: View {
    let provider: Provider
    let isEmbedded: Bool
    @State private var viewModel: ProviderUsageViewModel

    init(provider: Provider, isEmbedded: Bool = false) {
        self.provider = provider
        self.isEmbedded = isEmbedded
        self._viewModel = State(initialValue: ProviderUsageViewModel(provider: provider))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.usageProvider == nil {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.unsupported.title", value: "Usage not supported", comment: "Unsupported title"),
                    systemImage: "chart.bar.xaxis",
                    description: Text(NSLocalizedString(
                        "usage.monitor.unsupported.desc",
                        value: "Usage is not configured for this provider yet.",
                        comment: "Unsupported description"
                    ))
                )
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.outcomes.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"),
                    systemImage: "chart.bar",
                    description: Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.outcomes) { outcome in
                            ProviderUsageSnapshotView(outcome: outcome)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        }
        .if(!isEmbedded) { view in
            view.navigationTitle(NSLocalizedString("tab.usage", value: "Usage", comment: "Usage"))
        }
        .task(id: provider.id) {
            await viewModel.load()
        }
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: Bindable(viewModel).isShowingLogin) {
            UsageLoginSheet(title: provider.name, url: viewModel.dashboardURL)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(provider.name)
                .font(.headline)

            Spacer()

            Button(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")) {
                Task { await viewModel.load() }
            }

            Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                viewModel.isShowingLogin = true
            }
        }
        .onChange(of: viewModel.settings) { _, newValue in
            viewModel.updateSettings(newValue)
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private extension ProviderSourceMode {
    var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("usage.monitor.source_mode.auto", value: "Auto", comment: "Auto")
        case .cli: return NSLocalizedString("usage.monitor.source_mode.cli", value: "CLI", comment: "CLI")
        case .web: return NSLocalizedString("usage.monitor.source_mode.web", value: "Web", comment: "Web")
        case .oauth: return NSLocalizedString("usage.monitor.source_mode.oauth", value: "OAuth", comment: "OAuth")
        case .apiToken: return NSLocalizedString("usage.monitor.source_mode.api_token", value: "API token", comment: "API token")
        case .localProbe: return NSLocalizedString("usage.monitor.source_mode.local_probe", value: "Local probe", comment: "Local probe")
        case .webDashboard: return NSLocalizedString("usage.monitor.source_mode.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        }
    }
}

private struct UsageLoginSheet: View {
    let title: String
    let url: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(NSLocalizedString("common.done", value: "Done", comment: "Done")) {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if let url {
                ProviderLoginWebView(url: url)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in"),
                    systemImage: "globe",
                    description: Text(NSLocalizedString("usage.monitor.unsupported.desc", value: "Usage is not configured for this provider yet.", comment: "Unsupported"))
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

private struct ProviderLoginWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
