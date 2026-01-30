import SwiftUI
import Observation
import UniformTypeIdentifiers

@Observable
final class EditProviderViewModel {
    var providerName: String
    var providerPath: String
    var workflowPath: String
    var commandPath: String
    var installMethod: SkillInstallationMethod
    var showingFolderPicker = false
    var showingWorkflowFolderPicker = false
    var showingCommandFolderPicker = false
    
    var settings: ProviderSettings
    var provider: Provider
    
    init(settings: ProviderSettings, provider: Provider) {
        self.settings = settings
        self.provider = provider
        self.providerName = provider.name
        self.providerPath = provider.defaultSkillsPath
        self.workflowPath = provider.workflowPath
        self.commandPath = provider.commandPath ?? ""
        self.installMethod = provider.installMethod
    }

    var usesCommandFiles: Bool {
        provider.templateId == "opencode"
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
        if usesCommandFiles {
            updatedProvider.commandPath = commandPath
            updatedProvider.workflowPath = commandPath
        } else {
            updatedProvider.workflowPath = workflowPath
            updatedProvider.commandPath = nil
        }
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
                        if viewModel.usesCommandFiles {
                            Text(viewModel.commandPath.isEmpty
                                 ? NSLocalizedString("edit_provider.no_command_folder", value: "No command folder selected", comment: "No command folder selected")
                                 : viewModel.commandPath)
                                .foregroundStyle(viewModel.commandPath.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                                viewModel.showingCommandFolderPicker = true
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text(viewModel.workflowPath.isEmpty
                                 ? NSLocalizedString("edit_provider.no_workflow_folder", value: "No workflow folder selected", comment: "No workflow folder selected")
                                 : viewModel.workflowPath)
                                .foregroundStyle(viewModel.workflowPath.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                                viewModel.showingWorkflowFolderPicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    Text(
                        viewModel.usesCommandFiles
                            ? NSLocalizedString("edit_provider.command_folder_label", value: "Command Folder", comment: "Command Folder")
                            : NSLocalizedString("edit_provider.workflow_folder_label", value: "Workflow Folder", comment: "Workflow Folder")
                    )
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
            .fileImporter(
                isPresented: $viewModel.showingWorkflowFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            viewModel.workflowPath = url.path
                        }
                    case .failure(let error):
                        print("Workflow folder selection failed: \(error)")
                    }
                }
            )
            .fileImporter(
                isPresented: $viewModel.showingCommandFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            viewModel.commandPath = url.path
                        }
                    case .failure(let error):
                        print("Command folder selection failed: \(error)")
                    }
                }
            )
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
