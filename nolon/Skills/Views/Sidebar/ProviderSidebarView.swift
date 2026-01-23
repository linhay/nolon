import SwiftUI
import Observation
import UniformTypeIdentifiers

// MARK: - ViewModels

@Observable
final class ProviderSidebarViewModel {
    var showingAddProvider = false
    var editingProvider: Provider?
    
    var settings: ProviderSettings
    
    init(settings: ProviderSettings) {
        self.settings = settings
    }
    
    @MainActor
    func deleteProvider(_ provider: Provider, currentSelection: Binding<Provider.ID?>) {
        settings.removeProvider(provider)
        if currentSelection.wrappedValue == provider.id {
            currentSelection.wrappedValue = settings.providers.first?.id
        }
    }
    
    @MainActor
    func deleteProviders(at offsets: IndexSet) {
        settings.removeProvider(at: offsets)
    }
    
    @MainActor
    func moveProviders(from source: IndexSet, to destination: Int) {
        settings.moveProvider(from: source, to: destination)
    }
    
    @MainActor
    func selectFirstProviderIfNone(selection: Binding<Provider.ID?>) {
        if selection.wrappedValue == nil {
            selection.wrappedValue = settings.providers.first?.id
        }
    }
    
    @MainActor
    func showInFinder(_ provider: Provider) {
        let url = URL(fileURLWithPath: provider.skillsPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

// ... (AddProviderViewModel and EditProviderViewModel remain unchanged, keeping the ellipsis or just not including them in replacement if not needed. Since I need to replace the class block, I will target the ProviderSidebarViewModel class specifically)

@Observable
final class AddProviderViewModel {
    var providerName = ""
    var providerPath = ""
    var workflowPath = ""
    var selectedIcon = "folder"
    var installMethod: SkillInstallationMethod = .symlink
    var showingFolderPicker = false
    var selectedTemplate: ProviderTemplate?
    
    var settings: ProviderSettings
    
    init(settings: ProviderSettings) {
        self.settings = settings
    }
    
    var canSave: Bool {
        !providerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !providerPath.isEmpty
    }
    
    func selectTemplate(_ template: ProviderTemplate) {
        selectedTemplate = template
        providerName = template.displayName
        providerPath = template.defaultPath.path
        workflowPath = template.defaultWorkflowPath.path
        selectedIcon = template.iconName
    }
    
    func onNameChange() {
        if providerName != selectedTemplate?.displayName {
            selectedTemplate = nil
        }
    }
    
    func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                providerPath = url.path
                selectedTemplate = nil
            }
        case .failure(let error):
            print("Folder selection failed: \(error)")
        }
    }
    
    func addProvider() {
        settings.addProvider(
            name: providerName.trimmingCharacters(in: .whitespaces),
            skillsPath: providerPath,
            workflowPath: workflowPath,
            iconName: selectedIcon,
            installMethod: installMethod,
            templateId: selectedTemplate?.rawValue
        )
    }
}

@Observable
final class EditProviderViewModel {
    var providerName: String
    var providerPath: String
    var workflowPath: String
    var installMethod: SkillInstallationMethod
    var showingFolderPicker = false
    
    var settings: ProviderSettings
    var provider: Provider
    
    init(settings: ProviderSettings, provider: Provider) {
        self.settings = settings
        self.provider = provider
        self.providerName = provider.name
        self.providerPath = provider.skillsPath
        self.workflowPath = provider.workflowPath
        self.installMethod = provider.installMethod
    }
    
    var canSave: Bool {
        !providerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !providerPath.isEmpty
    }
    
    func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                providerPath = url.path
            }
        case .failure(let error):
            print("Folder selection failed: \(error)")
        }
    }
    
    func saveProvider() {
        var updatedProvider = provider
        updatedProvider.name = providerName.trimmingCharacters(in: .whitespaces)
        updatedProvider.skillsPath = providerPath
        updatedProvider.workflowPath = workflowPath
        updatedProvider.installMethod = installMethod
        settings.updateProvider(updatedProvider)
    }
}

// MARK: - Views

/// Left column 1: Provider sidebar (collapsible)
/// Displays the unified list of all providers with selection state
@MainActor
public struct ProviderSidebarView: View {
    @Binding var selectedProviderId: Provider.ID?
    @State private var viewModel: ProviderSidebarViewModel
    
    public init(
        selectedProviderId: Binding<Provider.ID?>,
        settings: ProviderSettings
    ) {
        self._selectedProviderId = selectedProviderId
        self._viewModel = State(initialValue: ProviderSidebarViewModel(settings: settings))
    }
    
