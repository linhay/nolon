import SwiftUI

struct ResourceCardHeaderGroup: View {
    let name: String
    let version: String?
    let badgeForeground: Color
    let badgeBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            if let version {
                Text(version)
                    .font(.system(size: 10, weight: .bold))
                    .dsBadge(
                        foreground: badgeForeground,
                        background: badgeBackground,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    )
            }
        }
    }
}

struct ResourceCardSummaryGroup: View {
    let summary: String?

    var body: some View {
        if let summary {
            Text(summary)
                .dsSecondaryText(font: .subheadline)
                .lineSpacing(2)
                .lineLimit(3)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        } else {
            Spacer()
        }
    }
}

struct ResourceCardContextMenuGroup<ExtraContent: View>: View {
    let onTap: () -> Void
    let onRevealInFinder: (() -> Void)?
    let canInstall: Bool
    let onInstall: () -> Void
    let canDelete: Bool
    let onDeleteRequest: (() -> Void)?
    let copyCommand: String?
    let onCopyCommand: (() -> Void)?
    let extraContent: () -> ExtraContent

    var body: some View {
        ContextMenuViewDetailsButton(action: onTap)

        if let onRevealInFinder {
            ContextMenuShowInFinderButton(action: onRevealInFinder)
        }

        if canInstall {
            Divider()
            ContextMenuInstallButton(action: onInstall)
        }

        if canDelete {
            Divider()
            ContextMenuDeleteButton(
                isEnabled: onDeleteRequest != nil,
                action: { onDeleteRequest?() }
            )
        }

        if let command = copyCommand, !command.isEmpty, let onCopyCommand {
            Divider()
            Button {
                onCopyCommand()
            } label: {
                Label(NSLocalizedString("Copy Command", comment: "Copy command"), systemImage: "doc.on.doc")
                    .dsIconLabelButton()
            }
        }

        extraContent()
    }
}
