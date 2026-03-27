import SwiftUI
import ProviderCatalog
import Observation
import UniformTypeIdentifiers
import OSLog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

@Observable
final class AddProviderViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "AddProviderViewModel")

    var kind: ProviderKind = .vendor
    var name: String = ""
    var projectRootPath: String = ""
    var resolvedSkillsPath: String = ""
    var resolvedWorkflowPath: String = ""
    var resolvedCommandPath: String = ""
    var selectedTemplate: ProviderTemplate = .antigravity
    var showingProjectFolderPicker = false
    var validationError: String?
    
    var settings: ProviderSettings
    
    init(settings: ProviderSettings) {
        self.settings = settings
        applyTemplate(.antigravity)
    }

    var templateSections: [ProviderPresentationSections.TemplateSection] {
        ProviderPresentationSections.templateSections()
    }

    var secondaryResourceLabel: String {
        NSLocalizedString(
            selectedTemplate.secondaryResourceLabelLocalizationKey,
            value: selectedTemplate.secondaryResourceLabelFallback,
            comment: "Secondary resource folder label"
        )
    }
    
    func applyTemplate(_ template: ProviderTemplate) {
        selectedTemplate = template
        name = template.displayName
        validationError = nil
        resolvePaths()
    }

    func setKind(_ newKind: ProviderKind) {
        guard kind != newKind else { return }
        kind = newKind
        if newKind == .vendor {
            projectRootPath = ""
        }
        validationError = nil
        resolvePaths()
    }
    
    func handleProjectFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                projectRootPath = url.path
                resolvePaths()
            }
        case .failure(let error):
            Self.logger.error("Project folder selection failed: \(error.localizedDescription)")
        }
    }

    private func resolvePaths() {
        let template = selectedTemplate

        switch kind {
        case .vendor:
            resolvedSkillsPath = template.defaultSkillsPath.path
            let commandPath = template.defaultCommandPath?.path ?? ""
            resolvedCommandPath = commandPath
            resolvedWorkflowPath = commandPath.isEmpty ? template.defaultWorkflowPath.path : commandPath
        case .project:
            guard !projectRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                resolvedSkillsPath = ""
                resolvedWorkflowPath = ""
                resolvedCommandPath = ""
                return
            }

            let rootURL = URL(fileURLWithPath: projectRootPath)
            resolvedSkillsPath = template.skillsPath(forProjectRoot: rootURL).path
            let commandURL = template.commandPath(forProjectRoot: rootURL)
            resolvedCommandPath = commandURL?.path ?? ""
            resolvedWorkflowPath = (commandURL?.path) ?? template.workflowPath(forProjectRoot: rootURL).path
        }
    }
    
    var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch kind {
        case .vendor:
            return hasName && !resolvedSkillsPath.isEmpty && !resolvedWorkflowPath.isEmpty
        case .project:
            return hasName
                && !projectRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !resolvedSkillsPath.isEmpty
                && !resolvedWorkflowPath.isEmpty
        }
    }
    
    func save() {
        validationError = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if settings.providers.contains(where: { $0.name == trimmedName }) {
            validationError = NSLocalizedString("add_provider.error.name_exists", value: "A provider with this name already exists.", comment: "Error message")
            return
        }
        
        if settings.providers.contains(where: { $0.defaultSkillsPath == resolvedSkillsPath }) {
            validationError = NSLocalizedString("add_provider.error.path_exists", value: "A provider with this path already exists.", comment: "Error message")
            return
        }
        
        // Check for "exact match" (logical equivalent) - though path check usually covers it
        if settings.providers.contains(where: { $0.kind == kind && $0.templateId == selectedTemplate.rawValue && $0.defaultSkillsPath == resolvedSkillsPath }) {
             validationError = NSLocalizedString("add_provider.error.exists", value: "This provider configuration already exists.", comment: "Error message")
             return
        }
        
        let isOpenCode = selectedTemplate.usesCommandFiles
        let effectiveWorkflowPath = isOpenCode ? resolvedCommandPath : resolvedWorkflowPath
        let provider = Provider(
            kind: kind,
            name: trimmedName,
            projectRootPath: kind == .project ? projectRootPath : nil,
            defaultSkillsPath: resolvedSkillsPath,
            workflowPath: effectiveWorkflowPath,
            commandPath: isOpenCode ? resolvedCommandPath : nil,
            iconName: selectedTemplate.iconName,
            installMethod: .symlink,
            vendorCategory: kind == .vendor ? selectedTemplate.vendorCategory : nil,
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
        NolonUI.SheetHeaderFooterScaffold(
            title: NSLocalizedString("Add Provider", comment: "Add Provider"),
            onClose: {
                dismiss()
            }
        ) {
            NolonUI.GroupedSheetForm {
                Section {
                    Picker(NSLocalizedString("add_provider.kind_label", value: "Type", comment: "Provider kind label"), selection: $viewModel.kind) {
                        Text(NSLocalizedString("add_provider.kind.vendor", value: "Vendor", comment: "Vendor provider type"))
                            .tag(ProviderKind.vendor)
                        Text(NSLocalizedString("add_provider.kind.project", value: "Project", comment: "Project provider type"))
                            .tag(ProviderKind.project)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.kind) { _, newValue in
                        viewModel.setKind(newValue)
                    }

                    Picker(NSLocalizedString("Template", comment: "Template"), selection: $viewModel.selectedTemplate) {
                        ForEach(viewModel.templateSections) { section in
                            Section(
                                NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Template section title")
                            ) {
                                ForEach(section.templates) { template in
                                    Label {
                                        Text(template.displayName)
                                    } icon: {
                                        NolonUI.ProviderLogoView(name: template.displayName, logoName: template.logoFile, iconSize: 16)
                                    }
                                    .tag(template)
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedTemplate) { _, newValue in
                        viewModel.applyTemplate(newValue)
                    }
                } header: {
                    Text(NSLocalizedString("Template", comment: "Template"))
                }
                
                NolonUI.ProviderIdentityAndPathsFormSections(
                    name: $viewModel.name,
                    nameSection: .init(),
                    projectFolderData: projectFolderSectionData,
                    resolvedPathItems: resolvedPathItems,
                    onChooseProjectFolder: {
                        viewModel.showingProjectFolderPicker = true
                    }
                )
                
                if let error = viewModel.validationError {
                    Section {
                        Text(error)
                            .dsErrorText(font: .caption)
                    }
                }
            }
        } footer: {
            NolonUI.SheetActionFooterView(
                primaryTitle: NSLocalizedString("generic.add", comment: "Add"),
                isPrimaryDisabled: !viewModel.canSave,
                onCancel: {
                    dismiss()
                },
                onPrimary: {
                    viewModel.save()
                    if viewModel.validationError == nil {
                        dismiss()
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $viewModel.showingProjectFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: viewModel.handleProjectFolderSelection
        )
        .frame(minWidth: 450, minHeight: 400)
    }

    private var projectFolderSectionData: ProviderProjectFolderSectionData {
        ProviderProjectFolderSectionData(
            mode: viewModel.kind == .project ? .project : .vendorLocked,
            sectionTitle: viewModel.kind == .project
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
                path: viewModel.resolvedSkillsPath
            )
        ]

        if viewModel.selectedTemplate.usesCommandFiles {
            items.append(
                ProviderResolvedPathItemData(
                    id: "command",
                    label: NSLocalizedString("add_provider.command_folder_label", value: "Command Folder", comment: "Command Folder"),
                    path: viewModel.resolvedCommandPath,
                    emptyPlaceholder: NSLocalizedString("add_provider.no_command_folder", value: "No command folder selected", comment: "No command folder selected")
                )
            )
        } else {
            items.append(
                ProviderResolvedPathItemData(
                    id: "secondary",
                    label: viewModel.secondaryResourceLabel,
                    path: viewModel.resolvedWorkflowPath
                )
            )
        }
        return items
    }
}
