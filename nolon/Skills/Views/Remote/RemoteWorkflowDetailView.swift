import SwiftUI
import ProviderCatalog

/// Remote Workflow 详情视图
struct RemoteWorkflowDetailView: View {
    let workflow: RemoteWorkflow
    let providers: [Provider]
    let targetProvider: Provider?
    let onInstall: (Provider) -> Void
    
    @State private var selectedProvider: Provider?
    @Environment(\.dismiss) private var dismiss

    private var workflowSubtitle: String? {
        guard let version = workflow.latestVersion else { return nil }
        let date = Date(timeIntervalSince1970: version.createdAt)
            .formatted(date: .abbreviated, time: .omitted)
        if date.isEmpty {
            return version.version
        }
        return "\(version.version) • \(date)"
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: workflow.displayName,
                subtitle: workflowSubtitle
            ) {
                dismiss()
            }

            SheetDivider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    if let summary = workflow.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Stats
                    if let stats = workflow.stats {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Statistics")
                                .font(.headline)
                            
                            HStack(spacing: 20) {
                                if let stars = stats.stars {
                                    Label("\(stars) Stars", systemImage: "star.fill")
                                        .foregroundStyle(.yellow)
                                }
                                if let downloads = stats.downloads {
                                    Label("\(downloads) Downloads", systemImage: "arrow.down.circle")
                                }
                                if let usages = stats.usages {
                                    Label("\(usages) Usages", systemImage: "arrow.triangle.branch")
                                }
                            }
                            .font(.callout)
                        }
                    }
                    
                    // Changelog
                    if let changelog = workflow.latestVersion?.changelog {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Changelog")
                                .font(.headline)
                            Text(changelog)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, SheetLayout.horizontalPadding)
                .padding(.vertical, SheetLayout.contentVerticalPadding)
            }
            
            SheetDivider()
            
            // Footer - Install Button
            HStack {
                if let targetProvider = targetProvider {
                    Text("Install to: \(targetProvider.name)")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                } else {
                    Picker("Install to:", selection: $selectedProvider) {
                        Text("Select Provider").tag(nil as Provider?)
                        ForEach(providers) { provider in
                            Text(provider.name).tag(provider as Provider?)
                        }
                    }
                    .labelsHidden()
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button("Install") {
                    if let provider = targetProvider ?? selectedProvider {
                        onInstall(provider)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(targetProvider == nil && selectedProvider == nil)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
    }
}
