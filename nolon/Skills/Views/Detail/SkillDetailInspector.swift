import SwiftUI

struct SkillDetailInspector: View {
    @Bindable var viewModel: SkillDetailViewModel
    @ObservedObject var settings: ProviderSettings
    let provider: Provider?
    
    @State private var isListMode = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text(viewModel.skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Providers Grid
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Installations")
                            .font(.headline)
                        Spacer()
                        Button {
                            withAnimation {
                                isListMode.toggle()
                            }
                        } label: {
                            Image(systemName: isListMode ? "square.grid.2x2" : "list.bullet")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(isListMode ? "Show as Grid" : "Show as List")
                    }
                    
                    if isListMode {
                        // List Mode
                        VStack(spacing: 8) {
                            ForEach(settings.providers) { provider in
                                let isInstalled = viewModel.providerInstallationStates[provider.id] ?? false
                                
                                Button {
                                    Task {
                                        await viewModel.toggleInstallation(for: provider)
                                    }
                                } label: {
                                    HStack {
                                        ProviderLogoView(provider: provider, style: .horizontal, iconSize: 24)
                                            .grayscale(isInstalled ? 0 : 1.0)
                                            .opacity(isInstalled ? 1.0 : 0.6)
                                        
                                        Spacer()
                                        
                                        if isInstalled {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isInstalled ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // Grid Mode
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50, maximum: 60), spacing: 12)], spacing: 12) {
                            ForEach(settings.providers) { provider in
                                let isInstalled = viewModel.providerInstallationStates[provider.id] ?? false
                                
                                Button {
                                    Task {
                                        await viewModel.toggleInstallation(for: provider)
                                    }
                                } label: {
                                    ZStack {
                                        // Background
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(isInstalled ? Color.accentColor : Color.secondary.opacity(0.1), lineWidth: isInstalled ? 2 : 1)
                                            )
                                        
                                        // Icon
                                        ProviderLogoView(provider: provider, style: .iconOnly, iconSize: 30)
                                            .grayscale(isInstalled ? 0 : 1.0)
                                            .opacity(isInstalled ? 1.0 : 0.4)
                                    }
                                    .contentShape(Rectangle())
                                    .help(provider.name)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // Current Provider Workflow
                if let currentProvider = provider {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workflow")
                            .font(.headline)
                        
                        Text("Associate this skill with a workflow in **\(currentProvider.name)**.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Toggle(isOn: Binding(
                            get: { viewModel.isWorkflowLinked },
                            set: { _ in viewModel.toggleWorkflow(for: currentProvider) }
                        )) {
                            Label("Enable Workflow", systemImage: "arrow.triangle.branch")
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                
                Spacer()
                
                // Finder Button
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.skill.globalPath)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding()
        }
    }
}
