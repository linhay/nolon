import SwiftUI
import Observation
import UniformTypeIdentifiers

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
        path = template.defaultSkillsPath.path
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
        
        if settings.providers.contains(where: { $0.defaultSkillsPath == path }) {
            validationError = NSLocalizedString("add_provider.error.path_exists", value: "A provider with this path already exists.", comment: "Error message")
            return
        }
        
        // Check for "exact match" (logical equivalent) - though path check usually covers it
        if settings.providers.contains(where: { $0.templateId == selectedTemplate.rawValue && $0.defaultSkillsPath == path }) {
             validationError = NSLocalizedString("add_provider.error.exists", value: "This provider configuration already exists.", comment: "Error message")
             return
        }
        
        let provider = Provider(
            name: trimmedName,
            defaultSkillsPath: path,
            workflowPath: workflowPath,
            iconName: selectedTemplate.iconName,
            installMethod: .symlink,
            templateId: selectedTemplate.rawValue,
            documentationURL: selectedTemplate.documentationURL
        )
        settings.addProvider(provider)
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
                            Label {
                                Text(template.displayName)
                            } icon: {
                                ProviderLogoView(name: template.displayName, logoName: template.logoFile, iconSize: 16)
                            }
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
