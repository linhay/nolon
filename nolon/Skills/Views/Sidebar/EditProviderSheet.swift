import SwiftUI
import Observation
import UniformTypeIdentifiers

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
        self.providerPath = provider.defaultSkillsPath
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
        updatedProvider.defaultSkillsPath = providerPath
        updatedProvider.workflowPath = workflowPath
        updatedProvider.installMethod = installMethod
        settings.updateProvider(updatedProvider)
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
