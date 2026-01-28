import SwiftUI

/// Remote MCP 详情视图
struct RemoteMCPDetailView: View {
    let mcp: RemoteMCP
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
                    Text(mcp.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let version = mcp.latestVersion {
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
                    if let summary = mcp.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Configuration
                    if let config = mcp.configuration {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Configuration")
                                .font(.headline)
                            
                            if let command = config.command {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Command")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(command)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            
                            if let args = config.args, !args.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Arguments")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(args, id: \.self) { arg in
                                            Text("• \(arg)")
                                                .font(.system(.caption, design: .monospaced))
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                            
                            if let env = config.env, !env.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Environment Variables")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(Array(env.keys.sorted()), id: \.self) { key in
                                            if let value = env[key] {
                                                Text("\(key)=\(value)")
                                                    .font(.system(.caption, design: .monospaced))
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Stats
                    if let stats = mcp.stats {
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
                                if let installs = stats.installs {
                                    Label("\(installs) Installs", systemImage: "server.rack")
                                }
                            }
                            .font(.callout)
                        }
                    }
                    
                    // Changelog
                    if let changelog = mcp.latestVersion?.changelog {
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
