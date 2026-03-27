import SwiftUI
import NolonUIFoundation

public struct CodexBinaryActionsBarView: View {
    public let data: CodexBinaryActionBarData
    public let onPrimaryAction: () -> Void
    public let onCheckUpdates: () -> Void
    public let onImportLocal: () -> Void
    public let onOpenGitHub: () -> Void
    public let onToggleBeta: (Bool) -> Void

    public init(
        data: CodexBinaryActionBarData,
        onPrimaryAction: @escaping () -> Void,
        onCheckUpdates: @escaping () -> Void,
        onImportLocal: @escaping () -> Void,
        onOpenGitHub: @escaping () -> Void,
        onToggleBeta: @escaping (Bool) -> Void
    ) {
        self.data = data
        self.onPrimaryAction = onPrimaryAction
        self.onCheckUpdates = onCheckUpdates
        self.onImportLocal = onImportLocal
        self.onOpenGitHub = onOpenGitHub
        self.onToggleBeta = onToggleBeta
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedActionRow
            compactActionRow
        }
    }

    private var expandedActionRow: some View {
        HStack(spacing: 10) {
            Button(data.primaryActionTitle, action: onPrimaryAction)
                .dsPrimaryButton()
                .disabled(data.isBusy)

            Button(data.importLocalTitle, action: onImportLocal)
                .dsSecondaryButton()
                .disabled(data.isBusy)

            Button(data.openGitHubTitle, action: onOpenGitHub)
                .dsSecondaryButton()
                .disabled(data.isBusy)

            Spacer(minLength: 0)

            Toggle(
                data.showBetaTitle,
                isOn: Binding(
                    get: { data.showBetaEnabled },
                    set: { value in
                        onToggleBeta(value)
                    }
                )
            )
            .toggleStyle(.switch)
        }
    }

    private var compactActionRow: some View {
        HStack(spacing: 10) {
            Button(data.primaryActionTitle, action: onPrimaryAction)
                .dsPrimaryButton()
                .disabled(data.isBusy)

            Menu {
                Button(data.checkUpdatesTitle, action: onCheckUpdates)
                Button(data.importLocalTitle, action: onImportLocal)
                Button(data.openGitHubTitle, action: onOpenGitHub)
            } label: {
                Label(data.moreActionsTitle, systemImage: "ellipsis.circle")
            }
            .dsSecondaryButton()
            .disabled(data.isBusy)

            Spacer(minLength: 0)

            Toggle(
                data.showBetaTitle,
                isOn: Binding(
                    get: { data.showBetaEnabled },
                    set: { value in
                        onToggleBeta(value)
                    }
                )
            )
            .toggleStyle(.switch)
        }
    }
}
