import SwiftUI

/// Remote Workflow 详情视图
struct RemoteWorkflowDetailView: View {
    let workflow: RemoteWorkflow
    let providers: [Provider]
    let targetProvider: Provider?
    let onInstall: (Provider) -> Void
    
    @State private var selectedProvider: Provider?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workflow.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let version = workflow.latestVersion {
                        HStack(spacing: 8) {
                            Label(version.version, systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let date = Date(timeIntervalSince1970: version.createdAt).formatted(date: .abbreviated, time: .omitted) as String? {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
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
                .padding()
            }
            
            Divider()
            
            // Footer - Install Button
            HStack {
                if let targetProvider = targetProvider {
                    Text("Install to: \(targetProvider.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .keyboardShortcut(.cancelAction)
                
                Button("Install") {
                    if let provider = targetProvider ?? selectedProvider {
                        onInstall(provider)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(targetProvider == nil && selectedProvider == nil)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}
