import SwiftUI
import Observation
import UniformTypeIdentifiers

// MARK: - ViewModels

@Observable
final class ProviderSidebarViewModel {
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

@Observable
final class AddProviderViewModel {
    var name: String = ""
    var path: String = ""
    var workflowPath: String = ""
    var selectedTemplate: ProviderTemplate = .antigravity
    var showingFolderPicker = false
    var showingWorkflowFolderPicker = false
    var validationError: String?
    
    var settings: ProviderSettings
    
    init(settings: ProviderSettings) {
        self.settings = settings
        applyTemplate(.antigravity)
    }
    
    func applyTemplate(_ template: ProviderTemplate) {
        selectedTemplate = template
        name = template.displayName
        path = template.defaultPath.path
        workflowPath = template.defaultWorkflowPath.path
        validationError = nil
    }
    
    func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                path = url.path
            }
        case .failure(let error):
            print("Folder selection failed: \(error)")
        }
    }
    
    func handleWorkflowFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                workflowPath = url.path
            }
        case .failure(let error):
            print("Workflow folder selection failed: \(error)")
        }
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !path.isEmpty
    }
    
    func save() {
        validationError = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if settings.providers.contains(where: { $0.name == trimmedName }) {
            validationError = NSLocalizedString("add_provider.error.name_exists", value: "A provider with this name already exists.", comment: "Error message")
            return
        }
        
        if settings.providers.contains(where: { $0.skillsPath == path }) {
            validationError = NSLocalizedString("add_provider.error.path_exists", value: "A provider with this path already exists.", comment: "Error message")
            return
        }
        
        // Check for "exact match" (logical equivalent) - though path check usually covers it
        if settings.providers.contains(where: { $0.templateId == selectedTemplate.rawValue && $0.skillsPath == path }) {
             validationError = NSLocalizedString("add_provider.error.exists", value: "This provider configuration already exists.", comment: "Error message")
             return
        }
        
        let provider = Provider(
            name: trimmedName,
            skillsPath: path,
            workflowPath: workflowPath,
            iconName: selectedTemplate.iconName,
            installMethod: .symlink,
            templateId: selectedTemplate.rawValue,
            documentationURL: selectedTemplate.documentationURL
        )
        settings.addProvider(provider)
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
    @ObservedObject var settings: ProviderSettings
    @State private var viewModel: ProviderSidebarViewModel
    @State private var showingAddSheet = false
    
    public init(
        selectedProviderId: Binding<Provider.ID?>,
        settings: ProviderSettings
    ) {
        self._selectedProviderId = selectedProviderId
        self.settings = settings
        self._viewModel = State(initialValue: ProviderSidebarViewModel(settings: settings))
    }
    
    public var body: some View {
        List(selection: $selectedProviderId) {
            Section {
                ForEach(settings.providers) { provider in
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

        .sheet(item: $viewModel.editingProvider) { provider in
            EditProviderSheet(settings: viewModel.settings, provider: provider)
        }
        .onAppear {
            viewModel.selectFirstProviderIfNone(selection: $selectedProviderId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label(NSLocalizedString("action.add_provider", value: "Add Provider", comment: "Add Provider"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProviderSheet(settings: viewModel.settings)
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
            ProviderLogoView(provider: provider, style: .iconOnly, iconSize: 18)
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

struct AddProviderSheet: View {
    @State private var viewModel: AddProviderViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(settings: ProviderSettings) {
        self._viewModel = State(initialValue: AddProviderViewModel(settings: settings))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Template", selection: $viewModel.selectedTemplate) {
                        ForEach(ProviderTemplate.allCases) { template in
                            Label(template.displayName, systemImage: template.iconName)
                                .tag(template)
                        }
                    }
                    .onChange(of: viewModel.selectedTemplate) { _, newValue in
                        viewModel.applyTemplate(newValue)
                    }
                } header: {
                    Text("Template")
                }
                
                Section {
                    TextField(
                        NSLocalizedString("add_provider.name_placeholder", comment: "Provider Name"),
                        text: $viewModel.name
                    )
                } header: {
                    Text(NSLocalizedString("add_provider.name_label", comment: "Name"))
                }
                
                Section {
                    HStack {
                        Text(viewModel.path.isEmpty
                             ? NSLocalizedString("add_provider.no_folder", comment: "No folder selected")
                             : viewModel.path)
                            .foregroundStyle(viewModel.path.isEmpty ? .secondary : .primary)
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
                        
                        Button("Choose...") {
                            viewModel.showingWorkflowFolderPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Workflow Folder")
                }
                
                if let error = viewModel.validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Provider")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("generic.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("generic.add", comment: "Add")) {
                        viewModel.save()
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
            .fileImporter(
                isPresented: $viewModel.showingWorkflowFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: viewModel.handleWorkflowFolderSelection
            )
        }
        .frame(minWidth: 450, minHeight: 400)
    }
}
