import SwiftUI
import ProviderCatalog
import Observation
import UniformTypeIdentifiers
import OSLog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

@Observable
final class EditProviderViewModel {
    fileprivate static let logger = Logger(subsystem: "com.nolon", category: "EditProviderViewModel")

    var providerName: String
    var projectRootPath: String
    var providerPath: String
    var workflowPath: String
    var commandPath: String
    var installMethod: SkillInstallationMethod
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

    var template: ProviderTemplate? {
        guard let templateId = provider.templateId else { return nil }
        return ProviderTemplate(rawValue: templateId)
    }

    var secondaryResourceLabel: String {
        if let template {
            return NSLocalizedString(
                template.secondaryResourceLabelLocalizationKey,
                value: template.secondaryResourceLabelFallback,
                comment: "Secondary resource folder label"
            )
        }

        return NSLocalizedString("provider.secondary_resource.workflows", value: "Workflow Folder", comment: "Workflow Folder")
    }

    var vendorCategoryLabel: String? {
        guard provider.kind == .vendor, let category = provider.vendorCategory else { return nil }
        switch category {
        case .original:
            return NSLocalizedString("provider.vendor_category.original", value: "Original Vendors", comment: "Original vendors")
        case .integrated:
            return NSLocalizedString("provider.vendor_category.integrated", value: "Integrated Vendors", comment: "Integrated vendors")
        }
    }
    
    var canSave: Bool {
        !providerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !providerPath.isEmpty
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
        NolonUI.SheetHeaderFooterScaffold(
            title: NSLocalizedString("Edit Provider", comment: "Edit Provider"),
            onClose: {
                dismiss()
            }
        ) {
            NolonUI.GroupedSheetForm {
                NolonUI.ProviderIdentityAndPathsFormSections(
                    name: $viewModel.providerName,
                    nameSection: .init(),
                    vendorInfo: viewModel.vendorCategoryLabel.map {
                        ProviderLabeledValueData(
                            label: NSLocalizedString("edit_provider.vendor_category", value: "Vendor Category", comment: "Vendor category"),
                            value: $0
                        )
                    },
                    projectFolderData: projectFolderSectionData,
                    resolvedPathItems: resolvedPathItems,
                    onChooseProjectFolder: {
                        viewModel.showingProjectFolderPicker = true
                    }
                )
                
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
        } footer: {
            NolonUI.SheetActionFooterView(
                primaryTitle: NSLocalizedString("generic.save", value: "Save", comment: "Save"),
                onCancel: {
                    dismiss()
                },
                onPrimary: {
                    viewModel.saveProvider()
                    dismiss()
                }
            )
        }
        .fileImporter(
            isPresented: $viewModel.showingProjectFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: viewModel.handleProjectFolderSelection
        )
        .frame(minWidth: 400, minHeight: 300)
    }

    private var projectFolderSectionData: ProviderProjectFolderSectionData {
        ProviderProjectFolderSectionData(
            mode: viewModel.provider.kind == .project ? .project : .vendorLocked,
            sectionTitle: viewModel.provider.kind == .project
                ? NSLocalizedString("add_provider.project_folder_label", value: "Project Folder", comment: "Project Folder")
                : NSLocalizedString("add_provider.kind.vendor_info_label", value: "Paths", comment: "Paths section label"),
            displayPath: viewModel.projectRootPath
        )
    }

    private var resolvedPathItems: [ProviderResolvedPathItemData] {
        var items: [ProviderResolvedPathItemData] = [
            ProviderResolvedPathItemData(
                id: "skills",
                label: NSLocalizedString("add_provider.folder_label", comment: "Skills Folder"),
                path: viewModel.providerPath
            )
        ]
        if viewModel.usesCommandFiles {
            items.append(
                ProviderResolvedPathItemData(
                    id: "command",
                    label: NSLocalizedString("edit_provider.command_folder_label", value: "Command Folder", comment: "Command Folder"),
                    path: viewModel.commandPath,
                    emptyPlaceholder: NSLocalizedString("edit_provider.no_command_folder", value: "No command folder selected", comment: "No command folder selected")
                )
            )
        } else {
            items.append(
                ProviderResolvedPathItemData(
                    id: "secondary",
                    label: viewModel.secondaryResourceLabel,
                    path: viewModel.workflowPath
                )
            )
        }
        return items
    }
}
