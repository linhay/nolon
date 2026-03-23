import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit
import NolonUI

/// 资源中心 Workflow 卡片视图 - Grid 布局中的卡片
struct RemoteWorkflowCardView: View, DebugPageLocatable {
    let workflow: RemoteWorkflow
    let isInstalled: Bool
    let isInstalling: Bool
    let installErrorMessage: String?
    let isSelected: Bool
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onDeleteRequest: (() -> Void)?
    let isDeleting: Bool
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false

    var debugPageMarkerItems: [PageMarkerItem] {
        [
            .init(title: "Workflow Card"),
            .init(title: workflow.displayName)
        ]
    }
    
    var body: some View {
        NolonUI.ResourceWorkflowCardView(
            name: workflow.displayName,
            version: workflow.latestVersion?.version,
            summary: workflow.summary,
            metaItems: mappedMetaItems,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: handleInstall,
            onRetry: handleInstall,
            onRevealInFinder: revealInFinderAction,
            onDeleteRequest: onDeleteRequest
        ) {
            debugPageMarkerMenuItem(debugPageMarkerItems)
        }
        .debugCardLocator(debugPageMarkerItems)
        .sheet(isPresented: $showingInstallSheet) {
            WorkflowInstallSheet(providers: providers, workflowName: workflow.displayName) { provider in
                onInstall(provider)
            }
        }
    }
    
    private func handleInstall() {
        if let target = targetProvider {
            onInstall(target)
        } else {
            showingInstallSheet = true
        }
    }

    private var mappedMetaItems: [NolonUI.ResourceCardMetaItem] {
        NolonUIAdapter.resourceMetaItems(ResourceCardMetaBuilder.workflowItems(workflow))
    }

    private var revealInFinderAction: (() -> Void)? {
        guard let revealURL = revealInFinderURL else {
            return nil
        }

        return {
            NSWorkspace.shared.activateFileViewerSelecting([revealURL])
        }
    }

    private var revealInFinderURL: URL? {
        var candidates: [URL] = []

        if isInstalled, let provider = targetProvider {
            let providerWorkflowPath = (provider.workflowPath as NSString).expandingTildeInPath
            let mdPath = (providerWorkflowPath as NSString).appendingPathComponent("\(workflow.slug).md")
            candidates.append(URL(fileURLWithPath: mdPath))
            let legacyPath = (providerWorkflowPath as NSString).appendingPathComponent(workflow.slug)
            candidates.append(URL(fileURLWithPath: legacyPath))
        }

        if let localPath = workflow.localPath {
            candidates.append(URL(fileURLWithPath: (localPath as NSString).expandingTildeInPath))
        }

        let globalWorkflowPath = NolonManager.shared.userWorkflowsURL.appendingPathComponent("\(workflow.slug).md")
        candidates.append(globalWorkflowPath)
        candidates.append(NolonManager.shared.userWorkflowsURL.appendingPathComponent(workflow.slug))

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}

/// Workflow 安装选择 Sheet
private struct WorkflowInstallSheet: View {
    let providers: [Provider]
    let workflowName: String
    let onInstall: (Provider) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            UISheetHeaderView(
                title: NSLocalizedString("Install", comment: "Install"),
                subtitle: workflowName
            ) {
                dismiss()
            }

            SheetDivider()

            List {
                ForEach(providers) { provider in
                    Button {
                        onInstall(provider)
                        dismiss()
                    } label: {
                        HStack {
                            if !provider.iconName.isEmpty {
                                Image(provider.iconName)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "folder")
                                    .frame(width: 24, height: 24)
                            }
                            
                            Text(provider.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheetScrollContentPadding()

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420, height: 520)
    }
}
