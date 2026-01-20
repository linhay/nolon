import SwiftUI
import UniformTypeIdentifiers

/// Left column 1: Provider sidebar (collapsible)
/// Displays the unified list of all providers with selection state
@MainActor
public struct ProviderSidebarView: View {
    @Binding var selectedProvider: Provider?
    @ObservedObject var settings: ProviderSettings
    @State private var showingAddProvider = false
    @State private var editingProvider: Provider?
    
    public init(
        selectedProvider: Binding<Provider?>,
        settings: ProviderSettings
    ) {
        self._selectedProvider = selectedProvider
        self.settings = settings
    }
    
    public var body: some View {
        List(selection: $selectedProvider) {
            Section {
                ForEach(settings.providers) { provider in
                    ProviderRowView(
                        provider: provider,
                        isSelected: selectedProvider?.id == provider.id
                    )
                    .tag(provider)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            // 在 Finder 中打开
                            let url = URL(fileURLWithPath: provider.path)
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                        } label: {
                            Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                        }
                        
                        Button {
                            // 编辑
                            editingProvider = provider
                        } label: {
                            Label(NSLocalizedString("action.edit", comment: "Edit"), systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            settings.removeProvider(provider)
                            if selectedProvider?.id == provider.id {
                                selectedProvider = settings.providers.first
                            }
                        } label: {
                            Label(NSLocalizedString("action.delete", comment: "Delete"), systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    settings.removeProvider(at: offsets)
                }
                .onMove { source, destination in
                    settings.moveProvider(from: source, to: destination)
                }
            } header: {
                Text(NSLocalizedString("sidebar.providers", comment: "Providers"))
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
        .sheet(item: $editingProvider) { provider in
            EditProviderSheet(settings: settings, provider: provider)
        }
        .onAppear {
            // Select first provider by default if none selected
            if selectedProvider == nil {
                selectedProvider = settings.providers.first
            }
        }
    }
}

/// Row view for a provider in the sidebar
struct ProviderRowView: View {
    let provider: Provider
    let isSelected: Bool
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                Text(provider.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            Image(systemName: provider.iconName)
                .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Sheet for adding a new provider
struct AddProviderSheet: View {
    @ObservedObject var settings: ProviderSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var providerName = ""
    @State private var providerPath = ""
    @State private var selectedIcon = "folder"
    @State private var installMethod: SkillInstallationMethod = .symlink
    @State private var showingFolderPicker = false
    @State private var selectedTemplate: ProviderTemplate?
    
    private var canSave: Bool {
        !providerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !providerPath.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Template selection section
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ProviderTemplate.allCases) { template in
                                TemplateButton(
                                    template: template,
                                    isSelected: selectedTemplate == template,
                                    action: {
                                        selectedTemplate = template
                                        providerName = template.displayName
                                        providerPath = template.defaultPath.path
                                        selectedIcon = template.iconName
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.templates", comment: "Quick Templates"))
                } footer: {
                    Text(NSLocalizedString("add_provider.templates_desc", comment: "Select a template to auto-fill, or customize below"))
                }
                
                Section {
                    TextField(
                        NSLocalizedString("add_provider.name_placeholder", comment: "Provider Name"),
                        text: $providerName
                    )
                    .onChange(of: providerName) { _, _ in
                        // If user modifies the name, clear template selection
                        if providerName != selectedTemplate?.displayName {
                            selectedTemplate = nil
                        }
                    }
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
                }
                
                Section {
                    Picker(NSLocalizedString("add_provider.install_method", comment: "Installation Method"), selection: $installMethod) {
                        ForEach(SkillInstallationMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.settings", comment: "Settings"))
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
                        settings.addProvider(
                            name: providerName.trimmingCharacters(in: .whitespaces),
                            path: providerPath,
                            iconName: selectedIcon,
                            installMethod: installMethod,
                            templateId: selectedTemplate?.rawValue
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
                        selectedTemplate = nil  // Clear template when custom path selected
                    }
                case .failure(let error):
                    print("Folder selection failed: \(error)")
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

/// Template selection button
struct TemplateButton: View {
    let template: ProviderTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: template.iconName)
                    .font(.title2)
                Text(template.displayName)
                    .font(.caption)
            }
            .frame(width: 80, height: 60)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Sheet for editing an existing provider
struct EditProviderSheet: View {
    @ObservedObject var settings: ProviderSettings
    let provider: Provider
    @Environment(\.dismiss) private var dismiss
    
    @State private var providerName: String
    @State private var providerPath: String
    @State private var installMethod: SkillInstallationMethod
    @State private var showingFolderPicker = false
    
    init(settings: ProviderSettings, provider: Provider) {
        self.settings = settings
        self.provider = provider
        self._providerName = State(initialValue: provider.name)
        self._providerPath = State(initialValue: provider.path)
        self._installMethod = State(initialValue: provider.installMethod)
    }
    
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
                }
                
                Section {
                    Picker(NSLocalizedString("add_provider.install_method", comment: "Installation Method"), selection: $installMethod) {
                        ForEach(SkillInstallationMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.settings", comment: "Settings"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("edit_provider.title", comment: "Edit Provider"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("generic.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("generic.save", comment: "Save")) {
                        var updatedProvider = provider
                        updatedProvider.name = providerName.trimmingCharacters(in: .whitespaces)
                        updatedProvider.path = providerPath
                        updatedProvider.installMethod = installMethod
                        settings.updateProvider(updatedProvider)
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
        .frame(minWidth: 400, minHeight: 300)
    }
}