    public var body: some View {
        List(selection: $selectedProviderId) {
            Section {
                ForEach(viewModel.settings.providers) { provider in
                    ProviderRowView(
                        provider: provider,
                        isSelected: selectedProviderId == provider.id,
                        onShowInFinder: { viewModel.showInFinder(provider) },
                        onEdit: { viewModel.editingProvider = provider },
                        onDelete: { viewModel.deleteProvider(provider, currentSelection: $selectedProviderId) }
                    )
                    .tag(provider.id)
                }
                .onDelete { offsets in
                    viewModel.deleteProviders(at: offsets)
                }
                .onMove { source, destination in
                    viewModel.moveProviders(from: source, to: destination)
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
                    viewModel.showingAddProvider = true
                } label: {
                    Label(
                        NSLocalizedString("sidebar.add_provider", comment: "Add Provider"),
                        systemImage: "plus"
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddProvider) {
            AddProviderSheet(settings: viewModel.settings)
        }
        .sheet(item: $viewModel.editingProvider) { provider in
            EditProviderSheet(settings: viewModel.settings, provider: provider)
        }
        .onAppear {
            viewModel.selectFirstProviderIfNone(selection: $selectedProviderId)
        }
    }
}

/// Row view for a provider in the sidebar
struct ProviderRowView: View {
    let provider: Provider
    let isSelected: Bool
    let onShowInFinder: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                Text(provider.skillsPath)
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
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onShowInFinder()
            } label: {
                Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
            }
            
            Button {
                onEdit()
            } label: {
                Label(NSLocalizedString("action.edit", comment: "Edit"), systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(NSLocalizedString("action.delete", comment: "Delete"), systemImage: "trash")
            }
        }
    }
}

/// Sheet for adding a new provider
struct AddProviderSheet: View {
    @State private var viewModel: AddProviderViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(settings: ProviderSettings) {
        self._viewModel = State(initialValue: AddProviderViewModel(settings: settings))
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
                                    isSelected: viewModel.selectedTemplate == template,
                                    action: { viewModel.selectTemplate(template) }
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
                        text: $viewModel.providerName
                    )
                    .onChange(of: viewModel.providerName) { _, _ in
                        viewModel.onNameChange()
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.name_label", comment: "Name"))
                }
                
                Section {
                    HStack {
                        Text(viewModel.providerPath.isEmpty
                             ? NSLocalizedString("add_provider.no_folder", comment: "No folder selected")
                             : viewModel.providerPath)
                            .foregroundStyle(viewModel.providerPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                            viewModel.showingFolderPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.folder_label", comment: "Skills Folder"))
                }

                Section {
                    HStack {
                        Text(viewModel.workflowPath.isEmpty
                             ? "No workflow folder selected"
                             : viewModel.workflowPath)
                            .foregroundStyle(viewModel.workflowPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                    }
                } header: {
                    Text("Workflow Folder")
                }
                
                Section {
                    Picker(NSLocalizedString("add_provider.install_method", comment: "Installation Method"), selection: $viewModel.installMethod) {
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
                        viewModel.addProvider()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .fileImporter(
                isPresented: $viewModel.showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: viewModel.handleFolderSelection
            )
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
    @State private var viewModel: EditProviderViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(settings: ProviderSettings, provider: Provider) {
        self._viewModel = State(initialValue: EditProviderViewModel(settings: settings, provider: provider))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        NSLocalizedString("add_provider.name_placeholder", comment: "Provider Name"),
                        text: $viewModel.providerName
                    )
                } header: {
                    Text(NSLocalizedString("add_provider.name_label", comment: "Name"))
                }
                
                Section {
                    HStack {
                        Text(viewModel.providerPath.isEmpty
                             ? NSLocalizedString("add_provider.no_folder", comment: "No folder selected")
                             : viewModel.providerPath)
                            .foregroundStyle(viewModel.providerPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                            viewModel.showingFolderPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.folder_label", comment: "Skills Folder"))
                }

                Section {
                    HStack {
                        Text(viewModel.workflowPath.isEmpty
                             ? "No workflow folder selected"
                             : viewModel.workflowPath)
                            .foregroundStyle(viewModel.workflowPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                         // No picker for now
                    }
                } header: {
                    Text("Workflow Folder")
                }
                
                Section {
                    Picker(NSLocalizedString("add_provider.install_method", comment: "Installation Method"), selection: $viewModel.installMethod) {
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
                        viewModel.saveProvider()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .fileImporter(
                isPresented: $viewModel.showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: viewModel.handleFolderSelection
            )
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
