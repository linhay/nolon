import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI

/// Remote MCP 详情视图
struct RemoteMCPDetailView: View {
    let mcp: RemoteMCP
    let providers: [Provider]
    let targetProvider: Provider?
    let onInstall: (Provider) -> Void
    
    @State private var selectedProvider: Provider?
    @Environment(\.dismiss) private var dismiss

    private var mcpSubtitle: String? {
        guard let version = mcp.latestVersion else { return nil }
        let date = Date(timeIntervalSince1970: version.createdAt)
            .formatted(date: .abbreviated, time: .omitted)
        if date.isEmpty {
            return version.version
        }
        return "\(version.version) • \(date)"
    }

    var body: some View {
        VStack(spacing: 0) {
            NolonUI.SheetHeaderView(
                title: mcp.displayName,
                subtitle: mcpSubtitle
            ) {
                dismiss()
            }

            SheetDivider()
            
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
                                .dsSecondaryText(font: .body)
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
                                        .dsCard(
                                            background: DesignSystem.Colors.Component.controlFillSubtle,
                                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                                        )
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
                                    .dsCard(
                                        background: DesignSystem.Colors.Component.controlFillSubtle,
                                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                                    )
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
                                    .dsCard(
                                        background: DesignSystem.Colors.Component.controlFillSubtle,
                                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                                    )
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
                                        .dsIconLabelText(foreground: DesignSystem.Colors.Status.warning, font: .callout)
                                }
                                if let downloads = stats.downloads {
                                    Label("\(downloads) Downloads", systemImage: "arrow.down.circle")
                                        .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .callout)
                                }
                                if let installs = stats.installs {
                                    Label("\(installs) Installs", systemImage: "server.rack")
                                        .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .callout)
                                }
                            }
                        }
                    }
                    
                    // Changelog
                    if let changelog = mcp.latestVersion?.changelog {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Changelog")
                                .font(.headline)
                            Text(changelog)
                                .font(.body)
                                .dsSecondaryText(font: .body)
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
                        .dsSecondaryText(font: .caption)
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
                .dsLinkButton()
                .keyboardShortcut(.cancelAction)
                
                Button("Install") {
                    if let provider = targetProvider ?? selectedProvider {
                        onInstall(provider)
                        dismiss()
                    }
                }
                .dsPrimaryButton()
                .keyboardShortcut(.defaultAction)
                .disabled(targetProvider == nil && selectedProvider == nil)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
    }
}
