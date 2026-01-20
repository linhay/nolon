import SwiftUI
import UniformTypeIdentifiers

/// Left column 1: Provider sidebar (collapsible)
/// Displays the list of all providers with selection state
@MainActor
public struct ProviderSidebarView: View {
    @Binding var selectedProvider: SkillProvider?
    @Binding var selectedCustomProvider: CustomProvider?
    @ObservedObject var settings: ProviderSettings
    @State private var showingAddProvider = false
    
    public init(
        selectedProvider: Binding<SkillProvider?>,
        selectedCustomProvider: Binding<CustomProvider?>,
        settings: ProviderSettings
    ) {
        self._selectedProvider = selectedProvider
        self._selectedCustomProvider = selectedCustomProvider
        self.settings = settings
    }
    
    public var body: some View {
        List {
            // Built-in providers section
            Section {
                ForEach(SkillProvider.allCases) { provider in
                    BuiltInProviderRow(
                        provider: provider,
                        isSelected: selectedProvider == provider && selectedCustomProvider == nil
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProvider = provider
                        selectedCustomProvider = nil
                    }
                }
            } header: {
                Text(NSLocalizedString("sidebar.builtin_providers", comment: "Built-in Providers"))
            }
            
            // Custom providers section
            Section {
                ForEach(settings.customProviders) { customProvider in
                    CustomProviderRow(
                        customProvider: customProvider,
                        isSelected: selectedCustomProvider?.id == customProvider.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCustomProvider = customProvider
                        selectedProvider = nil
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            settings.removeCustomProvider(customProvider)
                            if selectedCustomProvider?.id == customProvider.id {
                                selectedCustomProvider = nil
                                selectedProvider = SkillProvider.allCases.first
                            }
                        } label: {
                            Label(NSLocalizedString("action.delete", comment: "Delete"), systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    settings.removeCustomProvider(at: offsets)
                }
            } header: {
                Text(NSLocalizedString("sidebar.custom_providers", comment: "Custom Providers"))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(NSLocalizedString("app.title", comment: "nolon"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProvider = true
                } label: {
                    Label(
                        NSLocalizedString("sidebar.add_provider", comment: "Add Provider"),
                        systemImage: "plus"
                    )
                }
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet(settings: settings)
        }
        .onAppear {
            // Select first provider by default if none selected
            if selectedProvider == nil && selectedCustomProvider == nil {
                selectedProvider = SkillProvider.allCases.first
            }
        }
    }
}

/// Row view for a built-in provider in the sidebar
struct BuiltInProviderRow: View {
    let provider: SkillProvider
    let isSelected: Bool
    
    var body: some View {
        Label {
            Text(provider.displayName)
        } icon: {
            Image(systemName: iconName(for: provider))
                .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func iconName(for provider: SkillProvider) -> String {
        switch provider {
        case .codex: return "terminal"
        case .claude: return "bubble.left.and.bubble.right"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .copilot: return "airplane"
        case .gemini: return "sparkles"
        case .antigravity: return "arrow.up.circle"
        }
    }
}

/// Row view for a custom provider in the sidebar
struct CustomProviderRow: View {
    let customProvider: CustomProvider
    let isSelected: Bool
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(customProvider.name)
                Text(customProvider.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            Image(systemName: customProvider.iconName)
                .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Sheet for adding a new custom provider
struct AddProviderSheet: View {
    @ObservedObject var settings: ProviderSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var providerName = ""
    @State private var providerPath = ""
    @State private var showingFolderPicker = false
    
    private var canSave: Bool {
        !providerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !providerPath.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        NSLocalizedString("add_provider.name_placeholder", comment: "Provider Name"),
                        text: $providerName
                    )
                } header: {
                    Text(NSLocalizedString("add_provider.name_label", comment: "Name"))
                }
                
                Section {
                    HStack {
                        Text(providerPath.isEmpty 
                             ? NSLocalizedString("add_provider.no_folder", comment: "No folder selected")
                             : providerPath)
                            .foregroundStyle(providerPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                            showingFolderPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.folder_label", comment: "Skills Folder"))
                } footer: {
                    Text(NSLocalizedString("add_provider.folder_desc", comment: "Select the folder where skills will be installed"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("add_provider.title", comment: "Add Provider"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("generic.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("generic.add", comment: "Add")) {
                        settings.addCustomProvider(
                            name: providerName.trimmingCharacters(in: .whitespaces),
                            path: providerPath
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        providerPath = url.path
                    }
                case .failure(let error):
                    print("Folder selection failed: \(error)")
                }
            }
        }
        .frame(minWidth: 400, minHeight: 250)
    }
}

