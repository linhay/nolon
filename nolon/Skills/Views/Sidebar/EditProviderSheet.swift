import SwiftUI
import ProviderCatalog
import Observation
import UniformTypeIdentifiers
import OSLog
import NolonResourceKit

@Observable
final class EditProviderViewModel {
    fileprivate static let logger = Logger(subsystem: "com.nolon", category: "EditProviderViewModel")

    var providerName: String
    var projectRootPath: String
    var providerPath: String
    var workflowPath: String
    var commandPath: String
    var installMethod: SkillInstallationMethod
    var showingFolderPicker = false
    var showingWorkflowFolderPicker = false
    var showingCommandFolderPicker = false
    var showingProjectFolderPicker = false
    
    var settings: ProviderSettings
    var provider: Provider
    
    init(settings: ProviderSettings, provider: Provider) {
        self.settings = settings
        self.provider = provider
        self.providerName = provider.name
        self.projectRootPath = provider.projectRootPath ?? ""
        self.providerPath = provider.defaultSkillsPath
        self.workflowPath = provider.workflowPath
        self.commandPath = provider.commandPath ?? ""
        self.installMethod = provider.installMethod
    }

    var usesCommandFiles: Bool {
        provider.templateId == "opencode"
    }

    var canEditPaths: Bool {
        provider.canEditPaths
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
            Self.logger.error("Folder selection failed: \(error.localizedDescription)")
        }
    }
    
    func handleProjectFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                projectRootPath = url.path
                resolveProjectPathsIfPossible()
            }
        case .failure(let error):
            Self.logger.error("Project folder selection failed: \(error.localizedDescription)")
        }
    }

    func resolveProjectPathsIfPossible() {
        guard provider.kind == .project else { return }
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId)
        else {
            return
        }

        let root = projectRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else { return }
        let rootURL = URL(fileURLWithPath: root)

        providerPath = template.skillsPath(forProjectRoot: rootURL).path
        let commandURL = template.commandPath(forProjectRoot: rootURL)
        commandPath = commandURL?.path ?? ""
        workflowPath = (commandURL?.path) ?? template.workflowPath(forProjectRoot: rootURL).path
    }

    func saveProvider() {
        var updatedProvider = provider
        updatedProvider.name = providerName.trimmingCharacters(in: .whitespaces)
        if updatedProvider.kind == .project {
            updatedProvider.projectRootPath = projectRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if canEditPaths {
            updatedProvider.defaultSkillsPath = providerPath
            if usesCommandFiles {
                updatedProvider.commandPath = commandPath
                updatedProvider.workflowPath = commandPath
            } else {
                updatedProvider.workflowPath = workflowPath
                updatedProvider.commandPath = nil
            }
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
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("Edit Provider", comment: "Edit Provider")) {
                dismiss()
            }

            SheetDivider()

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
                    if viewModel.provider.kind == .project {
                        HStack {
                            Text(viewModel.projectRootPath.isEmpty
                                 ? NSLocalizedString("add_provider.no_project_folder", value: "No project folder selected", comment: "No project folder selected")
                                 : viewModel.projectRootPath)
                                .foregroundStyle(viewModel.projectRootPath.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                                viewModel.showingProjectFolderPicker = true
                            }
                            .dsSecondaryButton()
                        }
                    } else {
                        Text(NSLocalizedString("add_provider.kind.vendor_paths_locked", value: "Vendor paths are predefined and cannot be changed.", comment: "Vendor paths are locked"))
                            .dsSecondaryText(font: .callout)
                    }
                } header: {
                    Text(viewModel.provider.kind == .project
                         ? NSLocalizedString("add_provider.project_folder_label", value: "Project Folder", comment: "Project Folder")
                         : NSLocalizedString("add_provider.kind.vendor_info_label", value: "Paths", comment: "Paths section label"))
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(NSLocalizedString("add_provider.folder_label", comment: "Skills Folder")) {
                            Text(viewModel.providerPath.isEmpty
                                 ? NSLocalizedString("add_provider.no_folder", comment: "No folder selected")
                                 : viewModel.providerPath)
                                .foregroundStyle(viewModel.providerPath.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        if viewModel.usesCommandFiles {
                            LabeledContent(NSLocalizedString("edit_provider.command_folder_label", value: "Command Folder", comment: "Command Folder")) {
                                Text(viewModel.commandPath.isEmpty
                                     ? NSLocalizedString("edit_provider.no_command_folder", value: "No command folder selected", comment: "No command folder selected")
                                     : viewModel.commandPath)
                                    .foregroundStyle(viewModel.commandPath.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        } else {
                            LabeledContent(NSLocalizedString("edit_provider.workflow_folder_label", value: "Workflow Folder", comment: "Workflow Folder")) {
                                Text(viewModel.workflowPath.isEmpty
                                     ? NSLocalizedString("edit_provider.no_workflow_folder", value: "No workflow folder selected", comment: "No workflow folder selected")
                                     : viewModel.workflowPath)
                                    .foregroundStyle(viewModel.workflowPath.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("add_provider.resolved_paths_label", value: "Resolved Paths", comment: "Resolved paths section header"))
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
            .sheetScrollContentPadding()

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("generic.cancel", comment: "Cancel")) {
                    dismiss()
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("generic.save", value: "Save", comment: "Save")) {
                    viewModel.saveProvider()
                    dismiss()
                }
                .dsPrimaryButton()
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .fileImporter(
            isPresented: $viewModel.showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: viewModel.handleFolderSelection
        )
        .fileImporter(
            isPresented: $viewModel.showingProjectFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: viewModel.handleProjectFolderSelection
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
                    EditProviderViewModel.logger.error("Workflow folder selection failed: \(error.localizedDescription)")
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
                    EditProviderViewModel.logger.error("Command folder selection failed: \(error.localizedDescription)")
                }
            }
        )
        .frame(minWidth: 400, minHeight: 300)
    }
}
