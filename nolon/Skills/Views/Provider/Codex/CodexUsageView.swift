import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class CodexUsageViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexUsageViewModel")

    var range: CodexUsageTimeRange = .last7Days
    var summary: CodexUsageSummary?
    var isLoading = false
    var errorMessage: String?

    private let dbURL: URL
    private let repository: CodexStateUsageRepository

    init(dbURL: URL, repository: CodexStateUsageRepository = CodexStateUsageRepository()) {
        self.dbURL = dbURL
        self.repository = repository
    }

    var dbExists: Bool {
        FileManager.default.fileExists(atPath: dbURL.path)
    }

    func load() async {
        errorMessage = nil
        guard dbExists else {
            summary = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            summary = try repository.fetchUsage(dbURL: dbURL, range: range)
        } catch {
            Self.logger.error("Failed to load Codex usage: \(error.localizedDescription)")
            errorMessage = NSLocalizedString("codex.usage.error.load", value: "Failed to load usage from Codex state.sqlite.", comment: "Error message")
            summary = nil
        }
    }
}

struct CodexUsageView: View {
    let provider: Provider
    @State private var viewModel: CodexUsageViewModel

    init(provider: Provider) {
        self.provider = provider
        let codexHomeURL = CodexPaths.codexHomeURL(for: provider) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
        let dbURL = CodexPaths.stateDbURL(codexHomeURL: codexHomeURL)
        self._viewModel = State(initialValue: CodexUsageViewModel(dbURL: dbURL))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controls

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.dbExists {
                ContentUnavailableView(
                    NSLocalizedString("codex.usage.no_db.title", value: "No usage data", comment: "No DB title"),
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text(NSLocalizedString("codex.usage.no_db.desc", value: "Codex state.sqlite was not found in your Codex home directory.", comment: "No DB description"))
                )
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    NSLocalizedString("codex.usage.error.title", value: "Failed to load usage", comment: "Error title"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let summary = viewModel.summary {
                usageSummary(summary)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("codex.usage.empty.title", value: "No usage", comment: "Empty title"),
                    systemImage: "chart.bar",
                    description: Text(NSLocalizedString("codex.usage.empty.desc", value: "No threads found for the selected time range.", comment: "Empty description"))
                )
            }
        }
        .navigationTitle(NSLocalizedString("codex.usage.title", value: "Usage", comment: "Codex usage title"))
        .task(id: provider.id) {
            await viewModel.load()
        }
        .onChange(of: viewModel.range) { _, _ in
            Task { await viewModel.load() }
        }
    }

    private var controls: some View {
        HStack {
            Text(NSLocalizedString("codex.usage.range.label", value: "Range", comment: "Range label"))
                .foregroundStyle(.secondary)
            Picker("", selection: $viewModel.range) {
                ForEach(CodexUsageTimeRange.allCases) { range in
                    Text(range.localizedTitle).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Spacer()
        }
    }

    private func usageSummary(_ summary: CodexUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("codex.usage.total.tokens", value: "Total tokens", comment: "Total tokens label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.tokens)")
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("codex.usage.total.threads", value: "Threads", comment: "Threads label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.threads)")
                        .font(.title2)
                }

                Spacer()
            }

            GroupBox(NSLocalizedString("codex.usage.projects.title", value: "Top projects", comment: "Top projects title")) {
                if summary.projects.isEmpty {
                    Text(NSLocalizedString("codex.usage.projects.empty", value: "No projects found.", comment: "No projects"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(summary.projects.prefix(20)) { project in
                            HStack {
                                Text(project.cwd)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(project.tokens)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
